//
//  ContentView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

/// Login phase of the application
enum LoginState {
    /// All users are logged out
    case loggedOut
    /// There is at least one user signed in
    case loggedIn(any StreamingServiceProtocol)
    /// There are accounts signed in, but the current user needs to be picked
    case pickingUser
    /// User is signed in, but requires a PIN
    case requiresPIN(User)
}

struct ContentView: View {
    @State var loginState: LoginState = .loggedOut
    @State var deepLinkRequest: DeepLinkRequest?
    @State private var navigationPath: NavigationPath
    @State private var settings: SettingsModel
    @State private var userModel: UserModel
    
    @Environment(\.scenePhase) var scenePhase
    
    init() throws(SetupErrors) {
        let defaultsStorage: DefaultsBasicStorage
        do { defaultsStorage = try DefaultsBasicStorage() }
        catch { throw SetupErrors.databaseError(error) }
        let userStorage = UserStorage(basicStorage: defaultsStorage)
        let settingStorage = SettingStorage(basicStorage: defaultsStorage)
        
        let userModel = UserModel(storage: userStorage)
        self.userModel = userModel
        self.navigationPath = NavigationPath()
        self.settings = SettingsModel(userModel: userModel, storage: settingStorage)
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            switch loginState {
            case .loggedOut:
                AddServerView(loginState: $loginState)
                    .padding(128)
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
                    .padding(128)
                
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
            if case .loggedIn(let streamingService) = self.loginState, streamingService.playerProgress != nil { // Streaming something
                return
            }
            if self.settings.profileSwitchingMethod == .askOnResume { self.loginState = .pickingUser } // Should we ask
        }
        .environment(settings)
        .environment(userModel)
        .onAppear {
            listKeychainEntries()
            nukeKeychain()
            Log.info("Attempting to set up from storage")
            // Check if any users exist
            if self.userModel.getUsers().isEmpty {
                Log.info("No users have been signed up, showing login screen")
                return
            }
            
            // Asking user for prefered profile
            switch self.settings.profileSwitchingMethod {
            case .askOnLaunch, .askOnResume:
                Log.info("Showing profile picker")
                if case .loggedIn(let streamingService) = self.loginState, streamingService.playerProgress != nil { // Streaming something
                    self.loginState = .pickingUser
                    return
                }
            default: break
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
    
    /// Deletes all entries within the global keychain.
    func nukeKeychain() {
        // Check for ResetKeychain argument
        if !ProcessInfo.processInfo.arguments.contains("-ResetKeychain") {
            Log.debug("Leaving Keychain alone.")
            return
        }
        Log.info("Nuking Keychain...")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.benlab.Stingray",
            kSecAttrAccessGroup as String: DefaultsBasicStorage.keychainAccessGroup(),
            kSecUseUserIndependentKeychain as String: true
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Log.debug("Keychain reset failed for class kSecClassGenericPassword: \(status)")
        }
        
        Log.info("Keychain nuked.")
        listKeychainEntries()
    }
    
    func listKeychainEntries() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.benlab.Stingray",
            kSecAttrAccessGroup as String: DefaultsBasicStorage.keychainAccessGroup(),
            kSecUseUserIndependentKeychain as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            Log.debug("Keychain is empty.")
            return
        } else if status != errSecSuccess {
            Log.debug("Keychain list failed: \(status)")
            return
        }
        
        guard let items = result as? [[String: Any]] else {
            Log.debug("Keychain list: unexpected result format")
            return
        }
        
        Log.debug("--- Keychain (\(items.count) entries) ---")
        for item in items {
            let key = item[kSecAttrAccount as String] as? String ?? "unknown"
            let value: String
            if let data = item[kSecValueData as String] as? Data {
                value = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
            } else {
                value = "<no data>"
            }
            Log.debug("\(key) : \(value)")
        }
        Log.debug("---")
    }
}

struct DeepLinkRequest: Equatable, Hashable {
    let mediaID: String
    let parentID: String
    let id = UUID() // Ensure each request is unique
}

#Preview {
    if let view = try? ContentView() { view }
    else { Text("Preview failed to initialize") }
}
