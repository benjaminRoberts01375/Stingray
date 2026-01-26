//
//  Error-View.swift
//  Stingray
//
//  Created by Ben Roberts on 1/26/26.
//

import SwiftUI

/// Shows a simple error and can expand into a full verbose error log.
public struct ErrorView: View {
    /// Recursive error thrown by Stingray
    let error: RError
    /// User-facing error to show before expanding
    let summary: String
    /// Tracks whether or not the error has been expanded
    @State private var isExpanded: Bool = false
    
    public var body: some View {
        Button { self.isExpanded = true }
        label: { ErrorSummaryView(summary: summary) }
            .buttonStyle(.plain)
            .padding()
            .sheet(isPresented: $isExpanded) { ErrorExpandedView(error: error) }
    }
}

/// Show a summary of a greater error.
fileprivate struct ErrorSummaryView: View {
    /// User-facing error to show before expanding
    let summary: String
    
    var body: some View {
        Text(summary)
            .foregroundStyle(.red)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.red, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.red.opacity(0.25))
                    )
            }
    }
}

/// Show a verbose version of an RError
fileprivate struct ErrorExpandedView: View {
    /// Verbose error thrown by Stingray
    let error: RError
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Error:")
            Text(error.rDescription())
        }
        .padding(.horizontal, 50)
        .padding(.vertical, 20)
    }
}

#Preview {
    ErrorSummaryView(summary: "Stingray went kaplooey.")
}

#Preview {
    ErrorSummaryView(summary: "Stingray went kaplooey.")
        .sheet(isPresented: .constant(true)) {
            ErrorExpandedView(error: NetworkError.decodeJSONFailed(JSONError.missingKey("Nerd", "Preview"), url: nil))
        }
}
