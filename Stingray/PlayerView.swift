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
    @State private var selectedSubtitleID: Int?
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
        .task { newPlayer() }
        .ignoresSafeArea(.all)
    }
    
    private func makeTransportBarItems() -> [UIMenuElement] {
        [
            UIMenu(title: "Subtitles", image: UIImage(systemName: "captions.bubble"), children: [
                {
                    let action = UIAction(title: "None") { _ in
                        newPlayer(subtitleID: nil)
                    }
                    action.state = selectedSubtitleID == nil ? .on : .off
                    return action
                }()
            ] + mediaSource.subtitleStreams.map({ subtitleStream in
                let action = UIAction(title: subtitleStream.title) { _ in
                    newPlayer(subtitleID: subtitleStream.id)
                }
                action.state = selectedSubtitleID == subtitleStream.id ? .on : .off
                return action
            })),
            UIMenu(title: "Audio", image: UIImage(systemName: "speaker.wave.2"), children: [
                UIAction(title: "English") { _ in print("English audio") },
                UIAction(title: "Japanese") { _ in print("Japanese audio") }
            ]),
//            UIAction(title: "Next Episode", image: UIImage(systemName: "forward.end")) { _ in
//                print("Next episode tapped")
//            }
        ]
    }
    
    private func newPlayer(subtitleID: Int? = nil) {
        let currentTime = player?.currentTime()
        if let existingPlayer = player {
            existingPlayer.pause()
        }
        guard let playerItem = streamingService.getStreamingContent(mediaSource: mediaSource, subtitleID: subtitleID)
        else {
            player = nil
            return
        }
        self.selectedSubtitleID = subtitleID
        self.player = AVPlayer(playerItem: playerItem)
        if let currentTime {
            self.player?.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        self.player?.play()
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
        uiViewController.player = player
        uiViewController.transportBarCustomMenuItems = transportBarCustomMenuItems
    }
}
