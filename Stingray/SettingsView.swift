//
//  UserView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/17/25.
//

import SwiftUI

public struct SettingsView: View {
    /// Tracks if the user has logged in, is about to login, or needs to login.
    @Binding var loginState: LoginState
    /// System-wide settings
    @Environment(SettingsModel.self) var settings: SettingsModel
    /// Controlls the pin configuration screen showing and hiding
    @State private var showPinSetup: Bool = false
    
    public var body: some View {
        @Bindable var settings = settings
        Form {
            // Profile picker
            Section(header: Text("Account").bold()) {
                ProfilePickerView(loginState: $loginState)
                    .focusSection()
                Button { self.showPinSetup = true }
                label: {
                    HStack {
                        Text("PIN")
                        Spacer()
                        Text(self.settings.pin == nil ? "Configure..." : "Configured")
                    }
                }
                .padding(.horizontal)
                .fullScreenCover(isPresented: $showPinSetup) {
                    if self.settings.pin == nil {
                        PINSetup()
                            .padding(128)
                            .stingrayBackground()
                    } else {
                        PINDelete()
                            .padding(128)
                            .stingrayBackground()
                    }
                }
            }
            
            Section(
                header: Text("Profile Switching").bold(),
                footer: Text(self.settings.profileSwitchingMethod.description)
            ) {
                Picker("Profile Switching", selection: $settings.profileSwitchingMethod) {
                    ForEach(SettingsModel.ProfileSwitching.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .focusSection()
            }
            .listRowBackground(Color.clear)
            
            // Playback settings
            Section( header: Text("Playback Settings").bold() ) {
                Menu {
                    ForEach([nil] + SettingsModel.bitrateOptions, id: \.self) { bitrateOption in
                        Button { settings.bitrate = bitrateOption }
                        label: {
                            if settings.bitrate == bitrateOption {
                                Label(Int.formatMegabitsPerSec(bitrateOption), systemImage: "checkmark")
                            }
                            else { Text(Int.formatMegabitsPerSec(bitrateOption)) }
                        }
                    }
                } label: {
                    HStack {
                        Text("Target Video Bitrate")
                        Spacer()
                        Text(settings.bitrate == nil ? "Maximum" : "Limited to \(Int.formatMegabitsPerSec(settings.bitrate))")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, -20)
                .padding(.vertical, -10)
                .listRowBackground(Color.clear)
            }
            
            // Connection info
            Section {
                switch loginState {
                case .loggedIn(let streamingService):
                    VStack {
                        SystemInfoView(streamingService: streamingService)
                        LibrariesInfoView(streamingService: streamingService)
                    }
                    .frame(maxWidth: .infinity)
                default: EmptyView()
                }
            }
            .listRowBackground(Color.clear)
        }
    }
}

/// Readable versions of the profile switching options. Only used here so an extension was used.
extension SettingsModel.ProfileSwitching {
    /// Picker display name
    var displayName: String {
        switch self {
        case .askOnLaunch:
            return "Ask on Launch"
        case .manual:
            return "Manual"
        case .syncWithTVOS:
            return "Sync with tvOS (WIP)"
        case .askOnResume:
            return "Ask on Resume"
        }
    }
    
    /// More thorough description of the selected values.
    var description: String {
        switch self {
        case .askOnResume:
            return """
You'll be prompted for your choice of account when Jellyfin launches or opens from the background. 
This can be annoying to some and triggers on things like Control Center.
"""
        case .askOnLaunch: return "You'll be prompted for your choice of account on each launch. Typical of most streaming services."
        case .manual: return "Whoever was last signed in will remain signed in."
        case .syncWithTVOS: return "Jellyfin accounts will be mapped to users on this Apple TV."
        }
    }
}
