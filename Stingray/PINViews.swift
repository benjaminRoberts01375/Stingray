//
//  PINViews.swift
//  Stingray
//
//  Created by Ben Roberts on 3/26/26.
//

import SwiftUI

public struct PINSetup: View {
    @State private var desiredPIN: String = ""
    @State private var pinConfirmation: String = ""
    @State private var contentIsFilled: Bool = false // Both the desired and confirmation fields have data
    @State private var error: String = ""
    
    @Environment(UserModel.self) var userModel: UserModel
    @Environment(\.dismiss) var dismiss
    
    public var body: some View {
        VStack {
            Text("Enter PIN")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
            SecureField("PIN", text: $desiredPIN)
                .onChange(of: self.desiredPIN) { _, newValue in
                    self.contentIsFilled = !newValue.isEmpty && !self.pinConfirmation.isEmpty
                    if self.contentIsFilled { self.checkPIN() }
                }
                .frame(width: 400)
            SecureField("PIN Confirmation", text: $pinConfirmation)
                .onChange(of: self.pinConfirmation) { _, newValue in
                    self.contentIsFilled = !newValue.isEmpty && !self.desiredPIN.isEmpty
                    if self.contentIsFilled { self.checkPIN() }
                }
                .frame(width: 400)
            Spacer()
            Button("Save PIN") {
                self.userModel.activeUser?.pin = self.desiredPIN
                self.dismiss()
            }
                .disabled(!self.contentIsFilled || !self.error.isEmpty)
            Text(self.error)
                .foregroundStyle(.red)
                .opacity(self.error.isEmpty ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Check the provided info, show an error if there's an issue
    func checkPIN() {
        if desiredPIN != pinConfirmation { self.error = "PINs do not match." }
        else { self.error = "" }
    }
}

public struct PINEntry: View {
    @Environment(\.dismiss) var dismiss
    @Environment(UserModel.self) var userModel: UserModel
    @Environment(ThemeModel.self) var themeModel
    
    /// Not read, only set to successfully login or switch users
    @Binding var loginState: LoginState
    /// User the PIN is meant for
    let user: User
    /// PIN attempt
    @State private var pinEntry: String = ""
    /// Reason to not allow sign-in
    @State private var error: String = ""
    
    public var body: some View {
        VStack {
            Text("Enter PIN for \(self.user.displayName)")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
            SecureField("PIN", text: $pinEntry)
                .frame(width: 400)
            Spacer()
            HStack {
                Button("Submit") {
                    if self.userModel.activeUser?.pin != self.pinEntry {
                        self.error = "Invalid PIN"
                        return
                    }
                    self.loginState = ProfilePickerView.switchUser(
                        user: self.user,
                        userModel: self.userModel,
                        currentLoginState: self.loginState,
                        themeModel: self.themeModel
                    )
                }
                .disabled(pinEntry.isEmpty)
                Button("Switch User...") { self.loginState = .pickingUser }
            }
            Text(self.error)
                .foregroundStyle(.red)
                .opacity(self.error.isEmpty ? 0 : 1)
        }
    }
}

public struct PINDelete: View {
    @Environment(\.dismiss) var dismiss
    @Environment(UserModel.self) var userModel: UserModel
    /// PIN attempt
    @State private var pinEntry: String = ""
    /// Reason to not allow sign-in
    @State private var error: String = ""
    
    public var body: some View {
        VStack {
            Text("Delete PIN for \(self.userModel.activeUser?.displayName ?? "Nobody")")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
            SecureField("PIN", text: $pinEntry)
                .frame(width: 400)
            Spacer()
            HStack {
                Menu("Delete PIN") {
                    Button("You absolutely want to delete the PIN?", role: .destructive) {
                        if self.userModel.activeUser?.pin != self.pinEntry {
                            self.error = "Invalid PIN"
                            return
                        }
                        self.userModel.activeUser?.pin = nil
                        self.dismiss()
                    }
                    .disabled(pinEntry.isEmpty)
                }
            }
            Text(self.error)
                .foregroundStyle(.red)
                .opacity(self.error.isEmpty ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
