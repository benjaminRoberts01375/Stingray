//
//  AddServerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import CoreImage.CIFilterBuiltins
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
                .disabled(self.connected || self.loading)
                switch httpProcol {
                case .http:
                    TextField("Hostname", text: $httpHostname)
                        .disabled(self.connected)
                        .opacity(self.connected ? 0.5 : 1)
                    TextField("Port", text: $httpPort)
                        .keyboardType(.numberPad)
                        .disabled(self.connected || self.loading)
                        .opacity(self.connected ? 0.5 : 1)
                case .https:
                    TextField("URL", text: $httpHostname)
                        .disabled(self.connected || self.loading)
                        .opacity(self.connected ? 0.5 : 1)
                }
            }
            .focusSection()
            if !self.connected {
                Spacer()
                HStack {
                    Button("Connect") { self.connectToServer() }
                        .disabled(self.loading)
                        .focusSection()
                }
                .frame(maxWidth: .infinity)
                .focusSection()
            }
            else {
                Button("Disconnect") { self.connected = false }
            }
            if self.connected {
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
                                self.setupConnection(quickConnectSecret: nil)
                            }
                            .disabled(self.loading)
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
                        if let quickConnectCode { Text("Enter code \(quickConnectCode) to login") }
                        else { Text("Quick Connect not available") }
                        if let url = self.jellyfinURL?.buildURL(path: "web/#/quickconnect", urlParams: nil),
                           let qrCode = Self.generateQRCode(from: url) {
                            Image(uiImage: qrCode)
                                .interpolation(.none)
                                .resizable()
                                .accessibilityLabel("QR Code to \(url.absoluteString)")
                                .frame(width: 300, height: 300)
                                .shadow(radius: 10)
                                .padding(.horizontal)
                            Text(url.absoluteString)
                        }
                    }
                    // make the quick connect view 50% the size of the horizontal space
                    .frame(maxWidth: .infinity)
                }
                Spacer()
            }
            ProgressView()
                .opacity(self.loading ? 1 : 0)
            if let error = self.error {
                ErrorView(error: error, summary: self.errorSummary)
                    .padding(.vertical)
            }
        }
        // Done separately so we can ue the @Environment, also helps against reloads
        .onAppear { self.loadExistingServerInfo() }
        .onDisappear { self.connected = false } // A small hacky fix to stop checking QuickConnect
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
        self.loading = false
    }
    
    /// Initial connection to server before Username and Password or Quick Connect can be used
    private func connectToServer() {
        self.error = nil
        self.quickConnectCode = nil
        self.loading = true
        
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
            self.loading = false
            return
        }
        self.jellyfinURL = url
        
        // Check if quick connect is available
        Task {
            let jellyfinServerInfo = JellyfinQuickConnectModel(url: url)
            var quickConnectAvailable = false
            do {
                quickConnectAvailable = try await jellyfinServerInfo.getQuickConnectEnabled()
                self.connected = true
            } catch let error as RError {
                self.connected = false
                self.error = error
                self.setError()
                return
            } catch {
                self.connected = false
                return
            }
            self.loading = false
            
            if quickConnectAvailable {
                // Get the code for quick connect code
                do {
                    self.quickConnectCode = try await jellyfinServerInfo.getQuickConnectCodes()
                    // Start polling every 5 seconds to check if quick connect authentication succeeded
                    while self.connected {
                        let quickConnectSecret = try await jellyfinServerInfo.getQuickConnectSecret()
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
                    return
                }
                catch { return }
            }
        }
    }
    
    /// Setup user with the Jellyfin server
    /// - Parameter quickConnectSecret: Quick Connection secret generated by the Jellyfin server
    private func setupConnection(quickConnectSecret: String?) {
        // Setup streaming service
        self.loading = true
        Task {
            do {
                guard let jellyfinURL = jellyfinURL else {
                    Log.error("Could not unwrap server URL")
                    return
                }
                // Login using Quick Connect
                if let quickConnectSecret = quickConnectSecret {
                    let streamingService = try await JellyfinModel.login(
                        url: jellyfinURL, quickConnectSecret: quickConnectSecret, userModel: self.userModel
                    )
                    self.loggedIn = .loggedIn(streamingService)
                }
                // Login using normal credentials
                else {
                    let streamingService = try await JellyfinModel.login(
                        url: jellyfinURL, username: username, password: password, userModel: self.userModel
                    )
                    self.loggedIn = .loggedIn(streamingService)
                }
            } catch let error as RError {
                self.error = AccountErrors.loginFailed(error)
                self.setError()
                // Do not dismiss on error, so return
                return
            } catch {
                self.error = AccountErrors.loginFailed(nil)
                self.setError()
                return
            }
            self.loading = false
            self.dismiss()
        }
    }
    
    /// Generate a QR Code from a URL
    /// - Parameter url: URL to encode
    /// - Returns: QR Code if available
    public static func generateQRCode(from url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        
        guard let outputImage = filter.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    @Previewable @State var loginState: LoginState = .loggedOut
    AddServerView(loginState: $loginState)
}
