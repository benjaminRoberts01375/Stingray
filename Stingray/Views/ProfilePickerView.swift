//
//  ProfilePickerView.swift
//  Stingray
//
//  Created by Ben Roberts on 2/26/26.
//

import SwiftUI

/// A grid of signed-in profiles plus an "Add User" tile, reflowed to fit the available width.
public struct ProfilePickerView: View {
    /// List of all users who have at some point signed into Stingray
    @State private var itemRows: [[PickerItem]] = []
    /// Login state for the entire app
    @Binding public var loginState: LoginState

    /// Location where all users are stored
    public let userModel: UserModelProtocol

    /// Size of a single profile tile
    public static let optionSize: CGSize = CGSize(width: 274, height: 335)
    /// Gap between tiles, horizontally and vertically
    public static let spacing: CGSize = CGSize(width: 60, height: 45)

    /// Types of items available to show in the profile picker
    public enum PickerItem: Hashable, Identifiable {
        /// Display a user icon
        case user(User)
        /// Display the add user icon
        case addProfile

        /// Stable identity for SwiftUI. The user's own ID, or a fixed key for the add tile
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
                            ProfilePickerUser(loginState: $loginState, userModel: self.userModel, user: user)
                                .frame(width: Self.optionSize.width, height: Self.optionSize.height)
                        case .addProfile:
                            AddProfile(loginState: $loginState, userModel: self.userModel)
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
    ///   - pinModel: Data holding the user's PIN information
    /// - Returns: Updated `LoginState`
    public static func switchUser(
        user: any UserProtocol,
        userModel: UserModelProtocol,
        currentLoginState: LoginState,
        settingsModel: SettingsModel,
        pinModel: PINModel
    ) async -> LoginState {
        userModel.activeUser = user

        // If we're already logged in as this user, reuse the existing streaming service instance
        if case .loggedIn(let existingService, _) = currentLoginState {
            if existingService.userID == user.id { return currentLoginState } // Return the same state to avoid recreating the service
            else if user.pin != nil {  // May require a PIN when switching users
                pinModel.isPresented = true
                switch await pinModel.status {
                case .success: break
                case .canceled: return currentLoginState
                }
            }
        }
        if case .pickingUser = currentLoginState, user.pin != nil { // May require a PIN when switching users
            pinModel.isPresented = true
            switch await pinModel.status {
            case .success: break
            case .canceled: return currentLoginState
            }
        }
        settingsModel.switchUser(to: user)
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
                ), user
            )
        }
    }
}

/// The "Add User" tile, navigating to the sign-in form.
fileprivate struct AddProfile: View {
    @Environment(ThemeModel.self) private var theme
    /// Login state, handed to the sign-in form
    @Binding public var loginState: LoginState

    /// Checks if add user button is selected
    @FocusState private var isFocused: Bool

    let userModel: UserModelProtocol

    var body: some View {
        NavigationLink { AddServerView(loginState: $loginState, userModel: self.userModel) }
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

/// A single profile tile that signs its user in when selected, prompting for a PIN first when one is set.
fileprivate struct ProfilePickerUser: View {
    /// Current settings for the user
    @Environment(SettingsModel.self) private var settings
    /// Theme data for this user
    @Environment(ThemeModel.self) private var theme
    /// Login state for the entire app
    @Binding private var loginState: LoginState

    /// Controls showing the logout confirmation alert
    @State private var showLogoutAlert: Bool
    /// Controls showing the PIN screen for switching users
    @State private var pinModel: PINModel

    /// Functions and values regarding the users
    private let userModel: UserModelProtocol
    /// User to display
    private let user: UserProtocol

    /// Creates a profile tile.
    /// - Parameters:
    ///   - loginState: Login state to update when this profile is chosen
    ///   - userModel: Location where all users are stored
    ///   - user: User this tile represents
    init(loginState: Binding<LoginState>, userModel: UserModelProtocol, user: UserProtocol) {
        self.showLogoutAlert = false
        self._loginState = loginState
        self.userModel = userModel
        self.user = user
        self.pinModel = PINModel(for: user)
    }

    var body: some View {
        Button {
            Task {
                self.loginState = await ProfilePickerView.switchUser(
                    user: user,
                    userModel: self.userModel,
                    currentLoginState: self.loginState,
                    settingsModel: self.settings,
                    pinModel: self.pinModel
                )
            }
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
                case .loggedIn(let streamingService, _):
                    streamingService.userID == user.id ? self.theme.currentTheme.activeColor : .clear
                default: Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 40))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: self.$pinModel.isPresented) {
            PINEntry(model: self.pinModel)
                .padding(64)
                .stingrayBackground()
                .ignoresSafeArea()
        }
    }
}
