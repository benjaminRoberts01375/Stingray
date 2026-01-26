//
//  AddServerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

struct AddServerView: View {
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
            guard let defaultUser = UserModel.shared.getDefaultUser() else {
                print("Failed to setup from storage, showing login screen")
                return
            }
            switch defaultUser.serviceType {
            case .Jellyfin(let userJellyfin):
                loggedIn = .loggedIn(
                    JellyfinModel(
                        userDisplayName: defaultUser.displayName,
                        userID: defaultUser.id,
                        serviceID: defaultUser.serviceID,
                        accessToken: userJellyfin.accessToken,
                        sessionID: userJellyfin.sessionID,
                        serviceURL: defaultUser.serviceURL
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
                if let rError = error as? RError, let netErr = rError.last() as? NetworkError {
                    self.error = LoginView.overrideNetErrorMessage(netErr: netErr, httpProtocol: self.httpProcol)
                    print("Error signing in: \(rError.rDescription())")
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
