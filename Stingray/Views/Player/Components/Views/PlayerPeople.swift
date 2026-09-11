//
//  PlayerPeople.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import SwiftUI

/// The player's "People" info tab: a `PeopleBrowserView` wrapped in the player's glass background.
public struct PlayerPeopleView: View {
    /// People to display for the currently playing content
    public let people: [any MediaPersonProtocol]
    /// Streaming service used to load each person's photo
    public let streamingService: MediaImageProviding

    public var body: some View {
        PeopleBrowserView(people: self.people, streamingService: self.streamingService)
            .padding()
            .padding(.horizontal, 24)
            .clipped()
            .availableGlass()
    }
}
