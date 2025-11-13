//
//  ContentView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

struct ContentView: View {
    @State var jellyfin: JellyfinManager = JellyfinManager()
    
    var body: some View {
        if jellyfin.userID == "" {
            LoginView(settings: $jellyfin)
        } else {
            Text("Logged into server: \(jellyfin.urlHostname)")
        }
    }
}

#Preview {
    ContentView()
}
