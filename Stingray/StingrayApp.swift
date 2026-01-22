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
            LaunchHostView {
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
}

/// Wrapper view that shows the splash animation on app launch
private struct LaunchHostView<Content: View>: View {
    private let content: Content
    
    /// Whether splash animation is enabled in settings
    private let splashEnabled: Bool
    
    @State private var showSplash: Bool

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        // Read setting at init time
        self.splashEnabled = AppSettings.shared.showSplashAnimation
        // Initialize state based on setting
        _showSplash = State(initialValue: AppSettings.shared.showSplashAnimation)
    }

    var body: some View {
        ZStack {
            content

            if showSplash && splashEnabled {
                RippleSplashView()
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .opacity.combined(with: .scale(scale: 1.1))
                    ))
                    .zIndex(10)
            }
        }
        .task {
            guard splashEnabled else { return }
            
            // Keep splash visible briefly on cold start
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            withAnimation(.easeOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }
}
