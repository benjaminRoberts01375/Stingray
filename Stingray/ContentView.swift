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
}

struct ContentView: View {
    @State var loginState: LoginState = .loggedOut
    @State var deepLinkRequest: DeepLinkRequest?
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            switch loginState {
            case .loggedOut:
                AddServerView(loggedIn: $loginState)
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
    }
    
    private func handleDeepLink(url: URL) {
        print("Deep link received: \(url.absoluteString)")
        
        // Make sure URL scheme is good
        guard url.scheme == "stingray",
              url.host == "media" else {
            print("Invalid deep link scheme or host")
            return
        }
        
        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("Failed to parse URL components")
            return
        }
        
        // Get mediaID and its parent for lookup later
        let mediaID = queryItems.first(where: { $0.name == "id" })?.value
        let parentID = queryItems.first(where: { $0.name == "parentID" })?.value
        guard let mediaID = mediaID, let parentID = parentID else {
            print("Missing required parameters: mediaID or parentID")
            return
        }
        
        print("Parsed deep link - mediaID: \(mediaID), parentID: \(parentID)")
        
        // Create deep link request
        deepLinkRequest = DeepLinkRequest(mediaID: mediaID, parentID: parentID)
    }
}

struct DeepLinkRequest: Equatable, Hashable {
    let mediaID: String
    let parentID: String
    let id = UUID() // Ensure each request is unique
}

#Preview {
    ContentView()
}
