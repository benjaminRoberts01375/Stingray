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
                        switchUser(user: user)
                    } label: {
                        VStack(alignment: .center) {
                            switch user.serviceType {
                            case .Jellyfin:
                                AsyncImage(
                                    url: JellyfinModel.getProfileImageURL(
                                        userID: user.id,
                                        serviceURL: user.serviceURL
                                    )
                                ) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    default:
                                        // Handle the error here
                                        Image(systemName: "person.fill")
                                            .resizable()
                                            .scaledToFill()
                                            .accessibilityLabel("Person icon")
                                    }
                                }
                            }
                            Text(user.displayName)
                        }
                        .frame(width: 200, height: 250)
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
    
    func switchUser(user: User) {
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
    }
}
