//
//  settings.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

@Observable
final class JellyfinManager: StreamingService {
    private let defaults = UserDefaults.standard
    
    var urlProtocol: HttpProtocol {
        didSet { defaults.set(urlProtocol.rawValue, forKey: DefaultsKeys.urlProtocol.rawValue) }
    }
    
    var urlHostname: String {
        didSet { defaults.set(urlHostname, forKey: DefaultsKeys.urlHostname.rawValue) }
    }
    
    var urlPort: String {
        didSet { defaults.set(urlPort, forKey: DefaultsKeys.urlPort.rawValue) }
    }
    
    var usersName: String {
        didSet { defaults.set(usersName, forKey: DefaultsKeys.usersName.rawValue)}
    }
    
    var sessionID: String {
        didSet { defaults.set(sessionID, forKey: DefaultsKeys.sessionID.rawValue)}
    }
    
    var userID: String {
        didSet { defaults.set(userID, forKey: DefaultsKeys.userID.rawValue)}
    }
    
    var accessToken: String {
        didSet { defaults.set(accessToken, forKey: DefaultsKeys.accessToken.rawValue) }
    }
    
    var serverID: String {
        didSet { defaults.set(serverID, forKey: DefaultsKeys.serverID.rawValue) }
    }
    
    init() {
        self.urlProtocol = HttpProtocol(rawValue: defaults.string(forKey: DefaultsKeys.urlProtocol.rawValue) ?? "") ?? .http
        self.urlHostname = defaults.string(forKey: DefaultsKeys.urlHostname.rawValue) ?? ""
        self.urlPort = defaults.string(forKey: DefaultsKeys.urlPort.rawValue) ?? "8096"
        self.usersName = defaults.string(forKey: DefaultsKeys.usersName.rawValue) ?? ""
        self.sessionID = defaults.string(forKey: DefaultsKeys.sessionID.rawValue) ?? ""
        self.userID = defaults.string(forKey: DefaultsKeys.userID.rawValue) ?? ""
        self.accessToken = defaults.string(forKey: DefaultsKeys.accessToken.rawValue) ?? ""
        self.serverID = defaults.string(forKey: DefaultsKeys.serverID.rawValue) ?? ""
    }
    
    // StreamingProtocol conformance
    
    var url: URL? {
        get {
            if urlHostname == "" {
                return nil
            }
            return URL(string: "\(urlProtocol)://\(urlHostname):\(urlPort)/")
        }
        set {
            guard let newURL = newValue else { return }
            
            if let scheme = newURL.scheme {
                urlProtocol = HttpProtocol(rawValue: scheme) ?? .http
            }
            if let host = newURL.host {
                urlHostname = host
            }
            if let port = newURL.port {
                urlPort = String(port)
            }
        }
    }
    
    var loggedIn: Bool {
        get { self.accessToken != "" }
    }
    
    func login(httpProtocol: HttpProtocol, hostname: String, port: String, username: String, password: String) async throws {
        // Update URL settings
        self.urlProtocol = httpProtocol
        self.urlHostname = hostname
        self.urlPort = port
        
        guard let baseURL = self.url else {
            throw APIErrors.invalidBaseURL
        }
        guard let url = URL(string: "/Users/AuthenticateByName", relativeTo: baseURL) else {
            throw APIErrors.invalidAuthURL
        }
        
        // Create the request body
        let requestBody: [String: String] = [
            "Username": username,
            "Pw": password
        ]
        
        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(requestBody)
        } catch {
            throw APIErrors.encodingFailed(error)
        }
        
        // Create the POST request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Jellyfin requires this authorization header to identify the client
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let deviceName = UIDevice.current.name
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let authHeader = "MediaBrowser Client=\"Stingray\", Device=\"\(deviceName)\", DeviceId=\"\(deviceId)\", Version=\"\(appVersion)\""
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        request.httpBody = jsonData
        
        // Send the request
        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIErrors.requestFailed(error)
        }
        
        // Verify HTTP status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIErrors.invalidResponse(statusCode: 0, message: "Not an HTTP response")
        }
        
        // Get any error codes
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response
            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                errorMessage = json["message"] as? String ?? json["Message"] as? String
            }
            throw APIErrors.invalidResponse(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse JSON response directly
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let user = json["User"] as? [String: Any],
              let userName = user["Name"] as? String,
              let sessionInfo = json["SessionInfo"] as? [String: Any],
              let sessionId = sessionInfo["Id"] as? String,
              let userId = sessionInfo["UserId"] as? String,
              let accessToken = json["AccessToken"] as? String,
              let serverId = json["ServerId"] as? String else {
            throw APIErrors.invalidJSONStructure
        }
        
        // Update settings with response data
        self.usersName = userName
        self.sessionID = sessionId
        self.userID = userId
        self.accessToken = accessToken
        self.serverID = serverId
    }
}

enum HttpProtocol: String, CaseIterable {
    case http = "http"
    case https = "https"
}

enum DefaultsKeys: String {
    case urlProtocol = "URL-Protocol"
    case urlHostname = "URL-Hostname"
    case urlPort = "URL-Port"
    case usersName = "Users-Name"
    case sessionID = "Session-ID"
    case userID = "User-ID"
    case accessToken = "Access-Token"
    case serverID = "Server-ID"
}

enum APIErrors: Error, LocalizedError {
    case invalidBaseURL
    case invalidAuthURL
    case encodingFailed(Error)
    case requestFailed(Error)
    case invalidResponse(statusCode: Int, message: String?)
    case invalidJSONStructure
    
    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid base URL configuration"
        case .invalidAuthURL:
            return "Could not construct authentication URL"
        case .encodingFailed(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .requestFailed(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .invalidResponse(let statusCode, let message):
            if let message = message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server returned error code: \(statusCode)"
        case .invalidJSONStructure:
            return "Invalid response format from server"
        }
    }
}
