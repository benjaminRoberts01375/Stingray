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
    let mediaSource: any MediaSourceProtocol
    
    var body: some View {
        VStack {
            if let player {
                AVPlayerViewControllerRepresentable(
                    player: player,
                    transportBarCustomMenuItems: makeTransportBarItems()
                )
            }
        }
        .task {
            guard let playerItem = streamingService.getStreamingContent(mediaSource: mediaSource)
            else {
                player = nil
                return
            }
            self.player = AVPlayer(playerItem: playerItem)
            self.player?.play()
        }
        .ignoresSafeArea(.all)
    }
    
    private func makeTransportBarItems() -> [UIMenuElement] {
        [
            UIMenu(title: "Subtitles", image: UIImage(systemName: "captions.bubble"), children: [
                UIAction(title: "English") { _ in print("English selected") },
                UIAction(title: "Spanish") { _ in print("Spanish selected") },
                UIAction(title: "Off") { _ in print("Off selected") }
            ]),
            UIMenu(title: "Audio", image: UIImage(systemName: "speaker.wave.2"), children: [
                UIAction(title: "English") { _ in print("English audio") },
                UIAction(title: "Japanese") { _ in print("Japanese audio") }
            ]),
            UIAction(title: "Next Episode", image: UIImage(systemName: "forward.end")) { _ in
                print("Next episode tapped")
            }
        ]
    }
}

struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let transportBarCustomMenuItems: [UIMenuElement]
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.transportBarCustomMenuItems = transportBarCustomMenuItems
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        controller.allowsPictureInPicturePlayback = true
        controller.allowedSubtitleOptionLanguages = .init(["nerd"])
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.transportBarCustomMenuItems = transportBarCustomMenuItems
    }
}
