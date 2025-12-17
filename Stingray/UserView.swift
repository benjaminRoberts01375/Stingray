//
//  UserView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/17/25.
//

import SwiftUI

public struct UserView: View {
    var users = UserModel().getUsers()
    var streamingService: any StreamingServiceProtocol
    @Binding var loggedIn: LoginState
    
    public var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(users) { user in
                    Button {
                        print(user.displayName)
                    } label: {
                        Text(user.displayName)
                    }
                }
                NavigationLink {
                    LoginView(loggedIn: $loggedIn)
                } label: {
                    Text("Add User")
                }
            }
        }
        .scrollClipDisabled()
    }
}
