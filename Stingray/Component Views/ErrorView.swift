//
//  ErrorView.swift
//  Stingray
//
//  Created by Ben Roberts on 1/26/26.
//

import SwiftUI

/// Shows a simple error and can expand into a full verbose error log.
public struct ErrorView: View {
    /// Unloaded description for each of the errors
    public let errorDescriptions: [() -> String]
    /// User-facing error to show before expanding
    public let summary: String
    /// Tracks whether or not the error has been expanded
    @State private var isExpanded: Bool

    @FocusState private var isFocused: Bool

    /// Shows a large red banner error
    /// - Parameters:
    ///   - errors: Error that triggered the banner
    ///   - summary: Summary of the error
    ///   - isExpanded: Should the banner start by showing all the error details
    public init(error: RError, summary: String, isExpanded: Bool = false) {
        self.errorDescriptions = [error.rDescription]
        self.summary = summary
        self.isExpanded = isExpanded
    }
    
    /// Shows a large red banner error
    /// - Parameters:
    ///   - errors: Errors that triggered the banner
    ///   - summary: Summary of the errors
    ///   - isExpanded: Should the banner start by showing all the error details
    public init(errors: [RError], summary: String, isExpanded: Bool = false) {
        self.errorDescriptions = errors.map { $0.rDescription }
        self.summary = summary
        self.isExpanded = isExpanded
    }

    public var body: some View {
        Button { self.isExpanded = true }
        label: {
            Text(self.summary)
                .focused($isFocused, equals: true)
                .foregroundStyle(self.isFocused ? .black : .red)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(self.isFocused ? .clear : .red, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(self.isFocused ? .clear : .red.opacity(0.25))
                        )
                }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isExpanded) {
            if self.errorDescriptions.count == 1 { ErrorExpandedView(errorDesc: self.errorDescriptions[0]) }
            else { ErrorMultiExpandedView(errorDescs: self.errorDescriptions) }
        }
    }
}

/// A red button variant of the `ErrorView`
public struct ErrorButtonView: View {
    /// Lazily load descriptions for each of the errors
    private let errorDescriptions: [() -> String]
    /// User-facing warning shown on the button
    private let summary: String
    /// Tracks whether or not the errors have been expanded
    @State private var isExpanded: Bool

    /// Create a `ErrorButtonView` to display multiple errors
    /// - Parameters:
    ///   - errors: Underlying errors
    ///   - summary: Summary of the errors. It's recommended this is only a word or two
    ///   - isExpanded: Start expanded or collapsed
    public init(errors: [RError], summary: String, isExpanded: Bool = false) {
        self.summary = summary
        self.isExpanded = isExpanded
        self.errorDescriptions = errors.map { $0.rDescription }
    }

    /// Create a `ErrorButtonView` to display a single error
    /// - Parameters:
    ///   - errors: Underlying error
    ///   - summary: Summary of the error. It's recommended this is only a word or two
    ///   - isExpanded: Start expanded or collapsed
    public init(error: RError, summary: String, isExpanded: Bool = false) {
        self.summary = summary
        self.isExpanded = isExpanded
        self.errorDescriptions = [error.rDescription]
    }

    public var body: some View {
        Button { self.isExpanded = true }
        label: { Label(self.summary, systemImage: "exclamationmark.triangle.fill") }
            .foregroundStyle(.red)
            .sheet(isPresented: $isExpanded) {
                if self.errorDescriptions.count == 1 { ErrorExpandedView(errorDesc: self.errorDescriptions[0]) }
                else { ErrorMultiExpandedView(errorDescs: self.errorDescriptions) }
            }
    }
}

/// Show a verbose version of an RError
public struct ErrorExpandedView: View {
    /// Verbose error thrown by Stingray and is lazily evaluated
    public let errorDesc: () -> String

    public var body: some View {
        VStack(alignment: .leading) {
            Text("Error" + ":")
            Text(self.errorDesc())
        }
        .padding(.horizontal, 50)
        .padding(.vertical, 20)
    }
}

public struct ErrorMultiExpandedView: View {
    /// Verbose errors thrown by Stingray and is lazily evaluated
    public let errorDescs: [() -> String]

    public var body: some View {
        ForEach(Array(self.errorDescs.enumerated()), id: \.offset) { index, errorDesc in
            ScrollView {
                VStack(alignment: .leading) {
                    Button { } label: {
                        VStack(alignment: .leading) {
                            Text("Error #\(index + 1):")
                            Text(errorDesc())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 20)
                }
            }
        }
    }
}

#Preview("Single Preview") {
    ErrorView(error: NetworkError.decodeJSONFailed(nil, url: nil), summary: "Stingray went kaplooey")
}

#Preview("Single Expanded Sheet") {
    ErrorView(error: NetworkError.decodeJSONFailed(nil, url: nil), summary: "Stingray went kaplooey")
        .sheet(isPresented: .constant(true)) {
            ErrorExpandedView(errorDesc: NetworkError.decodeJSONFailed(JSONError.missingKey("Nerd", "Preview"), url: nil).rDescription)
        }
}

#Preview("Multi-Preview") {
    let repeated = NetworkError.decodeJSONFailed(JSONError.missingKey("Nerd", "Preview"), url: nil)
    let unique = NetworkError.decodeJSONFailed(JSONError.missingKey("Geek", "Preview"), url: nil)
    let rhett = NetworkError.decodeJSONFailed(JSONError.missingKey("Rhett", "Preview"), url: nil)
    let link = NetworkError.decodeJSONFailed(JSONError.missingKey("Link", "Preview"), url: nil)
    ErrorButtonView(errors: [repeated, unique, repeated, rhett, link], summary: "Failed to load some media")
}

#Preview("Multi-Expanded") {
    let repeated = NetworkError.decodeJSONFailed(JSONError.missingKey("Nerd", "Preview"), url: nil)
    let unique = NetworkError.decodeJSONFailed(JSONError.missingKey("Geek", "Preview"), url: nil)
    let rhett = NetworkError.decodeJSONFailed(JSONError.missingKey("Rhett", "Preview"), url: nil)
    let link = NetworkError.decodeJSONFailed(JSONError.missingKey("Link", "Preview"), url: nil)
    ErrorButtonView(errors: [repeated, unique, repeated, rhett, link], summary: "Failed to load some media", isExpanded: true)
}
