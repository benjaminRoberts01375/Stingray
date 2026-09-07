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
    @State private var showPinSetup: Bool
    /// Controls when to show a dialog box for logging out
    @State private var showLogoutAlert: Bool

    public var userModel: UserModelProtocol

    public let user: UserProtocol

    @Environment(PurchasesModel.self) private var purchases: PurchasesModel
    /// Controls the sheet to show the supporting Stingray screen
    @State private var showSupportStingray: Bool
    /// Controlls the sheet to show the current session's logs
    @State private var showLogs: Bool

    @State private var showRefreshLogin: Bool

    @State private var enterPIN: PINModel

    @State private var showResetSettings: Bool

    public let streamingService: UserProviding
    
    /// Create a SettingsView view for altering user and app settings
    /// - Parameters:
    ///   - loginState: The login state machine
    ///   - userModel: Location where all users are stored
    ///   - user: User to load preferences for
    ///   - streamingService: Current connection to server
    public init(loginState: Binding<LoginState>, userModel: UserModelProtocol, user: UserProtocol, streamingService: UserProviding) {
        self.showPinSetup = false
        self.showLogoutAlert = false
        self.showSupportStingray = false
        self.showLogs = false
        self.showRefreshLogin = false
        self.showResetSettings = false
        self._loginState = loginState
        self.userModel = userModel
        self.user = user
        self.streamingService = streamingService
        self.enterPIN = PINModel(for: user)
    }

    public var body: some View {
        @Bindable var settings = settings
        Form {
            // MARK: Profiles
            // Profile picker
            Section(header: Text(String(localized: "Account")).bold()) {
                ProfilePickerView(loginState: $loginState, userModel: self.userModel)
                    .focusSection()
                // PIN button
                DoubleButton(label: "PIN", sublabel: self.settings.pin == nil ? "Configure..." : "Configured") {
                    self.showPinSetup = true
                }
                .fullScreenCover(isPresented: $showPinSetup) {
                    if self.settings.pin == nil {
                        PINSetup(user: self.user)
                            .padding(64)
                            .stingrayBackground()
                            .ignoresSafeArea()
                    } else {
                        PINDelete(user: self.user)
                            .padding(64)
                            .stingrayBackground()
                            .ignoresSafeArea()
                    }
                }
                DoubleButton(label: "Update Login...", sublabel: "") { self.showRefreshLogin = true }
                    .fullScreenCover(isPresented: $showRefreshLogin) {
                        AddServerView(loginState: $loginState, userModel: self.userModel) // This view updates existing users access
                            .padding(64)
                            .stingrayBackground()
                            .ignoresSafeArea()
                    }
                DoubleButton(label: "Logout...", sublabel: "", role: .destructive) { self.showLogoutAlert = true }
                    .alert(
                        Text(String(localized: "Logout \(user.displayName)")),
                        isPresented: $showLogoutAlert
                    ) {
                        Button("Logout", role: .destructive) {
                            Task {
                                if self.user.pin != nil {
                                    self.enterPIN.isPresented = true
                                    switch await enterPIN.status {
                                    case .success: self.enterPIN = PINModel(for: self.user)
                                    case .canceled:
                                        self.enterPIN = PINModel(for: self.user)
                                        return
                                    }
                                }
                                self.userModel.deleteUser(user.id)
                                await self.streamingService.logout()
                                if self.userModel.userIDs.isEmpty { self.loginState = .loggedOut }
                                else { self.loginState = .pickingUser }
                            }
                        }
                    }
                message: { Text(String(localized: "Are you sure you want \(user.displayName) to logout?")) }
                    .fullScreenCover(isPresented: self.$enterPIN.isPresented) {
                        PINEntry(model: self.enterPIN)
                            .padding(64)
                            .stingrayBackground()
                            .ignoresSafeArea()
                    }
                DoubleButton(label: "Reset Settings...", sublabel: "", role: .destructive) { self.showResetSettings = true }
                    .alert(
                        Text(String(localized: "Reset Settings")),
                        isPresented: self.$showResetSettings
                    ) {
                        Button("Reset", role: .destructive) {
                            Task {
                                if self.user.pin != nil {
                                    switch await self.enterPIN.status {
                                    case .success: self.enterPIN = PINModel(for: self.user)
                                    case .canceled:
                                        self.enterPIN = PINModel(for: self.user)
                                        return
                                    }
                                }
                                self.userModel.reset(user: self.user)
                                self.settings.bitrate = nil
                                self.settings.profileSwitchingMethod = .askOnLaunch
                            }
                        }
                    }
                message: {
                    Text(String(localized: "Are you sure you want to reset all settings to default for \(self.user.displayName)"))
                }
                .fullScreenCover(isPresented: self.$enterPIN.isPresented) {
                    PINEntry(model: self.enterPIN)
                        .padding(64)
                        .stingrayBackground()
                        .ignoresSafeArea()
                }
            }

            // Profile switching
            Section(
                header: Text(String(localized: "Profile Switching")).bold(),
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
            Section(header: Text(String(localized: "Playback Settings")).bold()) {
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
                DoubleMenu(label: "Playback Speed", sublabel: LocalizedStringKey(self.settings.playbackSpeed.name)) {
                    ForEach(PlaybackSpeed.allCases, id: \.value) { speed in
                        Button { settings.playbackSpeed = speed }
                        label: {
                            if settings.playbackSpeed == speed { Label(speed.name, systemImage: "checkmark") }
                            else { Text(speed.name) }
                        }
                    }
                }
            }

            // MARK: Filters and Sorting
            Section(header: Text(String(localized: "Filters and Sorting")).bold()) {
                DoubleButton(label: "Display Sorting Options", sublabel: self.settings.showSorting ? "Enabled" : "Disabled") {
                    self.settings.showSorting.toggle()
                }
                DoubleButton(label: "Display Filter Options", sublabel: self.settings.showFilters ? "Enabled" : "Disabled") {
                    self.settings.showFilters.toggle()
                }
                DoubleButton(label: "Display Refresh Library Button", sublabel: self.settings.showRefreshLibrary ? "Enabled" : "Disabled") {
                    self.settings.showRefreshLibrary.toggle()
                }
                DoubleButton(label: "Search TV Episode Titles", sublabel: self.settings.searchEpisodeTitles ? "Enabled" : "Disabled") {
                    self.settings.searchEpisodeTitles.toggle()
                }
            }

            // MARK: Themes
            Section(header: Text(String(localized: "Themes")).bold()) {
                // Light mode
                DoubleMenu(label: "Light Mode", sublabel: self.settings.themeLight.displayName) {
                    ThemesListView(showSupportStingray: $showSupportStingray, themeType: .light)
                }
                // Dark mode
                DoubleMenu(label: "Dark Mode", sublabel: self.settings.themeDark.displayName) {
                    ThemesListView(showSupportStingray: $showSupportStingray, themeType: .dark)
                }
            }

            // MARK: Accessibility
            Section(header: Text(String(localized: "Accessibility")).bold()) {
                DoubleMenu(label: "Language", sublabel: self.settings.langauge?.languageDisplayName ?? LocalizedStringKey("System")) {
                    Button { self.settings.langauge = nil } // Use language from the Apple TV
                    label: {
                        if self.settings.langauge == nil { Label("System", systemImage: "checkmark") }
                        else { Text("System") }
                    }
                    Divider()
                    ForEach(SupportedLanguages.allCases, id: \.languageCode) { language in
                        Button { self.settings.langauge = language.locale }
                        label: {
                            if self.settings.langauge?.language.languageCode?.identifier == language.languageCode {
                                Label(language.name ?? String(localized: "Unknown"), systemImage: "checkmark")
                            }
                            else { Text(language.name ?? String(localized: "Unknown")) }
                        }
                    }
                }
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
            Section(header: Text(String(localized: "Support Stingray")).bold()) {
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
                        .ignoresSafeArea()
                }
                DoubleButton(label: "Logs", sublabel: "Open Logs...") { self.showLogs = true }
                    .fullScreenCover(isPresented: $showLogs) {
                        LogsView()
                            .stingrayBackground()
                            .ignoresSafeArea()
                    }
            }

            // MARK: Connection info
            Section {
                switch loginState {
                case .loggedIn(let streamingService, _):
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
    @Binding public var showSupportStingray: Bool

    /// Is the list meant to set dark or light mode themes
    public let themeType: ColorScheme

    public var body: some View {
        ForEach(Themes.allCases, id: \.self) { option in
            Button {
                if !self.purchases.boughtSupporter && option.requiresSupporter {
                    self.showSupportStingray = true
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

public enum SupportedLanguages: CaseIterable {
    case english
    case german

    /// The name of the language in the language it is
    public var name: String? { self.locale.localizedString(forLanguageCode: self.languageCode) }

    /// Country code of the language
    public var languageCode: String {
        switch self {
        case .english: return "en"
        case .german: return "de"
        }
    }

    /// A locale object from this language
    public var locale: Locale { Locale(identifier: self.languageCode) }
}
