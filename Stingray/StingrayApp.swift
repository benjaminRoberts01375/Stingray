//
//  StingrayApp.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

@main
public struct StingrayApp: App {
    public init() {
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024, // 100 MB
            diskCapacity: 1024 * 1024 * 1024 // 1 GB
        )
    }
    
    public var body: some Scene {
        WindowGroup {
            loadApp()
        }
    }
    
    @ViewBuilder
    public func loadApp() -> some View {
        switch makeContentView() { // We can't use do/catch directly in the ViewBuilder function
        case .success(let view): view
        case .failure(let error): ErrorView(error: error, summary: "Failed to setup Stingray")
        }
    }
    
    public func makeContentView() -> Result<ContentView, SetupErrors> { // Cheating the type system a bit
        do { return .success(try ContentView()) }
        catch { return .failure(error) }
    }
}
