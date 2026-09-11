//
//  Actors.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import SwiftUI

/// A horizontally scrolling row of cast and crew, with names that marquee while focused.
public struct PeopleBrowserView: View {
    /// Media to pull people from
    public let people: [any MediaPersonProtocol]
    /// Streaming service used to load each person's photo
    public let streamingService: MediaImageProviding

    @Environment(ThemeModel.self) private var theme

    @FocusState private var focusedActor: Int?

    /// Displays a list of people's photos, names, and roles
    /// - Parameters:
    ///   - people: People to render
    ///   - streamingService: Location to load media from
    public init(people: [any MediaPersonProtocol], streamingService: MediaImageProviding) {
        self.people = people
        self.streamingService = streamingService
    }

    public var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(Array(self.people.enumerated()), id: \.offset) { offset, person in
                    Button { /* Temp Focus Workaround */ } label: {
                        VStack(spacing: 0) {
                            if let blurHash = person.imageHashes?.primary {
                                AsyncBlurImage(
                                    blurHash: blurHash,
                                    blurSize: CGSize(width: 30, height: 45),
                                    imageURL: self.streamingService.getImageURL(imageType: .primary, mediaID: person.id, width: 600)
                                )
                                .frame(width: 350, height: 600)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            else {
                                ZStack {
                                    Color.gray
                                    VStack {
                                        Image(systemName: "person.slash.fill")
                                            .accessibilityLabel("Missing person icon")
                                            .accessibilityHidden(true)
                                            .font(.title)
                                        Text("No image available")
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(width: 350, height: 600)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            MarqueeText(text: person.name, animate: self.focusedActor == offset, font: .headline)
                                .foregroundStyle(
                                    self.focusedActor == offset ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                                )
                            MarqueeText(text: person.role, animate: self.focusedActor == offset, font: .caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .focused($focusedActor, equals: offset)
                    .frame(width: 350)
                }
            }
        }
        .padding(.vertical)
        .scrollClipDisabled()
    }
}
