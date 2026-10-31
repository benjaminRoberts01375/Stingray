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
    private let exampleMedia = MediaStorage.example(ExampleMedia(title: "Example"))
    /// Serves bundled sample posters in place of a real server
    private let exampleService = ExampleStreamingService()
    
    @Environment(ThemeModel.self) private var theme
    
    public var body: some View {
        HStack(alignment: .center, spacing: 20) {
            MediaCard(
                media: self.exampleMedia,
                streamingService: self.exampleService,
                reserveTextSpace: false
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

/// Some media designed to be displayed as an example
fileprivate final class ExampleMedia: MovieProtocol {
    public let sortTitle: String
    public let tagline: String?
    public let maturity: String?
    public let releaseDate: Date?
    public var genres: Set<String>
    public let duration: Duration?
    public let description: String
    public let people: [any MediaPersonProtocol]
    public let id: String
    public let parentID: String
    public let title: String
    public let imageBlurHashes: (any MediaImagesProtocol)?
    public let imageTags: (any MediaImagesProtocol)?
    public let mediaSources: [any MediaSourceProtocol]
    public let specialFeatures: SpecialFeaturesStatus

    public static func == (lhs: ExampleMedia, rhs: ExampleMedia) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Creates example media with fixed placeholder metadata, used by the theme previews.
    /// - Parameter title: Title to display
    public init(title: String) {
        self.title = title
        self.sortTitle = title
        self.tagline = "A short tagline"
        self.maturity = "NA"
        self.releaseDate = Date.now
        self.genres = ["Drama", "Fantasy"]
        self.duration = .seconds(90 * 60) // 90 minutes
        self.description = "A wonderful story"
        self.people = []
        self.id = UUID().uuidString
        self.parentID = UUID().uuidString
        self.imageBlurHashes = nil
        self.imageTags = MediaImages(thumbnail: "Example", logo: "Example", primary: "Example")
        self.mediaSources = []
        self.specialFeatures = .loaded([])
    }

    public func loadSpecialFeatures(specialFeatures: [SpecialFeature]) { } // Example media has no special features
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
