//
//  login.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

struct LoginView: View {
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
                Text("Error: \(error)")
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
                ProgressView()
                    .opacity(awaitingLogin ? 1 : 0)
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            print("Attempting to set up from storage")
            do {
                let advancedStorage = DefaultsAdvancedStorage(storage: DefaultsBasicStorage())
                guard let url = advancedStorage.getServerURL() else {
                    enum AddressError: Error { case badAddress }
                    throw AddressError.badAddress
                }
                loggedIn = .loggedIn(try JellyfinModel(address: url))
            } catch {
                print("Failed to setup from storage, showing login screen")
                return
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
        let streamingService: JellyfinModel
        do {
            streamingService = try JellyfinModel(address: url)
        } catch {
            self.error = "Unable to setup streaming service"
            return
        }
        Task {
            awaitingLogin = true
            do {
                try await streamingService.login(username: username, password: password)
            } catch {
                self.error = error.localizedDescription
                awaitingLogin = false
            }
            self.loggedIn = .loggedIn(streamingService)
        }
    }
}

#Preview {
    @Previewable @State var loginState: LoginState = .loggedOut
    LoginView(loggedIn: $loginState)
}
