//
//  ContentView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

struct ContentView: View {
    @State var jellyfin: any StreamingService = JellyfinManager()
    
    var body: some View {
        if !jellyfin.loggedIn {
            LoginView(streamingService: $jellyfin)
        } else {
            Text("Logged into server: \(jellyfin.url?.absoluteString ?? "No URL")")
        }
    }
}

#Preview {
    ContentView()
}
