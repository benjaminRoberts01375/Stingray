//
//  PlayerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/19/25.
//

import AVKit
import SwiftUI

struct PlayerView: View {
    @State var vm: PlayerViewModel
    
    init(streamingService: StreamingServiceProtocol, media: MediaProtocol) {
        self.vm = .init(streamingService: streamingService, media: media)
    }
    
    var body: some View {
        VideoPlayer(player: vm.player)
    }
}

@Observable
final class PlayerViewModel {
    let player: AVPlayer?
    
    init(streamingService: StreamingServiceProtocol, media: MediaProtocol) { // Shout out to https://stackoverflow.com/questions/15456130/add-custom-header-field-in-request-of-avplayer/54068128#54068128
        guard let playerItem = streamingService.getStreamingContent(media: media)
        else {
            player = nil
            return
        }
        self.player = AVPlayer(playerItem: playerItem)
    }
}
