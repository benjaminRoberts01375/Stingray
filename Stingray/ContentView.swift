//
//  ContentView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

struct ContentView: View {
    @State var settings: SettingsManager = SettingsManager()
    
    var body: some View {
        if settings.urlHostname == "" {
            LoginView(settings: $settings)
        } else {
            Text("Logged into server: \(settings.urlHostname)")
        }
    }
}

#Preview {
    ContentView()
}
