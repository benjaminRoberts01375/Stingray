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
            MediaCard(media: self.exampleMedia, streamingService: self.exampleService) { }
                .frame(width: MediaCard.cardSize.width, height: 225)
                .padding(.horizontal, 20)
            VStack(alignment: .leading) {
                Text(self.theme.currentTheme.representation.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(self.theme.currentTheme.header1())
                Text("Ain't it great?")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(self.theme.currentTheme.header2())
                Text(self.theme.currentTheme.representation.description)
                    .foregroundStyle(self.theme.currentTheme.labelPrimary())
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .focusable(false)
    }
}
