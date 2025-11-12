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
    
    func signin() {
        guard let url = settings.url else { return }
        awaitingLogin = true
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                self.error = error.localizedDescription
                awaitingLogin = false
                return
            }
            
            guard let data = data else {
                print("No data received")
                self.error = "No data received"
                awaitingLogin = false
                return
            }
            
            // Handle the data
            if let string = String(data: data, encoding: .utf8) {
                print(string)
            }
            
            // Update settings to trigger the view change
            settings.urlProtocol = httpProcol
            settings.urlHostname = httpHostname
            settings.urlPort = httpPort
            
            awaitingLogin = false
        }
        
        task.resume()
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
                        settings.url = URL(string: "\(httpProcol)://\(httpHostname):\(httpPort)")
                        signin()
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
