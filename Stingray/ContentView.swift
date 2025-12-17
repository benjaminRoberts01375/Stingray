//
//  ContentView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

enum LoginState {
    case loggedOut
    case loggedIn(any StreamingServiceProtocol)
}

struct ContentView: View {
    @State var loginState: LoginState = .loggedOut
    @State var deepLinkRequest: DeepLinkRequest?
    
    var body: some View {
        switch loginState {
        case .loggedOut:
            AddServerView(loggedIn: $loginState)
                .padding(128)
        case .loggedIn(let streamingService):
            DashboardView(streamingService: streamingService, deepLinkRequest: $deepLinkRequest) // Deeplink is handled in here
                .task {
                    guard case .waiting = streamingService.libraryStatus else {
                        print("No need for libraries")
                        return
                    }
                    print("Getting libraries")
                    await streamingService.retrieveLibraries()
                }
                .onOpenURL { url in
                    handleDeepLink(url: url)
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
