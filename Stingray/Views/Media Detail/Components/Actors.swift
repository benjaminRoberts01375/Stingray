//
//  Actors.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import BlurHashKit
import SwiftUI

public struct PeopleBrowserView: View {
    /// Media to pull people from
    public let media: any MediaProtocol
    public let streamingService: any StreamingServiceProtocol
    
    @Environment(ThemeModel.self) private var theme
    
    @FocusState private var focusedActor: String?
    
    public var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(Array(media.people.enumerated()), id: \.offset) { _, person in
                    Button { /* Temp Workaround */ } label: {
                        VStack {
                            ActorImage(media: media, streamingService: streamingService, person: person)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .frame(width: 300)
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
                    .padding()
                    .focused(self.$focusedActor, equals: person.id)
                }
            }
        }
        .scrollClipDisabled()
    }
}

// MARK: Actor Photo
fileprivate struct ActorImage: View {
    let media: any MediaProtocol
    let streamingService: any StreamingServiceProtocol
    let person: any MediaPersonProtocol
    @State private var imageOpacity: Double = 0
    
    var body: some View {
        ZStack {
            if let blurHash = media.imageBlurHashes?.backdrop,
               let blurImage = UIImage(blurHash: blurHash, size: .init(width: 30, height: 45)) {
                Image(uiImage: blurImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
            }
            if let url = streamingService.getImageURL(imageType: .primary, mediaID: person.id, width: 0) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    EmptyView()
                }
            }
        }
    }
}
