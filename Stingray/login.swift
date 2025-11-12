//
//  login.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

struct LoginView: View {
    @Binding var settings: SettingsManager
    @State var httpProcol: HttpProtocol
    @State var httpHostname: String
    @State var httpPort: String
    @State var username: String = ""
    @State var password: String = ""
    @State var error: String = ""
    @State var awaitingLogin: Bool = false
    
    init(settings: Binding<SettingsManager>) {
        _settings = settings
        _httpProcol = State(initialValue: settings.wrappedValue.urlProtocol)
        _httpHostname = State(initialValue: settings.wrappedValue.urlHostname)
        _httpPort = State(initialValue: String(settings.wrappedValue.urlPort))
    }
    
    var body: some View {
            VStack {
                Text("Sign into Jellyfin")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                HStack {
                    Picker("Protocol", selection: $httpProcol) {
                        ForEach(HttpProtocol.allCases, id: \.self) { availableProtocol in
                            Text(availableProtocol.rawValue).tag(availableProtocol)
                        }
                    }
                    .pickerStyle(.menu)
                    switch httpProcol {
                    case .http:
                        TextField("Hostname", text: $httpHostname)
                        TextField("Port", text: $httpPort)
                            .keyboardType(.numberPad)
                    case .https:
                        TextField("URL", text: $httpHostname)
                    }
                }
                HStack {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                }
                if error != "" {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                        .padding(.vertical)
                }
                Spacer()
                HStack {
                    ProgressView()
                        .opacity(0)
                    Button("Connect") {
                        Task {
                            awaitingLogin = true
                            error = ""
                            do {
                                try await settings.signin(httpProtocol: httpProcol, hostname: httpHostname, port: httpPort, username: username, password: password)
                            } catch {
                                self.error = error.localizedDescription
                                awaitingLogin = false
                            }
                        }
                    }
                    ProgressView()
                        .opacity(awaitingLogin ? 1 : 0)
                }
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    @Previewable @State var settings: SettingsManager = SettingsManager()
    LoginView(settings: $settings)
}

extension SettingsManager {
    enum SignInError: Error, LocalizedError {
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
    
    func signin(httpProtocol: HttpProtocol, hostname: String, port: String, username: String, password: String) async throws {
        // Update URL settings
        self.urlProtocol = httpProtocol
        self.urlHostname = hostname
        self.urlPort = port
        
        guard let baseURL = self.url else {
            throw SignInError.invalidBaseURL
        }
        guard let url = URL(string: "/Users/AuthenticateByName", relativeTo: baseURL) else {
            throw SignInError.invalidAuthURL
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
            throw SignInError.encodingFailed(error)
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
            throw SignInError.requestFailed(error)
        }
        
        // Verify HTTP status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SignInError.invalidResponse(statusCode: 0, message: "Not an HTTP response")
        }
        
        // Get any error codes
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response
            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                errorMessage = json["message"] as? String ?? json["Message"] as? String
            }
            throw SignInError.invalidResponse(statusCode: httpResponse.statusCode, message: errorMessage)
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
            throw SignInError.invalidJSONStructure
        }
        
        // Update settings with response data
        self.usersName = userName
        self.sessionID = sessionId
        self.userID = userId
        self.accessToken = accessToken
        self.serverID = serverId
    }
}
