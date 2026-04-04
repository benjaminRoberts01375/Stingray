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
    @State private var quickConnectAvailable: Bool = false
    @State private var connectionOk: Bool = false
    @State private var jellyfinServerInfo: JellyfinServerInfoModel?
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
                .onChange(of: httpPort) { oldValue, newValue in
                    if newValue != oldValue {
                        connectionOk = false
                    }
                }
                switch httpProcol {
                case .http:
                    TextField("Hostname", text: $httpHostname)
                        .onChange(of: httpHostname) { oldValue, newValue in
                            if oldValue != newValue {
                                connectionOk = false
                            }
                        }
                    TextField("Port", text: $httpPort)
                        .keyboardType(.numberPad)
                        .onChange(of: httpPort) { oldValue, newValue in
                            if oldValue != newValue {
                                connectionOk = false
                            }
                        }
                case .https:
                    TextField("URL", text: $httpHostname)
                        .onChange(of: httpHostname) { oldValue, newValue in
                            if oldValue != newValue {
                                connectionOk = false
                            }
                        }
                }
            }
            
            Button("Test Connection") {
                testConnection()
            }
            .disabled(loading)
            if connectionOk {
                VStack {
                    Text("Authentication").font(.title2)
                    Text("Enter Credentials").font(.title3)
                    HStack {
                        TextField("Username", text: $username)
                        SecureField("Password", text: $password)
                    }
                    HStack {
                        ProgressView()
                            .opacity(0)
                        Button("Login") {
                            setupConnection(quickConnectSecret: nil)
                        }
                        .disabled(loading || !connectionOk)
                        ProgressView()
                            .opacity(loading ? 1 : 0)
                    }
                    .buttonStyle(.borderedProminent)

                    if quickConnectAvailable {
                        VStack {
                            Text("- or -").font(.title2)
                            Text("Quick Connect")
                                .font(.title3)
                            VStack {
                                if let quickConnectCode {
                                    Text("Enter code \(quickConnectCode) to login")
                                } else {
                                    Text("Quick Connect failed to load")
                                }
                            }
                        }
                    }
                }
            }
            Spacer()
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
    }
    
    func testConnection() {
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
                self.error = netError
                self.errorSummary = NetworkError.overrideNetErrorMessage(netErr: netError, httpProtocol: .http)
            case .https:
                netError = NetworkError.invalidURL("https://\(httpHostname)")
                self.error = netError
                self.errorSummary = NetworkError.overrideNetErrorMessage(netErr: netError, httpProtocol: .https)
            }
            return
        }

        // check if quick connect is available
        self.jellyfinServerInfo = JellyfinServerInfoModel(url: url)
        Task {
            loading = true
            do {
                self.quickConnectAvailable = try await self.jellyfinServerInfo!.getQuickConnectEnabled()
                self.connectionOk = true
            } catch let error as RError {
                self.error = error
                setError()
            }
            if self.quickConnectAvailable {
                // get the code
                do {
                    self.quickConnectCode = try await self.jellyfinServerInfo!.getQuickConnectCodes()
                    // start polling to check if quick connect authentication succeeded every 5 seconds
                    while true {
                        let quickConnectSecret = try await self.jellyfinServerInfo!.checkCheckConnectAuthentication()
                        if quickConnectSecret != nil {
                            self.setupConnection(quickConnectSecret: quickConnectSecret)
                            break
                        }
                        // Wait for 5 seconds and then recheck if the user authenticated yet
                        try? await Task.sleep(for: .seconds(5))
                    }
                } catch let error as RError {
                    self.error = error
                    self.setError()
                }
            }
            loading = false
        }
    }

    func setupConnection(quickConnectSecret: String?) {
        // Setup streaming service
        Task {
            loading = true
            do {
                if quickConnectSecret != nil {
                    let streamingService = try await JellyfinModel.login(
                        url: self.jellyfinServerInfo!.serviceURL , quickConnectSecret: quickConnectSecret!, userModel: self.userModel
                    )
                    self.loggedIn = .loggedIn(streamingService)
                } else {
                    let streamingService = try await JellyfinModel.login(
                        // FIXME: URL default value
                        url: self.jellyfinServerInfo!.serviceURL, username: username, password: password, userModel: self.userModel
                    )
                    self.loggedIn = .loggedIn(streamingService)
                }
            } catch let error as RError {
                self.error = AccountErrors.loginFailed(error)
                self.setError()
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
