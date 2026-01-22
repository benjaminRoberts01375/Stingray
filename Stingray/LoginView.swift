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
                } catch {
                    self.error = error.localizedDescription
                    awaitingLogin = false
                }
            }
        case .loggedOut:
            self.error = "There's no streaming service is configured, so we aren't sure how you got here."
        }
    }
}
