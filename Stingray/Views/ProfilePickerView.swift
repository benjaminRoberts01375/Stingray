//
//  ProfilePickerView.swift
//  Stingray
//
//  Created by Ben Roberts on 2/26/26.
//

import SwiftUI

public struct ProfilePickerView: View {
    /// List of all users who have at some point signed into Stingray
    @State private var itemRows: [[PickerItem]] = []
    /// Login state for the entire app
    @Binding public var loginState: LoginState

    @Environment(UserModel.self) private var userModel

    public static let optionSize: CGSize = CGSize(width: 274, height: 335)
    public static let spacing: CGSize = CGSize(width: 60, height: 45)

    /// Types of items available to show in the profile picker
    public enum PickerItem: Hashable, Identifiable {
        /// Display a user icon
        case user(User)
        /// Display the add user icon
        case addProfile

        public var id: String {
            switch self {
            case .addProfile: return "addProfile"
            case .user(let user): return user.id
            }
        }
    }

    public var body: some View {
        VStack(alignment: .center, spacing: Self.spacing.height) {
            ForEach(self.itemRows, id: \.self) { itemRow in
                HStack(spacing: Self.spacing.width) {
                    ForEach(itemRow) { item in
                        switch item {
                        case .user(let user):
                            ProfilePickerUser(loginState: $loginState, user: user)
                                .frame(width: Self.optionSize.width, height: Self.optionSize.height)
                        case .addProfile:
                            AddProfile(loginState: $loginState)
                                .frame(width: Self.optionSize.width, height: Self.optionSize.height)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .focusSection()
            }
        }
        .onGeometryChange(for: Int.self) { proxy in
            max(1, Int(proxy.size.width / (Self.optionSize.width + Self.spacing.width)))
        }
        action: { columns in
            var rows: [PickerItem] = userModel
                .getUsers()
                .sorted { $0.displayName < $1.displayName }
                .map { .user($0) }
            rows += [.addProfile]
            self.itemRows = rows.chunked(into: columns)
        }
        .ignoresSafeArea()
    }

    /// Switch the current login state to a logged in user
    /// - Parameters:
    ///   - user: User to sign in with
    ///   - userModel: Location where users are stored
    ///   - currentLoginState: The current `LoginState`
    ///   - settingsModel: Location of settings and themes
    /// - Returns: Updated `LoginState`
    public static func switchUser(
        user: any UserProtocol,
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

/// Loads and displays a user's profile image.
///
/// Kept as its own view with focus-independent inputs so that moving focus between profiles
/// does not re-evaluate this body or recompute the (network-object-allocating, logging) image URL.
fileprivate struct ProfilePickerImage: View {
    /// Theme data used for the fallback icon color
    @Environment(ThemeModel.self) private var theme
    /// Whether the enclosing profile button (the nearest focusable ancestor) has focus
    @Environment(\.isFocused) private var isFocused

    /// URL of the user's profile image, precomputed by the parent so focus changes don't recompute it
    let url: URL?
    /// Display name, used for the fallback icon's accessibility label
    let displayName: String

    var body: some View {
        AsyncImage(url: url) { phase in
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
                    .accessibilityLabel("Icon for \(displayName)")
                    .padding(50)
            }
        }
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
                    ProfilePickerImage(
                        url: JellyfinModel.getProfileImageURL(userID: user.id, serviceURL: user.serviceURL),
                        displayName: user.displayName
                    )
                }
                Spacer()
                Text(user.displayName)
                    .font(.callout.bold())
            }
            .padding(16)
            .background { // Only show white background if the current user is this user
                switch self.loginState {
                case .loggedIn(let streamingService):
                    streamingService.userID == user.id ? self.theme.currentTheme.activeColor : .clear
                default: Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 40))
        }
        .buttonStyle(.plain)
    }
}
