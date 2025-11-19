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
    
    init(contentURL: URL) {
        self.vm = .init(contentURL: contentURL)
    }
    
    var body: some View {
        VideoPlayer(player: vm.player)
    }
}

@Observable
final class PlayerViewModel {
    let player: AVPlayer?
    
    init(contentURL: URL) {
        player = AVPlayer(url: contentURL)
//        let item = AVPlayerItem(url: contentURL)
    }
}
