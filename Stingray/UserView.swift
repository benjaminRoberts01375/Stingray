//
//  UserView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/17/25.
//

import SwiftUI

public struct UserView: View {
    var users = UserModel()
    var streamingService: any StreamingServiceProtocol
    @Binding var loggedIn: LoginState
    
    public var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(users.getUsers()) { user in
                    Button {
                        switch user.serviceType {
                        case .Jellyfin(let jellyfinData):
                            self.loggedIn = .loggedIn(
                                JellyfinModel(
                                    userDisplayName: user.displayName,
                                    userID: user.id,
                                    serviceID: user.serviceID,
                                    accessToken: jellyfinData.accessToken,
                                    sessionID: jellyfinData.sessionID,
                                    serviceURL: user.serviceURL
                                )
                            )
                            self.users.setDefaultUser(userID: user.id)
                        }
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
