//
//  Metadata.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import SwiftUI

/// Displays a synopsis of the provided media
public struct MediaOverview: View {
    @Environment(ThemeModel.self) private var theme
    @FocusState private var isFocused: Bool
    
    /// What to read the synopsis from
    public let media: any MediaProtocol
    
    public var body: some View {
        Button {} label: {
            VStack(alignment: .leading) {
                if !media.description.isEmpty {
                    Text("Overview")
                        .font(.headline.bold())
                        .lineLimit(2)
                        .foregroundStyle(
                            self.isFocused ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                        )
                    Text(media.description)
                        .multilineTextAlignment(.leading)
                }
                else {
                    Text("No description available")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .focused($isFocused, equals: true)
    }
}

/// Displays data about the provided media
public struct MediaMetadata: View {
    @Environment(ThemeModel.self) private var theme
    @FocusState private var isFocused: Bool
    
    /// What to read metadata for
    public let media: any MediaProtocol
    
    public var body: some View {
        Button {} label: {
            VStack(alignment: .leading, spacing: 16) {
                if !media.genres.isEmpty || media.releaseDate != nil || media.maturity != nil {
                    if !media.genres.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Genres")
                                .font(.headline.bold())
                                .lineLimit(2)
                                .foregroundStyle(
                                    self.isFocused ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                                )
                            Text(media.genres.joined(separator: ", "))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    if let releaseDate = media.releaseDate {
                        VStack(alignment: .leading) {
                            Text("Released")
                                .font(.headline.bold())
                                .lineLimit(2)
                                .foregroundStyle(
                                    self.isFocused ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                                )
                            Text(String(Calendar.current.component(.year, from: releaseDate)))
                                .lineLimit(1)
                        }
                    }
                    if let maturity = media.maturity {
                        Text("Maturity")
                            .font(.headline.bold())
                            .lineLimit(1)
                            .foregroundStyle(
                                self.isFocused ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                            )
                        Text(maturity)
                            .lineLimit(1)
                    }
                }
                else {
                    Text("No metadata available")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .focused($isFocused, equals: true)
    }
}
