//
//  PlayerStats.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import AVFoundation
import SwiftUI

public struct PlayerStreamingStats: View {
    /// All data regarding current playback
    public var vm: PlayerViewModel

    public init(vm: PlayerViewModel) {
        self.mediaSourceID = vm.playerProgress?.mediaSource.id ?? "Unknown"
        self.mediaSourceTitle = vm.playerProgress?.mediaSource.name ?? "Untitled"
        self.videoStreamID = vm.playerProgress?.videoID ?? "Unknown"
        self.audioStreamID = vm.playerProgress?.audioID ?? "Unknown"
        self.subtitleStreamID = vm.playerProgress?.subtitleID
        self.vm = vm
    }

    /// Network usage
    @State private var networkThroughput: Int = 0
    /// Video bitrate of the playing content
    @State private var bitrate: Int = 0
    /// Current playback resolution
    @State private var resolution: CGSize = .zero
    /// Current frame rate
    @State private var frameRate: Float = 0
    /// The amount of content loaded in the playback buffer in seconds
    @State private var bufferDuration: Int = 0
    /// Video codec and profile
    @State private var videoCodec = "Unknown"
    /// ID of the media source given by the server
    private let mediaSourceID: String
    /// Name of the current media source
    private let mediaSourceTitle: String
    /// ID of the video source given by the server
    private let videoStreamID: String
    /// ID of the audio source given by the server
    private let audioStreamID: String
    /// ID of the subtitle source given by the server. `nil` means no subtitles are being used
    private let subtitleStreamID: String?
    /// Screen resolution
    private let screenResolution: CGSize = UIScreen.main.nativeBounds.size

    public var body: some View {
        HStack {
            VStack {
                VStack(alignment: .leading) {
                    Text("Metadata")
                        .font(.title3.bold())
                        .padding(.bottom)
                    (Text("Media Source Name" + ": ").bold() + Text(self.mediaSourceTitle))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    (Text("Media Source ID" + ": ").bold() + Text(self.mediaSourceID))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Video Stream" + ": ").bold() + Text(self.videoStreamID)
                    Text("Audio Stream" + ": ").bold() + Text(self.audioStreamID)
                    Text("Subtitle Stream" + ": ").bold() + Text(self.subtitleStreamID ?? "None")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .availableGlass()
                .padding(.bottom)
                VStack(alignment: .leading) {
                    Text("Live Data")
                        .font(.title3.bold())
                        .padding(.bottom)
                    Text("Typical Network Usage" + ": ").bold() + Text("\(self.networkThroughput) bits per second")
                    Text("Video Bitrate" + ": ").bold() + Text("\(self.bitrate) bits per second")
                    Text("Buffer Duration" + ": ").bold() + Text("\(bufferDuration) seconds")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .availableGlass()
                .padding(.top)
            }
            VStack(alignment: .leading) {
                Text("Playback Metadata")
                    .font(.title3.bold())
                    .padding(.bottom)
                Text("Screen Resolution" + ": ").bold() + Text("\(Int(screenResolution.width)) × \(Int(screenResolution.height))px")
                Text("Playback Resolution" + ": ").bold() + Text("\(Int(resolution.width)) × \(Int(resolution.height))px")
                Text("Framerate" + ": ").bold() + Text("\(String(format: "%.2f", frameRate)) fps")
                Text("Video Codec" + ": ").bold() + Text(videoCodec)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .availableGlass()
        }
        .task { // Update stats periodically
            while !Task.isCancelled {
                await updateStats()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Updates the real-time stats
    private func updateStats() async {
        guard let currentItem = self.vm.player.currentItem,
              let track = currentItem.tracks.first,
              let accessLog = currentItem.accessLog(),
              let lastEvent = accessLog.events.last
        else { return }

        // Bits per second
        self.networkThroughput = Int(lastEvent.observedBitrate) // Represents network usage
        self.bitrate = Int(lastEvent.averageVideoBitrate) // Represents typical video bitrate

        // Get presentation size (actual displayed resolution)
        self.resolution = currentItem.presentationSize

        // Get real frame rate and playback resolution
        self.resolution = currentItem.presentationSize
        self.frameRate = track.currentVideoFrameRate

        // Get codec and profile
        if let assetTrack = track.assetTrack,
           let formatDescription = try? await assetTrack.load(.formatDescriptions).first {
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
            let fourCC = withUnsafeBytes(of: codecType.bigEndian) { String(bytes: $0, encoding: .ascii) ?? "????" }
            if fourCC.hasPrefix("hvc") || fourCC.hasPrefix("hev") { self.videoCodec = getHEVCProfile(from: formatDescription) ?? "HEVC" }
            else if fourCC.hasPrefix("avc") { self.videoCodec = getH264Profile(from: formatDescription) ?? "H.264" }
            else { self.videoCodec = fourCC }
        }

        // Calculate buffer duration in seconds
        if let timeRange = currentItem.loadedTimeRanges.first?.timeRangeValue {
            let bufferedStart = CMTimeGetSeconds(timeRange.start)
            let bufferedDuration = CMTimeGetSeconds(timeRange.duration)
            let currentTime = CMTimeGetSeconds(currentItem.currentTime())

            // Calculate how many seconds ahead are buffered from current position
            let bufferEnd = bufferedStart + bufferedDuration
            self.bufferDuration = max(0, Int(bufferEnd - currentTime))
        }
        else { self.bufferDuration = 0 }
    }

    private func getH264Profile(from formatDescription: CMFormatDescription) -> String? {
        guard let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any],
              let atoms = extensions["SampleDescriptionExtensionAtoms"] as? [String: Any],
              let avcC = atoms["avcC"] as? Data,
              avcC.count > 1
        else { return nil }

        switch avcC[1] {
        case 66:  return "H.264 Baseline"
        case 77:  return "H.264 Main"
        case 100: return "H.264 High"
        default:  return "H.264"
        }
    }

    private func getHEVCProfile(from formatDescription: CMFormatDescription) -> String? {
        guard let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any],
              let atoms = extensions["SampleDescriptionExtensionAtoms"] as? [String: Any],
              let hvcC = atoms["hvcC"] as? Data,
              hvcC.count > 1
        else { return nil }

        return hvcC[1] == 2 ? "HEVC Main10" : "HEVC Main"
    }
}
