//
//  LoginView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/17/25.
//

import SwiftUI

struct LoginView: View {
    @Binding internal var loggedIn: LoginState
    @State internal var username: String = ""
    @State internal var password: String = ""
    @State internal var error: String = ""
    @State internal var awaitingLogin: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Sign into Jellyfin")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
            VStack {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
                
                if awaitingLogin {
                    ProgressView()
                        .opacity(0)
                }
                Button("Add User") { setupUser() }
                    .disabled(awaitingLogin)
                if awaitingLogin {
                    ProgressView()
                }
                
                if error != "" {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                        .padding(.vertical)
                }
            }
            .frame(width: 400)
            Spacer()
        }
    }
    
    func setupUser() {
        switch loggedIn {
        case .loggedIn(let streamingService):
            Task {
                do {
                    let streamingService = try await JellyfinModel.login(
                        url: streamingService.serviceURL,
                        username: username,
                        password: password
                    )
                    self.loggedIn = .loggedIn(streamingService)
                    dismiss()
                } catch let error as RError {
                    if let netErr = error.last() as? NetworkError {
                        let scheme: HttpProtocol = streamingService.serviceURL.scheme == "https" ? .https : .http
                        self.error = Self.overrideNetErrorMessage(netErr: netErr, httpProtocol: scheme)
                    } else {
                        self.error = "Failed to login. Please try again."
                    }
                    
                    awaitingLogin = false
                }
            }
        case .loggedOut:
            self.error = "There's no streaming service is configured, so we aren't sure how you got here."
        }
    }
    
    static func overrideNetErrorMessage(netErr: NetworkError, httpProtocol: HttpProtocol) -> String {
        switch netErr {
        case .invalidURL:
            switch httpProtocol {
            case .http: return "Invalid HTTP URL. Check your hostname and port."
            case .https: return "Invalid HTTPS URL. Check your URL."
            }
        case .encodeJSONFailed: return "Failed to send request to server. " +
                "This may be because of some tricky characters in your username and password."
        case .decodeJSONFailed, .missingAccessToken, .requestFailedToSend:
            switch httpProtocol {
            case .http: return "Could not find your Jellyfin server. Please check your hostname and port."
            case .https: return "Could not find your Jellyfin server. Please check your URL."
            }
        case .badResponse(let responseCode, _):
            switch responseCode {
            case 401: return "Invalid username or password."
            case 404:
                switch httpProtocol {
                case .http: return "Could not find your Jellyfin server. Please check your hostname and port."
                case .https: return "Could not find your Jellyfin server. Please check your URL."
                }
            default: return "An unexpected error occurred. Please make sure your login details are correct."
            }
        }
    }
}

enum HttpProtocol: String, CaseIterable {
    case http = "http"
    case https = "https"
}
