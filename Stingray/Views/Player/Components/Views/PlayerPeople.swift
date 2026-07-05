//
//  PlayerPeople.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import SwiftUI

public struct PlayerPeopleView: View {
    public let people: [any MediaPersonProtocol]
    public let streamingService: MediaImageProviding

    public var body: some View {
        PeopleBrowserView(people: self.people, streamingService: self.streamingService)
            .padding()
            .padding(.horizontal, 24)
            .clipped()
            .availableGlass()
    }
}
