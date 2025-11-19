//
//  PlayerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/19/25.
//

import AVKit
import SwiftUI

struct PlayerView: View {
    @State private var player: AVPlayer?
    let streamingService: StreamingServiceProtocol
    let media: MediaProtocol
    
    var body: some View {
        VStack {
            if let player {
                VideoPlayer(player: player)
            }
        }
        .task {
            // Use the task modifier to defer creating the player to ensure
            // SwiftUI creates it only once when it first presents the view.
            // Shout out to https://stackoverflow.com/questions/15456130/add-custom-header-field-in-request-of-avplayer/54068128#54068128
            guard let playerItem = streamingService.getStreamingContent(media: media)
            else {
                player = nil
                return
            }
            self.player = AVPlayer(playerItem: playerItem)
        }
    }
}
