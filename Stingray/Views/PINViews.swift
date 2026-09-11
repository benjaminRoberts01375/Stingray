//
//  PINViews.swift
//  Stingray
//
//  Created by Ben Roberts on 3/26/26.
//

import SwiftUI

/// Creates a PIN for a profile, requiring it to be typed twice.
public struct PINSetup: View {
    /// First entry
    @State private var desiredPIN: String = ""
    /// Second entry, which must match
    @State private var pinConfirmation: String = ""
    @State private var contentIsFilled: Bool = false // Both the desired and confirmation fields have data
    @State private var error: String = ""

    /// User the PIN is being created for
    public let user: any UserProtocol
    /// Written to so that the new PIN reaches permanent storage
    @Environment(SettingsModel.self) private var settings
    @Environment(\.dismiss) private var dismiss

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
                self.settings.pin = self.desiredPIN
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
    public func checkPIN() {
        if desiredPIN != pinConfirmation { self.error = "PINs do not match." }
        else { self.error = "" }
    }
}

/// Tracks data about entering PINs
@Observable
public final class PINModel {
    /// Tracks if PIN entry is shown
    public var isPresented: Bool

    /// Resumed by `finish(_:)`; `nil` whenever nobody is waiting
    private var continuation: CheckedContinuation<Status, Never>?
    
    /// User to test against
    fileprivate var user: UserProtocol

    /// PIN successfulness
    public enum Status {
        /// The PIN was entered correctly
        case success
        /// The user did not enter the correct PIN
        case canceled
    }
    
    /// Create a model for storing PIN entry information
    public init(for user: UserProtocol) {
        self.user = user
        self.isPresented = false
        self.continuation = nil
    }

    /// Suspends until the PIN view reports back. One awaiting caller at a time.
    public var status: Status {
        get async {
            await withTaskCancellationHandler { await withCheckedContinuation { self.continuation = $0 } }
            onCancel: { Task { @MainActor in self.finish(.canceled) } }
        }
    }

    /// Hands `status` to the awaiting caller. Later calls are ignored, so reporting twice is harmless.
    fileprivate func finish(_ status: Status) {
        self.isPresented = false // Dismiss whatever cover is showing this model's PINEntry
        let continuation = self.continuation
        self.continuation = nil // Cleared first so a re-entrant call can't resume twice
        continuation?.resume(returning: status)
    }
}

/// Prompts for a profile's PIN and reports the outcome back through its `PINModel`.
/// Reports `.canceled` on disappear so a backing out doesn't leave the awaiting caller suspended forever, and short-circuits to `.success`
/// when the user has no PIN set.
public struct PINEntry: View {
    @Environment(SettingsModel.self) private var settings

    /// PIN attempt
    @State private var pinEntry: String = ""
    /// Reason to not allow sign-in
    @State private var error: String = ""

    /// Tracks the PIN entry attempt and reports the result back to the caller
    public let model: PINModel

    public var body: some View {
        VStack {
            Text("Enter PIN for \(self.model.user.displayName)")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
            SecureField("PIN", text: $pinEntry)
                .frame(width: 400)
            Spacer()
            HStack {
                Button("Submit") {
                    if self.model.user.pin != self.pinEntry {
                        self.error = "Invalid PIN"
                        return
                    }
                    self.model.finish(.success)
                }
                .disabled(pinEntry.isEmpty)
                Button("Cancel") { self.model.finish(.canceled) }
            }
            Text(self.error)
                .foregroundStyle(.red)
                .opacity(self.error.isEmpty ? 0 : 1)
        }
        .onAppear { // Escape if there is no PIN for a little safety
            if self.model.user.pin == nil { self.model.finish(.success) }
        }
        .onDisappear { self.model.finish(.canceled) } // If already fired, this is meaningless
    }
}

/// Removes a profile's PIN, requiring the current PIN plus a confirmation menu first.
public struct PINDelete: View {
    @Environment(\.dismiss) private var dismiss
    /// User the PIN is being removed from
    public let user: any UserProtocol
    /// Written to so that removing the PIN reaches permanent storage
    @Environment(SettingsModel.self) private var settings
    /// PIN attempt
    @State private var pinEntry: String = ""
    /// Reason to not allow sign-in
    @State private var error: String = ""

    public var body: some View {
        VStack {
            Text("Delete PIN for \(self.user.displayName)")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
            SecureField("PIN", text: $pinEntry)
                .frame(width: 400)
            Spacer()
            HStack {
                Menu("Delete PIN") {
                    Button("You absolutely want to delete the PIN?", role: .destructive) {
                        if self.settings.pin != self.pinEntry {
                            self.error = "Invalid PIN"
                            return
                        }
                        self.settings.pin = nil
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
