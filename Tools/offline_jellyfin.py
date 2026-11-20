#!/usr/bin/env python3
#
#  offline_jellyfin.py
#  Stingray
#
#  Created by Ben Roberts on 11/20/26.
#

"""
A record/replay proxy for developing Stingray without access to a Jellyfin server.

Record (while the real server is reachable):
    python3 Tools/offline_jellyfin.py record --upstream http://192.168.1.10:8096

Replay (while offline):
    python3 Tools/offline_jellyfin.py replay

In both modes, point Stingray simulator to http://localhost:8096 or http://<your-mac-ip>:8096 (device).
Anything browsed while recording is saved and can be replayed later. Stop either mode with Ctrl+C.

Responses are stored under <repo>/Stingray-Request-Cache (git ignored) as:
    <METHOD>/<request path>/<hash>.body
    <METHOD>/<request path>/<hash>.meta.json

Replay mode does not check authentication, so any token or login works. Heavily AI Assisted.
"""

import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# Query params that change every request (ex. new playback sessions) and shouldn't affect cache lookups
VOLATILE_PARAMS = {"playsessionid", "api_key", "deviceid", "_"}
# Hop-by-hop and length headers that must be recalculated instead of replayed verbatim
SKIPPED_RESPONSE_HEADERS = {"transfer-encoding", "connection", "content-length", "content-encoding", "keep-alive", "date"}
# Headers that describe the connection to the proxy rather than the upstream server
SKIPPED_REQUEST_HEADERS = {"host", "accept-encoding", "connection", "content-length"}


def split_request(raw_path: str) -> tuple[str, list[tuple[str, str]]]:
    """Splits a raw request path into its path and URL params.

    Args:
        raw_path: Request path as received by the server, including any URL params.

    Returns:
        The path with a single leading slash, and the URL params as (name, value) pairs.
    """
    parsed = urllib.parse.urlsplit(raw_path)
    path = "/" + parsed.path.strip("/")
    query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    return path, query


def entry_directory(root: Path, method: str, path: str) -> Path:
    """Builds the folder that holds every recorded variant of a request.

    Args:
        root: Root folder for all recordings.
        method: REST verb of the request.
        path: Request path without URL params.

    Returns:
        Folder for this method and path. Lowercased since Jellyfin paths are case-insensitive.
    """
    # Neutralize ".." so a request can't write outside of the root folder
    safe_components = [component.replace("..", "_") for component in path.lower().strip("/").split("/") if component]
    return root.joinpath(method, *safe_components) if safe_components else root / method / "_root"


def entry_hash(query: list[tuple[str, str]]) -> str:
    """Creates a stable file name for a request's URL params so the same request always maps to the same file.

    Args:
        query: URL params as (name, value) pairs.

    Returns:
        A short hash of the sorted, non-volatile URL params.
    """
    stable = sorted((key.lower(), value) for key, value in query if key.lower() not in VOLATILE_PARAMS)
    return hashlib.sha1(urllib.parse.urlencode(stable).encode()).hexdigest()[:16]


class ProxyHandler(BaseHTTPRequestHandler):
    """Handles a single request by either forwarding and recording it, or replaying a saved response."""

    mode: str = "replay"
    """Either "record" or "replay"."""
    upstream: str = ""
    """Address of the real Jellyfin server. Only used when recording."""
    root: Path = Path()
    """Root folder for all recordings."""

    # Every REST verb gets the same treatment
    def do_GET(self): self.handle_any()
    def do_POST(self): self.handle_any()
    def do_PUT(self): self.handle_any()
    def do_DELETE(self): self.handle_any()
    def do_HEAD(self): self.handle_any()

    def handle_any(self):
        """Reads the incoming request and routes it to the current mode."""
        # Read the body up front so it can be forwarded when recording
        length = int(self.headers.get("Content-Length") or 0)
        request_body = self.rfile.read(length) if length else None

        # Figure out where this request lives on disk
        path, query = split_request(self.path)
        directory = entry_directory(self.root, self.command, path)
        key = entry_hash(query)

        if self.mode == "record":
            self.record(directory, key, request_body)
        else:
            self.replay(directory, key, path)

    # MARK: Record

    def record(self, directory: Path, key: str, request_body: bytes | None):
        """Forwards a request to the real server, saves a successful response, and sends it back to the client.

        Args:
            directory: Folder to save the response in.
            key: File name for the response, without an extension.
            request_body: Body of the incoming request, if any.
        """
        # Setup the upstream request
        url = self.upstream.rstrip("/") + self.path
        headers = {name: value for name, value in self.headers.items() if name.lower() not in SKIPPED_REQUEST_HEADERS}
        upstream_request = urllib.request.Request(url, data=request_body, headers=headers, method=self.command)

        # Send the request
        try:
            with urllib.request.urlopen(upstream_request, timeout=60) as response:
                status, response_headers, body = response.status, list(response.getheaders()), response.read()
        except urllib.error.HTTPError as error:
            # Pass errors through without saving them so a bad request doesn't poison the cache
            self.send(error.code, list(error.headers.items()), error.read())
            return
        except Exception as error:
            self.send(502, [("Content-Type", "text/plain")], f"Upstream failed: {error}".encode())
            return

        # Pretty-print JSON so it's easy to read and edit later
        content_type = dict((name.lower(), value) for name, value in response_headers).get("content-type", "")
        stored_body = body
        if "json" in content_type and body:
            try: stored_body = json.dumps(json.loads(body), indent=2, ensure_ascii=False).encode()
            except ValueError: pass  # Not actually JSON, keep the original bytes

        # Save the response
        directory.mkdir(parents=True, exist_ok=True)
        (directory / f"{key}.body").write_bytes(stored_body)
        (directory / f"{key}.meta.json").write_text(json.dumps({
            "url": self.path,
            "status": status,
            "headers": [[name, value] for name, value in response_headers if name.lower() not in SKIPPED_RESPONSE_HEADERS],
        }, indent=2))

        # Send the untouched response back to the client
        self.send(status, response_headers, body)

    # MARK: Replay

    def replay(self, directory: Path, key: str, path: str):
        """Sends back a saved response for a request, or a stand-in if nothing was recorded.

        Args:
            directory: Folder the response would be saved in.
            key: File name for the response, without an extension.
            path: Request path, used for logging misses.
        """
        meta_file = directory / f"{key}.meta.json"
        if not meta_file.exists():
            # Fall back to the newest recording of this path, ex. same image at a different width
            candidates = sorted(directory.glob("*.meta.json"), key=lambda file: file.stat().st_mtime, reverse=True) if directory.exists() else []
            meta_file = candidates[0] if candidates else None

        if meta_file is None:
            if self.command in ("POST", "PUT", "DELETE"):
                # Playback progress reports, logout, etc. Pretend they worked
                self.send(200, [("Content-Type", "application/json")], b"{}")
            else:
                self.log_message("MISS %s %s", self.command, path)
                self.send(404, [("Content-Type", "text/plain")], b"Not recorded")
            return

        # Load the saved response and send it
        meta = json.loads(meta_file.read_text())
        body = meta_file.with_name(meta_file.name.replace(".meta.json", ".body")).read_bytes()
        self.send(meta["status"], meta["headers"], body)

    # MARK: Helpers

    def send(self, status: int, headers: list, body: bytes):
        """Writes a full response to the client.

        Args:
            status: HTTP status code.
            headers: Response headers as (name, value) pairs. Hop-by-hop headers are dropped.
            body: Response body. Skipped for HEAD requests.
        """
        self.send_response(status)
        for name, value in headers:
            if name.lower() not in SKIPPED_RESPONSE_HEADERS:
                self.send_header(name, value)
        self.send_header("Content-Length", str(len(body))) # Recalculate since the body may have changed
        self.end_headers()
        if self.command != "HEAD":
            try: self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError): pass  # AVPlayer often hangs up early


def main():
    """Parses arguments and runs the proxy until interrupted."""
    parser = argparse.ArgumentParser(description="Record/replay Jellyfin responses for offline Stingray development")
    parser.add_argument("mode", choices=["record", "replay"])
    parser.add_argument("--upstream", help="Real Jellyfin server URL (record mode only)")
    parser.add_argument("--port", type=int, default=8096)
    # Resolve relative to this script so the repo root is used no matter where it's run from
    default_dir = Path(__file__).resolve().parent.parent / "Stingray-Request-Cache"
    parser.add_argument("--dir", default=str(default_dir), help="Where recordings live")
    args = parser.parse_args()

    if args.mode == "record" and not args.upstream:
        parser.error("record mode requires --upstream")

    # Share the config with every handler
    ProxyHandler.mode = args.mode
    ProxyHandler.upstream = args.upstream or ""
    ProxyHandler.root = Path(args.dir)
    ProxyHandler.root.mkdir(parents=True, exist_ok=True)

    # Listen on all interfaces so a physical Apple TV can connect too
    server = ThreadingHTTPServer(("0.0.0.0", args.port), ProxyHandler)
    print(f"{args.mode.capitalize()}ing on http://localhost:{args.port} -> {args.upstream or ProxyHandler.root}", file=sys.stderr)
    try: server.serve_forever()
    except KeyboardInterrupt: pass  # Ctrl+C is the expected way to stop


if __name__ == "__main__":
    main()
