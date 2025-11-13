//
//  login.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

struct LoginView: View {
    @Binding var streamingService: StreamingService
    @State var httpProcol: HttpProtocol
    @State var httpHostname: String
    @State var httpPort: String
    @State var username: String = ""
    @State var password: String = ""
    @State var error: String = ""
    @State var awaitingLogin: Bool = false
    
    init(streamingService: Binding<StreamingService>) {
        _streamingService = streamingService
        
        _httpProcol = State(initialValue: HttpProtocol(rawValue: streamingService.wrappedValue.url?.scheme ?? "") ?? .http)
        _httpHostname = State(initialValue: streamingService.wrappedValue.url?.host ?? "")
        _httpPort = State(initialValue: String(streamingService.wrappedValue.url?.port ?? 8096))
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
                                try await streamingService.login(httpProtocol: httpProcol, hostname: httpHostname, port: httpPort, username: username, password: password)
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
    @Previewable @State var jellyfin: any StreamingService = JellyfinManager()
    LoginView(streamingService: $jellyfin)
}
