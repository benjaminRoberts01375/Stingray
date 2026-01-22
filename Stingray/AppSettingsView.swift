//
//  AppSettingsView.swift
//  Stingray
//
//  App-wide settings that users can configure.
//

import SwiftUI

/// View for configuring app-wide settings
struct AppSettingsView: View {
    @State private var showSplashAnimation: Bool = AppSettings.shared.showSplashAnimation
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $showSplashAnimation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Splash Animation")
                            .font(.body)
                        Text("Show ripple animation when launching the app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: showSplashAnimation) { _, newValue in
                    AppSettings.shared.showSplashAnimation = newValue
                }
            } header: {
                Text("Appearance")
            }
            
            Section {
                // Placeholder for future settings
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("More settings coming soon")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            } footer: {
                VStack(alignment: .center, spacing: 8) {
                    Text("Stingray")
                        .font(.headline)
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("Version \(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
    }
}
