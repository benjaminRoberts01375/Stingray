//
//  AddServerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

struct AddServerView: View {
    enum HttpProtocol: String, CaseIterable {
        case http = "http"
        case https = "https"
    }
    
    @Binding var loggedIn: LoginState
    @State var httpProcol: HttpProtocol = .http
    @State var httpHostname: String = ""
    @State var httpPort: String = "8096"
    @State var username: String = ""
    @State var password: String = ""
    @State var error: String = ""
    @State var awaitingLogin: Bool = false
    
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
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.vertical)
            }
            Spacer()
            HStack {
                ProgressView()
                    .opacity(0)
                Button("Connect") {
                    setupConnection()
                }
                .disabled(awaitingLogin)
                ProgressView()
                    .opacity(awaitingLogin ? 1 : 0)
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            print("Attempting to set up from storage")
            
            // Use TVProfileManager to determine which user to log in
            // Priority: 1) ATV profile mapped user, 2) Default user
            guard let userToLogin = TVProfileManager.shared.getUserForAppLaunch() else {
                print("Failed to setup from storage, showing login screen")
                return
            }
            
            switch userToLogin.serviceType {
            case .Jellyfin(let userJellyfin):
                loggedIn = .loggedIn(
                    JellyfinModel(
                        userDisplayName: userToLogin.displayName,
                        userID: userToLogin.id,
                        serviceID: userToLogin.serviceID,
                        accessToken: userJellyfin.accessToken,
                        sessionID: userJellyfin.sessionID,
                        serviceURL: userToLogin.serviceURL
                    )
                )
            }
        }
    }
    
    func setupConnection() {
        // Setup URL
        var url: URL?
        switch httpProcol {
        case .http:
            url = URL(string: "http://\(httpHostname):\(httpPort)")
        case .https:
            url = URL(string: "https://\(httpHostname)")
        }
        guard let url else {
            error = "Invalid URL"
            return
        }
        
        // Setup streaming service
        Task {
            awaitingLogin = true
            do {
                let streamingService = try await JellyfinModel.login(url: url, username: username, password: password)
                self.loggedIn = .loggedIn(streamingService)
            } catch {
                if let netErr = error as? NetworkError {
                    switch netErr {
                    case .invalidURL:
                        switch self.httpProcol {
                        case .http:
                            self.error = "Invalid HTTP URL. Check your hostname and port."
                        case .https:
                            self.error = "Invalid HTTPS URL. Check your URL."
                        }
                    case .encodeJSONFailed:
                        self.error = "Failed to send request to server. " +
                            "This may be because of some tricky characters in your username and password."
                    case .decodeJSONFailed, .missingAccessToken, .requestFailedToSend:
                        switch self.httpProcol {
                        case .http:
                            self.error = "Could not find your Jellyfin server. Please check your hostname and port."
                        case .https:
                            self.error = "Could not find your Jellyfin server. Please check your URL."
                        }
                    case .badResponse(let responseCode, _):
                        switch responseCode {
                        case 401:
                            self.error = "Invalid username or password."
                        case 404:
                            switch self.httpProcol {
                            case .http:
                                self.error = "Could not find your Jellyfin server. Please check your hostname and port."
                            case .https:
                                self.error = "Could not find your Jellyfin server. Please check your URL."
                            }
                        default:
                            self.error = "An unexpected error occurred. Please make sure your login details are correct."
                        }
                    }
                    print("Error signing in: \(error.localizedDescription)")
                } else {
                    // Handle other types of errors
                    print("Other error: \(error)")
                    self.error = "An unexpected error occurred. Please make sure your login details are correct."
                }
                awaitingLogin = false
            }
        }
    }
}

#Preview {
    @Previewable @State var loginState: LoginState = .loggedOut
    AddServerView(loggedIn: $loginState)
}
