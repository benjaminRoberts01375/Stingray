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
    /// Bindable wrapper for the settings model to enable two-way binding
    @Bindable var settingsModel = SettingsModel.shared
    
    public var body: some View {
        Form {
            Section(header: Text("Account").bold()) {
                ProfilePickerView(loginState: $loginState)
                    .focusSection()
            }
            
            Section(
                header: Text("Profile Switching").bold(),
                footer: Text(SettingsModel.shared.profileSwitchingMethod.description)
            ) {
                Picker("Profile Switching", selection: $settingsModel.profileSwitchingMethod) {
                    ForEach(SettingsModel.ProfileSwitching.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .focusSection()
            }
            .padding()
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
            return "Sync with tvOS"
        }
    }
    
    /// More thorough description of the selected values.
    var description: String {
        switch self {
        case .askOnLaunch: return "You'll be prompted for your choice in Jellyfin account on each launch."
        case .manual: return "Whoever was last signed in will remain signed in."
        case .syncWithTVOS: return "Jellyfin accounts will be mapped to users on this Apple TV."
        }
    }
}
