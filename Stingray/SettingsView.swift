//
//  UserView.swift
//  Stingray
//
//  Created by Ben Roberts on 12/17/25.
//

import SwiftUI

public struct SettingsView: View {
    @Binding var loginState: LoginState
    
    public var body: some View {
        ProfilePickerView(users: UserModel.shared.getUsers(), loginState: $loginState)
    }
}
