//
//  StingrayApp.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

/// The beginning of something awesome
@main
public struct StingrayApp: App {
    /// Enlarges the shared URL cache so artwork survives scrolling through a large library.
    public init() {
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024, // 100 MB
            diskCapacity: 1024 * 1024 * 1024 // 1 GB
        )
    }
    
    public var body: some Scene {
        WindowGroup { self.loadApp() }
    }
    
    /// Builds the root view, falling back to an error screen when setup failed.
    /// - Returns: `ContentView` on success, otherwise an `ErrorView` describing the setup failure
    @ViewBuilder
    public func loadApp() -> some View {
        switch makeContentView() { // We can't use do/catch directly in the ViewBuilder function
        case .success(let view): view
        case .failure(let error): ErrorView(error: error, summary: "Failed to setup Stingray")
        }
    }
    
    /// Attempts to build the root view, converting a throwing init into a value a `ViewBuilder` can switch over.
    /// - Returns: The configured `ContentView`, or the error that stopped it from being created
    public func makeContentView() -> Result<ContentView, SetupErrors> { // Cheating the type system a bit
        do { return .success(try ContentView()) }
        catch { return .failure(error) }
    }
}
