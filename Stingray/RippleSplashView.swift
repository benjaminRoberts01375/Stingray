//
//  RippleSplashView.swift
//  Stingray
//
//  Animated splash screen with expanding ripple effect.
//

import SwiftUI

/// Animated splash view with expanding ripple circles and the Stingray logo
struct RippleSplashView: View {
    @State private var ripplePhase: CGFloat = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    
    // Number of ripple rings
    private let rippleCount = 4
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient matching app theme
                LinearGradient(
                    colors: [
                        Color(red: 0, green: 0.145, blue: 0.223),
                        Color(red: 0, green: 0.063, blue: 0.153)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Ripple circles expanding from center
                ForEach(0..<rippleCount, id: \.self) { index in
                    RippleCircle(
                        phase: ripplePhase,
                        index: index,
                        totalCount: rippleCount,
                        maxRadius: max(geometry.size.width, geometry.size.height)
                    )
                }
                
                // Center logo/icon
                VStack(spacing: 16) {
                    // App icon - using a stingray-like shape
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 100, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Text("Stingray")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Animate logo entrance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Animate ripples continuously
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            ripplePhase = 1.0
        }
    }
}

/// Individual ripple circle that expands and fades
private struct RippleCircle: View {
    let phase: CGFloat
    let index: Int
    let totalCount: Int
    let maxRadius: CGFloat
    
    var body: some View {
        Circle()
            .stroke(
                Color.white.opacity(opacity),
                lineWidth: 2
            )
            .frame(width: radius, height: radius)
            .opacity(circleOpacity)
    }
    
    /// Staggered phase for each ring (0.0 to 1.0)
    private var staggeredPhase: CGFloat {
        let offset = CGFloat(index) / CGFloat(totalCount)
        let adjusted = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return adjusted
    }
    
    /// Current radius based on animation phase
    private var radius: CGFloat {
        let minRadius: CGFloat = 50
        return minRadius + (maxRadius - minRadius) * staggeredPhase
    }
    
    /// Opacity decreases as circle expands
    private var circleOpacity: Double {
        return max(0, 1.0 - Double(staggeredPhase))
    }
    
    /// Stroke opacity
    private var opacity: Double {
        return 0.4 * circleOpacity
    }
}

// MARK: - App Settings Manager

/// Simple manager for app-wide settings
final class AppSettings {
    static let shared = AppSettings()
    
    private let storage: BasicStorageProtocol
    
    private init() {
        self.storage = DefaultsBasicStorage()
    }
    
    /// Whether to show the splash animation on app launch
    /// Defaults to true for new users
    var showSplashAnimation: Bool {
        get {
            // Check if the key has ever been set
            let key = StorageKeys.showSplashAnimation.rawValue
            if UserDefaults.standard.object(forKey: key) == nil {
                // First launch - default to true
                return true
            }
            return storage.getBool(.showSplashAnimation, id: "")
        }
        set {
            storage.setBool(.showSplashAnimation, id: "", value: newValue)
        }
    }
}

// MARK: - Preview

#Preview {
    RippleSplashView()
}
