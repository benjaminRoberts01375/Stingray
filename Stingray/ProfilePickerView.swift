//
//  ProfilePickerView.swift
//  Stingray
//
//  Created by Ben Roberts on 2/26/26.
//

import SwiftUI

public struct ProfilePickerView: View {
    /// List of all users who have at some point signed into Stingray
    @State private var users: [User] = []
    /// Login state for the entire app
    @Binding public var loginState: LoginState
    
    @Environment(UserModel.self) private var userModel
    @Environment(ThemeModel.self) private var theme
    
    // A simple way to derrive the streaming service from the login state
    public var streamingService: (any StreamingServiceProtocol)? {
        switch loginState {
        case .loggedIn(let streamingServiceProtocol):
            return streamingServiceProtocol
        default: return nil
        }
    }
    
    public var body: some View {
        CenterWrappedRowsLayout(itemWidth: 250, itemHeight: 325, horizontalSpacing: 100, verticalSpacing: 100) {
            Spacer(minLength: 0)
            ForEach(users) { user in
                ProfilePickerUser(loginState: $loginState, user: user)
            }
            AddProfile(loginState: $loginState)
            Spacer(minLength: 0)
        }
        .onAppear { self.users = userModel.getUsers().sorted { $0.displayName < $1.displayName } }
    }
    
    /// Switch the current login state to a logged in user
    /// - Parameters:
    ///   - user: User to sign in with
    ///   - userModel: Location where users are stored
    ///   - currentLoginState: The current `LoginState`
    ///   - settingsModel: Location of settings and themes
    /// - Returns: Updated `LoginState`
    public static func switchUser(
        user: User,
        userModel: UserModel,
        currentLoginState: LoginState,
        settingsModel: SettingsModel
    ) -> LoginState {
        userModel.activeUser = user
        settingsModel.themeDark = user.darkTheme
        settingsModel.themeLight = user.lightTheme
        
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

fileprivate struct AddProfile: View {
    @Environment(ThemeModel.self) private var theme
    @Binding public var loginState: LoginState
    
    /// Checks if add user button is selected
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationLink { AddServerView(loginState: $loginState) }
        label: {
            VStack(alignment: .center) {
                Image(systemName: "person.crop.circle.fill.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Person icon")
                    .foregroundStyle(self.isFocused ? AnyShapeStyle(Color.black) : self.theme.currentTheme.addProfileStyle)
                    .padding(.top, 30)
                Spacer()
                Text("Add User")
                    .font(.callout.bold())
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused, equals: true)
    }
}

fileprivate struct ProfilePickerUser: View {
    /// Functions and values regarding the users
    @Environment(UserModel.self) private var userModel: UserModel
    /// Current settings for the user
    @Environment(SettingsModel.self) private var settings
    /// Theme data for this user
    @Environment(ThemeModel.self) private var theme
    /// Login state for the entire app
    @Binding var loginState: LoginState

    /// Controls showing the logout confirmation alert
    @State private var showLogoutAlert: Bool = false
    /// Checks if the user's profile is selected
    @FocusState private var isFocused: Bool

    /// User to display
    let user: User

    var body: some View {
        Button {
            self.loginState = ProfilePickerView.switchUser(
                user: user,
                userModel: self.userModel,
                currentLoginState: self.loginState,
                settingsModel: self.settings
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
                                .foregroundStyle(self.isFocused ? AnyShapeStyle(.black) : self.theme.currentTheme.defaultProfileImage)
                                .accessibilityLabel("Icon for \(user.displayName)")
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
                switch self.loginState {
                case .loggedIn(let streamingService):
                    streamingService.userID == user.id ? self.theme.currentTheme.activeColor : .clear
                default: Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 40))
            .padding(.horizontal, -16)
        }
        .buttonStyle(.plain)
        .focused($isFocused, equals: true)
    }
}
