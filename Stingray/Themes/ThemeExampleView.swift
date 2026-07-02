//
//  ThemeExampleView.swift
//  Stingray
//
//  Created by Ben Roberts on 4/12/26.
//

import SwiftUI

public struct ThemeExampleView: View {
    private let exampleMedia = ExampleMedia(title: "Example Show")
    private let exampleService = ExampleStreamingService()
    
    @Environment(ThemeModel.self) private var theme
    
    public var body: some View {
        HStack(alignment: .center, spacing: 20) {
            MediaCard(media: self.exampleMedia, streamingService: self.exampleService, reserveTextSpace: false)
                .frame(width: 150, height: 225)
                .padding(.horizontal, 20)
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
