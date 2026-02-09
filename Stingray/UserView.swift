//
//  UserView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/17/25.
//

import SwiftUI

public struct UserView: View {
    var users = UserModel.shared
    var streamingService: any StreamingServiceProtocol
    @Binding var loggedIn: LoginState
    
    public var body: some View {
        CenterWrappedRowsLayout(itemWidth: 250, itemHeight: 325, horizontalSpacing: 100, verticalSpacing: 100) {
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
                                        Spacer()
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    default:
                                        // Handle the error here
                                        Image(systemName: "person.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0, green: 0.729, blue: 1),
                                                        Color(red: 0, green: 0.09, blue: 0.945)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .accessibilityLabel("Person icon")
                                            .padding(50)
                                    }
                                }
                            }
                        Spacer()
                        Text(user.displayName)
                            .font(.callout.bold())
                    }
                    .padding(16)
                    .padding(.horizontal, 16)
                    .background(user.id == streamingService.userID ? .white.opacity(0.25) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .padding(.horizontal, -16)
                    .padding(-16)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Logout", systemImage: "tv.slash.fill", role: .destructive) {
                        UserModel.shared.deleteUser(user.id)
                        if self.streamingService.userID == user.id {
                            if let nextUser = UserModel.shared.getUsers().first {
                                self.switchUser(user: nextUser)
                            } else {
                                self.loggedIn = .loggedOut
                            }
                        }
                    }
                }
            }
            NavigationLink {
                LoginView(loggedIn: $loggedIn)
            } label: {
                VStack(alignment: .center) {
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("Person icon")
                        .padding(.top, 30)
                    Spacer()
                    Text("Add User")
                        .font(.callout.bold())
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    func switchUser(user: User) {
        // Check if the user we're switching to is the current user
        if user.id == self.streamingService.userID { return }
        
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
