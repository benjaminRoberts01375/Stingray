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
    
    init(contentURL: URL, authToken: String) {
        self.vm = .init(contentURL: contentURL, authToken: authToken)
    }
    
    var body: some View {
        VideoPlayer(player: vm.player)
    }
}

@Observable
final class PlayerViewModel {
    let player: AVPlayer?
    
    init(contentURL: URL, authToken: String) {
        player = AVPlayer(url: contentURL)
//        let item = AVPlayerItem(url: contentURL)
    }
}
