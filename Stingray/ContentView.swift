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
    
    var body: some View {
        switch loginState {
        case .loggedOut:
            LoginView(loggedIn: $loginState)
        case .loggedIn(let streamingService):
            DashboardView(streamingService: streamingService)
                .task {
                    guard case .waiting = streamingService.libraryStatus else {
                        print("No need for libraries")
                        return
                    }
                    print("Getting libraries")
                    await streamingService.retrieveLibraries()
                }
        }
    }
}

#Preview {
    ContentView()
}
