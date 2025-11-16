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
        }
    }
}
