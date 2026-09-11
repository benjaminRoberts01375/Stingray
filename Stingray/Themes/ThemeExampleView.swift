//
//  ThemeExampleView.swift
//  Stingray
//
//  Created by Ben Roberts on 4/12/26.
//

import SwiftUI

/// A non-interactive preview of the current theme, showing a sample card alongside the theme's name and description.
/// Reads the theme from the environment, so wrapping it in `.environment(someThemeModel)` renders that theme instead of the user's.
public struct ThemeExampleView: View {
    /// Placeholder media so the card has a title and artwork to render
    private let exampleMedia = ExampleMedia(title: "Example")
    /// Serves bundled sample posters in place of a real server
    private let exampleService = ExampleStreamingService()
    
    @Environment(ThemeModel.self) private var theme
    
    public var body: some View {
        HStack(alignment: .center, spacing: 20) {
            MediaCard(
                media: self.exampleMedia,
                streamingService: self.exampleService,
                reserveTextSpace: false,
                size: CGSize(width: 150, height: 255)
            )
            .padding(.horizontal, 17)
            VStack(alignment: .leading) {
                Text(self.theme.currentTheme.representation.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(self.theme.currentTheme.header1)
                Text("Ain't it great?")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(self.theme.currentTheme.header2)
                Text(self.theme.currentTheme.representation.description)
                    .foregroundStyle(self.theme.currentTheme.labelPrimary)
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .focusable(false)
    }
}

/// Load example art work
fileprivate final class ExampleStreamingService: MediaImageProviding {
    public func getImageURL(imageType: MediaImageType, mediaID: String, width: Int) -> URL? {
        let poster: String = [
            "Agent-poster",
            "BBB-poster",
            "Charge-poster",
            "Coffee-poster",
            "Cosmos-poster",
            "Glass-poster",
            "Hero-poster",
            "Llama-poster",
            "Llama3-poster",
            "SF-poster",
            "Sintel-poster",
            "Spring-poster",
            "TOS-poster",
            "WingIt-poster"
        ].randomElement() ?? "Agent-poster"
        Log.debug("Loaded poster: \(poster)")
        return Bundle.main.url(forResource: poster, withExtension: "jpg")
    }
}
