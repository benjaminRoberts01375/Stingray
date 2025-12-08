//
//  StingrayApp.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

@main
struct StingrayApp: App {
    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024, // 100 MB
            diskCapacity: 1024 * 1024 * 1024 // 1 GB
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background {
                     LinearGradient(
                        colors: [Color(red: 0, green: 0.145, blue: 0.223), Color(red: 0, green: 0.063, blue: 0.153)],
                         startPoint: .top,
                         endPoint: .bottom
                     )
                }
                .ignoresSafeArea()
        }
    }
}
