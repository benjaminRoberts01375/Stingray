//
//  UserView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/17/25.
//

import SwiftUI

public struct SettingsView: View {
    /// Tracks if the user has logged in, is about to login, or needs to login.
    @Binding public var loginState: LoginState
    /// System-wide settings
    @Environment(SettingsModel.self) private var settings: SettingsModel
    /// Controlls the pin configuration screen showing and hiding
    @State private var showPinSetup: Bool = false
    
    public var body: some View {
        @Bindable var settings = settings
        Form {
            // MARK: Profiles
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
                    .padding(.horizontal)
                }
                .buttonStyle(StingrayFormButtonStyle())
                .fullScreenCover(isPresented: $showPinSetup) {
                    if self.settings.pin == nil {
                        PINSetup()
                            .padding(64)
                            .stingrayBackground()
                    } else {
                        PINDelete()
                            .padding(64)
                            .stingrayBackground()
                    }
                }
            }
            
            // Profile selection
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
            
            // MARK: Playback settings
            Section( header: Text("Playback Settings").bold() ) {
                DoubleButton(label: "Autoplay Next Episode", sublabel: self.settings.autoplay ? "Enabled" : "Disabled") {
                    self.settings.autoplay.toggle()
                }
                DoubleMenu(
                    label: "Target Video Bitrate",
                    sublabel: settings.bitrate == nil ? "Maximum" : "Limited to \(Int.formatMegabitsPerSec(settings.bitrate))"
                ) {
                    ForEach([nil] + SettingsModel.bitrateOptions, id: \.self) { bitrateOption in
                        Button { settings.bitrate = bitrateOption }
                        label: {
                            if settings.bitrate == bitrateOption {
                                Label(Int.formatMegabitsPerSec(bitrateOption), systemImage: "checkmark")
                            }
                            else { Text(Int.formatMegabitsPerSec(bitrateOption)) }
                        }
                    }
                }
                DoubleMenu(label: "Playback Speed", sublabel: self.settings.playbackSpeed.name) {
                    ForEach(PlaybackSpeed.allCases, id: \.value) { speed in
                        Button { settings.playbackSpeed = speed }
                        label: {
                            if settings.playbackSpeed == speed {
                                Label(speed.name, systemImage: "checkmark")
                            }
                            else { Text(speed.name) }
                        }
                    }
                }
            }
            
            // MARK: Themes
            Section( header: Text("Themes").bold() ) {
                // Light mode
                DoubleMenu(label: "Light Mode", sublabel: self.settings.themeLight.displayName) {
                    ForEach(ThemeModel.Themes.allCases, id: \.self) { option in
                        Button { self.settings.themeLight = option }
                        label: {
                            if self.settings.themeLight == option {
                                Label(option.displayName, systemImage: "checkmark")
                                Text(option.description)
                            }
                            else {
                                Text(option.displayName)
                                Text(option.description)
                            }
                        }
                    }
                }
                // Dark mode
                DoubleMenu(label: "Dark Mode", sublabel: self.settings.themeDark.displayName) {
                    ForEach(ThemeModel.Themes.allCases, id: \.self) { option in
                        Button { self.settings.themeDark = option }
                        label: {
                            if self.settings.themeDark == option {
                                Label(option.displayName, systemImage: "checkmark")
                                Text(option.description)
                            }
                            else {
                                Text(option.displayName)
                                Text(option.description)
                            }
                        }
                    }
                }
            }
            
            // MARK: Accessibility
            Section( header: Text("Accessibility").bold() ) {
                DoubleButton(label: "Load Poster Art", sublabel: self.settings.loadThumbnailArt ? "Enabled" : "Disabled") {
                    self.settings.loadThumbnailArt.toggle()
                }
            }
            
            // MARK: Connection info
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
    public var displayName: String {
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
    public var description: String {
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
