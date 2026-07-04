//
//  Actors.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import SwiftUI

public struct PeopleBrowserView: View {
    /// Media to pull people from
    public let people: [any MediaPersonProtocol]
    public let streamingService: MediaImageProviding

    @Environment(ThemeModel.self) private var theme

    @FocusState private var focusedActor: String?

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
                ForEach(self.people, id: \.id) { person in
                    Button { /* Temp Focus Workaround */ } label: {
                        VStack {
                            AsyncBlurImage(
                                blurHash: person.imageHashes?.primary,
                                blurSize: CGSize(width: 30, height: 45),
                                imageURL: self.streamingService.getImageURL(imageType: .primary, mediaID: person.id, width: 600)
                            )
                            .frame(width: 350, height: 600)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            Text(person.name)
                                .multilineTextAlignment(.center)
                                .font(.headline)
                                .foregroundStyle(
                                    self.focusedActor == person.id ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                                )
                            Text(person.role)
                                .multilineTextAlignment(.center)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .focused(self.$focusedActor, equals: person.id)
                    .frame(width: 350)
                }
            }
        }
        .padding(.vertical)
        .scrollClipDisabled()
    }
}
