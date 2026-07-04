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
    case loggedIn(SystemInfoProviding & LibraryProviding & PlayerProviding & UserProviding & MediaImageProviding & MediaProviding &
                   RecommendationProviding)
    /// There are accounts signed in, but the current user needs to be picked
    case pickingUser
    /// User is signed in, but requires a PIN
    case requiresPIN(any UserProtocol)
}

public struct ContentView: View {
    @State private var loginState: LoginState = .loggedOut
    @State private var deepLinkRequest: DeepLinkRequest?
    @State private var navigationPath: NavigationPath
    @State private var settings: SettingsModel
    @State private var theme: ThemeModel
    @State private var userModel: UserModel
    @State private var purchases: PurchasesModel
    
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    
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
        self.settings = SettingsModel(userModel: userModel, storage: settingStorage, theme: themeModel)
    }
    
    public var body: some View {
        NavigationStack(path: $navigationPath) {
            switch loginState {
            case .loggedOut:
                AddServerView(loginState: $loginState)
            case .pickingUser:
                VStack {
                    Text("Welcome back to Jellyfin")
                        .font(.title.bold())
                    Spacer()
                    ProfilePickerView(loginState: $loginState)
                    Spacer()
                }
                .padding(128)
            case .requiresPIN(let user):
                PINEntry(loginState: $loginState, user: user)
                
            case .loggedIn(let streamingService):
                DashboardView(
                    streamingService: streamingService,
                    navigationPath: $navigationPath,
                    deepLinkRequest: $deepLinkRequest,
                    loggedIn: $loginState
                )
                .onOpenURL { handleDeepLink(url: $0) }
            }
        }
        .onChange(of: self.scenePhase) { _, newPhase in
            if newPhase != .active { return } // Did we become active
            if self.settings.profileSwitchingMethod != .askOnResume || self.userModel.getUsers().count <= 1 { return }  // Should we ask
            if case .loggedIn(let streamingService) = self.loginState, streamingService.playerProgress != nil { // Streaming something
                return
            }
            Log.info("Scene Phase caused profile picker")
            self.loginState = .pickingUser
        }
        .colorScheme(self.theme.currentTheme.colorScheme)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .stingrayBackground()
        .ignoresSafeArea()
        .environment(self.theme)
        .environment(self.settings)
        .environment(self.userModel)
        .environment(self.purchases)
        .environment(\.locale, self.settings.langauge ?? self.locale)
        .onChange(of: self.colorScheme, initial: true) { self.settings.systemTheme = $1 }
        .onAppear {
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
            
            // User requires PIN
            if defaultUser.pin != nil {
                self.loginState = .requiresPIN(defaultUser)
                return
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
                    )
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

public struct DeepLinkRequest: Equatable, Hashable {
    public let mediaID: String
    public let parentID: String
    public let id = UUID() // Ensure each request is unique
}

#Preview {
    if let view = try? ContentView() { view }
    else { Text("Preview failed to initialize") }
}
