//
//  AddServerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

public struct AddServerView: View {
    @Binding public var loggedIn: LoginState
    @State private var httpProcol: HttpProtocol = .http
    @State private var httpHostname: String = ""
    @State private var httpPort: String = "8096"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var quickConnectCode: String?
    @State private var error: RError?
    @State private var errorSummary: String = ""
    @State private var loading: Bool = false
    @State private var connected: Bool = false
    @State private var jellyfinURL: URL?
    @Environment(UserModel.self) public var userModel: UserModel
    @Environment(\.dismiss) public var dismiss
    
    public init(loginState: Binding<LoginState>) {
        self._loggedIn = loginState
    }
    
    public var body: some View {
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
                .disabled(connected || loading)
                switch httpProcol {
                case .http:
                    TextField("Hostname", text: $httpHostname)
                        .disabled(connected)
                    TextField("Port", text: $httpPort)
                        .keyboardType(.numberPad)
                        .disabled(connected || loading)
                case .https:
                    TextField("URL", text: $httpHostname)
                        .disabled(connected || loading)
                }
            }
            if !connected {
                Button("Connect") {
                    connect()
                }.disabled(loading)
            } else {
                Button("Disconnect") {
                    connected = false
                }
            }
            if connected {
                Divider()
                HStack {
                    VStack {
                        Text("Enter Credentials").font(.title3)
                        TextField("Username", text: $username)
                        SecureField("Password", text: $password)
                        HStack {
                            ProgressView()
                                .opacity(0)
                            Button("Login") {
                                setupConnection(quickConnectSecret: nil)
                            }
                            .disabled(loading)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    // make the login 50% the size of the horizontal space
                    .frame(maxWidth: .infinity)
                    HStack {
                        VStack {
                            HStack {
                                Divider()
                            }
                            Text("or").font(.title2)
                            HStack {
                                Divider()
                            }
                        }
                    }
                    VStack {
                        Text("Quick Connect")
                            .font(.title3)
                        if let quickConnectCode {
                            Text("Enter code \(quickConnectCode) to login")
                        } else {
                            Text("Quick Connect not available")
                        }
                    }
                    // make the quick connect view 50% the size of the horizontal space
                    .frame(maxWidth: .infinity)
                }
            }
            Spacer()
            ProgressView()
                .opacity(loading ? 1 : 0)
            if let error = self.error {
                ErrorView(error: error, summary: self.errorSummary)
                    .padding(.vertical)
            }
        }
        .onAppear { // Done separately so we can ue the @Environment, also helps against reloads
            loadExistingServerInfo()
        }
    }
    
    public func loadExistingServerInfo() {
        guard let serviceURL = userModel.activeUser?.serviceURL ?? userModel.getUsers().first?.serviceURL else {
            return
        }
        
        if serviceURL.scheme == "https" {
            httpProcol = .https
        }
        httpPort = String(serviceURL.port ?? 8096)
        httpHostname = serviceURL.host ?? ""
    }
    
    private func setError() {
        guard let error = self.error else { return }
        if let netErr = error.last() as? NetworkError {
            self.errorSummary = NetworkError.overrideNetErrorMessage(netErr: netErr, httpProtocol: self.httpProcol)
            Log.error("Error signing in: \(error.rDescription())")
        } else {
            self.errorSummary = "An unexpected error occurred. Please make sure your login details are correct."
            Log.error("Unknown error while signing in: \(error)")
        }
        loading = false
    }
    
    private func connect() {
        error = nil
        quickConnectCode = nil
        loading = true
        
        // Setup URL
        var url: URL?
        switch httpProcol {
        case .http:
            url = URL(string: "http://\(httpHostname):\(httpPort)")
        case .https:
            url = URL(string: "https://\(httpHostname)")
        }
        guard let url else {
            let netError: NetworkError
            switch httpProcol {
            case .http:
                netError = NetworkError.invalidURL("http://\(httpHostname):\(httpPort)")
                error = netError
                errorSummary = NetworkError.overrideNetErrorMessage(netErr: netError, httpProtocol: .http)
            case .https:
                netError = NetworkError.invalidURL("https://\(httpHostname)")
                error = netError
                errorSummary = NetworkError.overrideNetErrorMessage(netErr: netError, httpProtocol: .https)
            }
            loading = false
            return
        }
        jellyfinURL = url
        
        // check if quick connect is available
        let jellyfinServerInfo = JellyfinQuickConnectModel(url: url)
        Task {
            var quickConnectAvailable = false
            do {
                quickConnectAvailable = try await jellyfinServerInfo.getQuickConnectEnabled()
                connected = true
            } catch let error as RError {
                connected = false
                self.error = error
                setError()
                return
            }
            loading = false
            
            if quickConnectAvailable {
                // get the code for quick connect
                do {
                    quickConnectCode = try await jellyfinServerInfo.getQuickConnectCodes()
                    // start polling every 5 seconds to check if quick connect authentication succeeded
                    while connected {
                        let quickConnectSecret = try await jellyfinServerInfo.checkCheckConnectAuthentication()
                        if quickConnectSecret != nil {
                            setupConnection(quickConnectSecret: quickConnectSecret)
                            break
                        }
                        // Wait for 5 seconds and then recheck if the user authenticated yet
                        try? await Task.sleep(for: .seconds(5))
                    }
                } catch let error as RError {
                    self.error = error
                    setError()
                    return
                }
            }
        }
    }
    
    private func setupConnection(quickConnectSecret: String?) {
        // Setup streaming service
        Task {
            loading = true
            do {
                guard let jellyfinURL = jellyfinURL else {
                    Log.error("Could not unwrap server URL")
                    return
                }
                if let quickConnectSecret = quickConnectSecret {
                    let streamingService = try await JellyfinModel.login(
                        url: jellyfinURL, quickConnectSecret: quickConnectSecret, userModel: self.userModel
                    )
                    self.loggedIn = .loggedIn(streamingService)
                } else {
                    let streamingService = try await JellyfinModel.login(
                        url: jellyfinURL, username: username, password: password, userModel: self.userModel
                    )
                    self.loggedIn = .loggedIn(streamingService)
                }
            } catch let error as RError {
                self.error = AccountErrors.loginFailed(error)
                setError()
                // do not dismiss on error, so return
                return
            }
            loading = false
            self.dismiss()
        }
    }
}

#Preview {
    @Previewable @State var loginState: LoginState = .loggedOut
    AddServerView(loginState: $loginState)
}
