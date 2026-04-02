//
//  ProfilePickerView.swift
//  Stingray
//
//  Created by Ben Roberts on 2/26/26.
//

import SwiftUI

public struct ProfilePickerView: View {
    /// List of all users who have at some point signed into Stingray
    private var users: [User] {
        return userModel.getUsers()
    }
    /// Login state for the entire app
    @Binding var loginState: LoginState
    /// Functions and values regarding the users
    @Environment(UserModel.self) var userModel: UserModel
    /// Current theme
    @Environment(ThemeModel.self) var themeModel: ThemeModel
    
    // A simple way to derrive the streaming service from the login state
    var streamingService: (any StreamingServiceProtocol)? {
        switch loginState {
        case .loggedIn(let streamingServiceProtocol):
            return streamingServiceProtocol
        default: return nil
        }
    }
    
    public var body: some View {
        CenterWrappedRowsLayout(itemWidth: 250, itemHeight: 325, horizontalSpacing: 100, verticalSpacing: 100) {
            ForEach(users) { user in
                Button {
                    loginState = Self.switchUser(
                        user: user,
                        userModel: self.userModel,
                        currentLoginState: loginState,
                        themeModel: self.themeModel
                    )
                }
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
                                        .foregroundStyle(self.themeModel.currentTheme.defaultProfileImage())
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
                        streamingService?.userID == user.id ? self.themeModel.currentTheme.activeColor() : .clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .padding(.horizontal, -16)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Logout", systemImage: "tv.slash.fill", role: .destructive) {
                        let userIDToDelete = user.id  // Capture immediately to prevent a race condition
                        let wasActiveUser = self.streamingService?.userID == userIDToDelete
                        
                        self.userModel.deleteUser(userIDToDelete)
                        
                        if wasActiveUser {
                            if let nextUser = self.userModel.getUsers().first {
                                self.loginState = Self.switchUser(
                                    user: nextUser,
                                    userModel: self.userModel,
                                    currentLoginState: self.loginState,
                                    themeModel: self.themeModel
                                )
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
    
    static func switchUser(user: User, userModel: UserModel, currentLoginState: LoginState, themeModel: ThemeModel) -> LoginState {
        userModel.activeUser = user
        themeModel.dark = user.darkTheme
        themeModel.light = user.lightTheme
        
        // If we're already logged in as this user, reuse the existing streaming service instance
        if case .loggedIn(let existingService) = currentLoginState {
            if existingService.userID == user.id { return currentLoginState } // Return the same state to avoid recreating the service
            else if user.pin != nil { return .requiresPIN(user) } // May require a PIN when switching users
        }
        if case .pickingUser = currentLoginState {
            if user.pin != nil { return .requiresPIN(user) } // May require a PIN when switching users
        }
        
        // Otherwise, create a new streaming service instance
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
