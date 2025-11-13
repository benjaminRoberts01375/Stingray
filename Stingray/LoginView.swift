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
    
    @Binding var streamingService: StreamingServiceProtocol?
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
    }
    
    func setupConnection() {
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
        let streamingService = JellyfinModel(address: url)
        Task {
            awaitingLogin = true
            error = ""
            do {
                try await streamingService.login(username: username, password: password)
            } catch {
                self.error = error.localizedDescription
                awaitingLogin = false
            }
            self.streamingService = JellyfinModel(address: url)
        }
    }
}

#Preview {
    @Previewable @State var jellyfin: (any StreamingServiceProtocol)? = nil
    LoginView(streamingService: $jellyfin)
}
