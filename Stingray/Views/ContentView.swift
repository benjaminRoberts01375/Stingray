//
//  ContentView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import StoreKit
import SwiftUI

/// Login phase of the application
public enum LoginState {
    /// All users are logged out
    case loggedOut
    /// There is at least one user signed in
    case loggedIn(
        SystemInfoProviding & LibraryProviding & PlayerProviding & UserProviding & MediaImageProviding & MediaProviding &
        RecommendationProviding,
        UserProtocol
    )
    /// There are accounts signed in, but the current user needs to be picked
    case pickingUser
}

/// The root view, owning every app-wide model and driving the logged-out / picking-user / logged-in state machine.
public struct ContentView: View {
    /// Which phase of sign-in the app is in
    @State private var loginState: LoginState = .loggedOut
    /// A pending deep link, forwarded to `DashboardView` once signed in
    @State private var deepLinkRequest: DeepLinkRequest?
    /// App navigation, shared with every child view
    @State private var navigationPath: NavigationPath
    /// User and app settings, published into the environment
    @State private var settings: SettingsModel
    /// Active theme, published into the environment
    @State private var theme: ThemeModel
    /// Store of every known user
    @State private var userModel: UserModel
    /// In-app purchase state, published into the environment
    @State private var purchases: PurchasesModel
    /// Gates cold-boot auto sign-in behind a PIN when the resumed user has one set
    @State private var pinModel: PINModel?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    /// Opens permanent storage and builds every app-wide model from it.
    /// Throwing here rather than degrading is deliberate: if storage can't be opened, continuing risks writing over the user's existing
    /// data. `StingrayApp` catches this and shows an error screen instead.
    /// - Throws: `SetupErrors.databaseError` when permanent storage cannot be opened
    public init() throws(SetupErrors) {
        let defaultsStorage: HybridBasicStorage
        do { defaultsStorage = try HybridBasicStorage() }
        catch { throw SetupErrors.databaseError(error) }
        let userStorage = UserStorage(basicStorage: defaultsStorage)
        let settingStorage = SettingStorage(basicStorage: defaultsStorage)

        let userModel = UserModel(storage: userStorage)
        self.userModel = userModel
        self.navigationPath = NavigationPath()
        let themeModel = ThemeModel(
            darkTheme: userModel.activeUser?.darkTheme ?? .deepSea,
            lightTheme: userModel.activeUser?.lightTheme ?? .beach,
            colorScheme: ColorScheme.light
        )
        self.theme = themeModel
        let purchases = PurchasesModel()
        self.purchases = purchases
        self.settings = SettingsModel(user: userModel.activeUser, storage: settingStorage, theme: themeModel)
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            switch loginState {
            case .loggedOut:
                AddServerView(loginState: $loginState, userModel: self.userModel)
            case .pickingUser:
                VStack {
                    Text("Welcome back to Jellyfin")
                        .font(.title.bold())
                    Spacer()
                    ProfilePickerView(loginState: $loginState, userModel: self.userModel)
                    Spacer()
                }
                .padding(128)

            case .loggedIn(let streamingService, let user):
                DashboardView(
                    streamingService: streamingService,
                    navigationPath: $navigationPath,
                    deepLinkRequest: $deepLinkRequest,
                    loggedIn: $loginState,
                    user: user,
                    userModel: self.userModel
                )
                .onOpenURL { handleDeepLink(url: $0) }
            }
        }
        .onChange(of: self.scenePhase) { _, newPhase in
            if newPhase != .active { return } // Did we become active
            if self.settings.profileSwitchingMethod != .askOnResume || self.userModel.getUsers().count <= 1 { return }  // Should we ask
            if case .loggedIn(let streamingService, _) = self.loginState, streamingService.playerProgress != nil { // Streaming something
                return
            }
            Log.info("Scene Phase caused profile picker")
            self.loginState = .pickingUser
        }
        .colorScheme(self.theme.currentTheme.colorScheme)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .stingrayBackground()
        .ignoresSafeArea()
        .fullScreenCover(isPresented: Binding(
            get: { self.pinModel?.isPresented ?? false },
            set: { newValue in self.pinModel?.isPresented = newValue }
        )) {
            if let pinModel = self.pinModel {
                PINEntry(model: pinModel)
                    .padding(64)
                    .stingrayBackground()
                    .ignoresSafeArea()
            }
        }
        .environment(self.theme)
        .environment(self.settings)
        .environment(self.purchases)
        .environment(\.locale, self.settings.langauge ?? self.locale)
        .onChange(of: self.colorScheme, initial: true) { self.settings.systemTheme = $1 }
        .task {
            switch self.loginState {
            case .loggedIn: return
            default: break
            }

            Log.info("Attempting to set up from storage")
            // Check if any users exist
            if self.userModel.getUsers().isEmpty {
                Log.info("No users have been signed up, showing login screen")
                return
            }

            // Asking user for prefered profile
            if self.userModel.getUsers().count > 1 {
                switch self.settings.profileSwitchingMethod {
                case .askOnLaunch, .askOnResume:
                    Log.info("Showing profile picker")
                    self.loginState = .pickingUser
                    return
                default: break
                }
            }

            // Check if the current Apple TV user has an associated account
            guard let defaultUser = self.userModel.activeUser
            else {
                Log.info("Users exist, but there's no active user. Showing profile picker")
                self.loginState = .pickingUser
                return
            }

            // Manual profile switching skips the picker entirely, so the PIN must be gated here instead
            if defaultUser.pin != nil {
                Log.info("Cold boot requires a PIN for \(defaultUser.displayName)")
                let pinModel = PINModel(for: defaultUser)
                self.pinModel = pinModel
                pinModel.isPresented = true
                switch await pinModel.status {
                case .success: break
                case .canceled:
                    Log.info("PIN entry canceled on cold boot, showing profile picker")
                    self.loginState = .pickingUser
                    return
                }
            }

            switch defaultUser.serviceType {
            case .Jellyfin(let userJellyfin):
                Log.info("Signing in as user \(defaultUser.displayName) - \(defaultUser.id)")
                self.loginState = .loggedIn(
                    JellyfinModel(
                        userDisplayName: defaultUser.displayName,
                        userID: defaultUser.id,
                        serviceID: defaultUser.serviceID,
                        accessToken: userJellyfin.accessToken,
                        sessionID: userJellyfin.sessionID,
                        serviceURL: defaultUser.serviceURL
                    ), defaultUser
                )
            }
        }
        .task {
            await self.purchases.setupProducts()

            // Listening for new purchases
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    if transaction.productID == PurchasesModel.ProductID.supporter.rawValue {
                        self.purchases.boughtSupporter = transaction.revocationDate == nil
                    }
                    await transaction.finish()
                }
            }
        }
    }

    /// Parses a `stingray://media?id=…&parentID=…` URL into a `DeepLinkRequest`.
    /// Malformed links are logged and dropped rather than surfaced, since they arrive from outside the app.
    /// - Parameter url: URL the system opened Stingray with
    private func handleDeepLink(url: URL) {
        Log.info("Deep link received: \(url.absoluteString)")

        // Make sure URL scheme is good
        guard url.scheme == "stingray",
              url.host == "media" else {
            Log.warning("Invalid deep link scheme or host")
            return
        }

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            Log.warning("Failed to parse URL components")
            return
        }

        // Get mediaID and its parent for lookup later
        let mediaID = queryItems.first(where: { $0.name == "id" })?.value
        let parentID = queryItems.first(where: { $0.name == "parentID" })?.value
        guard let mediaID = mediaID, let parentID = parentID else {
            Log.warning("Missing required parameters: mediaID or parentID")
            return
        }

        Log.info("Parsed deep link - mediaID: \(mediaID), parentID: \(parentID)")

        // Create deep link request
        deepLinkRequest = DeepLinkRequest(mediaID: mediaID, parentID: parentID)
    }
}

/// A request to open a specific piece of media, arriving from a Top Shelf deep link.
public struct DeepLinkRequest: Equatable, Hashable {
    /// Server ID of the media to open
    public let mediaID: String
    /// Library the media belongs to, checked first during lookup
    public let parentID: String
    /// Makes each request distinct, so opening the same media twice still triggers `onChange`
    public let id = UUID() // Ensure each request is unique
}

#Preview {
    if let view = try? ContentView() { view }
    else { Text("Preview failed to initialize") }
}
