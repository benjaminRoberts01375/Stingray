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
        if settings.urlHostname == "" || settings.urlHostname == "" {
            Text("None")
        } else {
            Text("Some: \(settings.url)")
        }
    }
}

#Preview {
    ContentView()
}
