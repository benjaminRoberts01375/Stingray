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
    /// Controls the pin configuration screen showing and hiding
    @State private var showPinSetup: Bool = false
    /// Controls when to show a dialog box for logging out
    @State private var showLogoutAlert: Bool = false
    
    @Environment(UserModel.self) private var userModel: UserModel
    
    @Environment(PurchasesModel.self) private var purchases: PurchasesModel
    /// Controls the sheet to show the supporting Stingray screen
    @State private var showSupportStingray: Bool = false
    
    public var body: some View {
        @Bindable var settings = settings
        Form {
            // MARK: Profiles
            // Profile picker
            Section(header: Text("Account").bold()) {
                ProfilePickerView(loginState: $loginState)
                    .focusSection()
                // PIN button
                DoubleButton(label: "PIN", sublabel: self.settings.pin == nil ? "Configure..." : "Configured") {
                    self.showPinSetup = true
                }
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
                if let user = self.userModel.activeUser {
                    DoubleButton(label: "Logout...", sublabel: "", role: .destructive) { self.showLogoutAlert = true }
                        .alert("Logout \(user.displayName)", isPresented: $showLogoutAlert) {
                            Button("Logout", role: .destructive) {
                                self.userModel.deleteUser(user.id)
                                if self.userModel.userIDs.isEmpty { self.loginState = .loggedOut }
                                else { self.loginState = .pickingUser }
                            }
                        } message: { Text("Are you sure you want \(user.displayName) to logout?") }
                }
            }
            
            // Profile switching
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
                    ThemesListView(themeType: .light)
                }
                // Dark mode
                DoubleMenu(label: "Dark Mode", sublabel: self.settings.themeDark.displayName) {
                    ThemesListView(themeType: .dark)
                }
            }
            
            // MARK: Accessibility
            Section( header: Text("Accessibility").bold() ) {
                DoubleButton(label: "Load Poster Art", sublabel: self.settings.loadThumbnailArt ? "Enabled" : "Disabled") {
                    self.settings.loadThumbnailArt.toggle()
                }
                DoubleButton(label: "Load Media Backgrounds", sublabel: self.settings.loadMediaBackgroundArt ? "Enabled" : "Disabled") {
                    self.settings.loadMediaBackgroundArt.toggle()
                }
                DoubleButton(label: "Replace Logos with Text", sublabel: self.settings.replaceLogosWithText ? "Enabled" : "Disabled") {
                    self.settings.replaceLogosWithText.toggle()
                }
            }
            
            // MARK: Supporting Stingray
            Section( header: Text("Support Stingray").bold() ) {
                DoubleButton(
                    label: "Support Stingray",
                    sublabel: {
                        switch self.purchases.products {
                        case .failed: return "Error loading products"
                        case .fetching, .waiting: return "Loading..."
                        case .ready: 
                            return self.purchases.boughtSupporter ? "Thanks for supporting Stingray!" : "Become a supporter..."
                        }
                    }(),
                    action: {
                        switch self.purchases.products {
                        case .ready: self.showSupportStingray = true
                        default: break
                        }
                    }
                )
                .fullScreenCover(isPresented: $showSupportStingray) {
                    SupportStingrayView()
                        .stingrayBackground()
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

/// Lists all available themes and allows the user to update their theme preferences
public struct ThemesListView: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(PurchasesModel.self) private var purchases
    
    /// Is the list meant to set dark or light mode themes
    public let themeType: ColorScheme
    
    public var body: some View {
        ForEach(ThemeModel.Themes.allCases, id: \.self) { option in
            Button {
                if !self.purchases.boughtSupporter && option.requiresSupporter {
                    Log.critical("Not a supporter!")
                }
                else if self.themeType == .dark { self.settings.themeDark = option }
                else { self.settings.themeLight = option }
            }
            label: {
                let currentTheme = self.themeType == .dark ? self.settings.themeDark : self.settings.themeLight
                if currentTheme == option {
                    Label(option.displayName, systemImage: "checkmark")
                    Text(option.description)
                }
                else if option.requiresSupporter && !self.purchases.boughtSupporter {
                    Label(option.displayName, systemImage: "lock.fill")
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
