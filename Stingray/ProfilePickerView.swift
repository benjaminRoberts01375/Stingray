//
//  ProfilePickerView.swift
//  Stingray
//
//  Created by Ben Roberts on 2/26/26.
//

import SwiftUI

public struct ProfilePickerView: View {
    /// List of all users who have at some point signed into Stingray
    let users: [User]
    /// Login state for the entire app
    @Binding var loginState: LoginState
    
    // A simple way to derrive the streaming service from the login state
    var streamingService: (any StreamingServiceProtocol)? {
        switch loginState {
        case .loggedIn(let streamingServiceProtocol):
            return streamingServiceProtocol
        default: return nil
        }
    }
    
    init(loginState: Binding<LoginState>) {
        self.users = UserModel.shared.getUsers()
        self._loginState = loginState
    }
    
    public var body: some View {
        CenterWrappedRowsLayout(itemWidth: 250, itemHeight: 325, horizontalSpacing: 100, verticalSpacing: 100) {
            ForEach(users) { user in
                Button { loginState = Self.switchUser(user: user, userModel: UserModel.shared) }
                label: {
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
                    .background { // Only show white background if the current user is this user
                        streamingService?.userID == user.id ? Color.white.opacity(0.25) : .clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .padding(.horizontal, -16)
                    .padding(-16)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Logout", systemImage: "tv.slash.fill", role: .destructive) {
                        UserModel.shared.deleteUser(user.id)
                        if self.streamingService?.userID == user.id {
                            if let nextUser = UserModel.shared.getUsers().first {
                                self.loginState = Self.switchUser(user: nextUser, userModel: UserModel.shared)
                            }
                            else { self.loginState = .loggedOut }
                        }
                    }
                }
            }
            NavigationLink { AddServerView(loginState: $loginState) }
            label: {
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
    
    static func switchUser(user: User, userModel: UserModel) -> LoginState {
        userModel.setActiveUser(userID: user.id)
        
        switch user.serviceType {
        case .Jellyfin(let jellyfinData):
            return .loggedIn(
                JellyfinModel(
                    userDisplayName: user.displayName,
                    userID: user.id,
                    serviceID: user.serviceID,
                    accessToken: jellyfinData.accessToken,
                    sessionID: jellyfinData.sessionID,
                    serviceURL: user.serviceURL
                )
            )
        }
    }
}
