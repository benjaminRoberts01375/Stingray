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
    @State private var selectedAudioID: Int
    let streamingService: StreamingServiceProtocol
    let mediaSource: any MediaSourceProtocol
    
    init(player: AVPlayer? = nil, streamingService: StreamingServiceProtocol, mediaSource: any MediaSourceProtocol) {
        self.player = player
        self.selectedSubtitleID = nil
        self.streamingService = streamingService
        self.mediaSource = mediaSource
        self.selectedAudioID = mediaSource.audioStreams.first?.id ?? 0
    }
    
    var body: some View {
        VStack {
            if let player {
                AVPlayerViewControllerRepresentable(
                    player: player,
                    transportBarCustomMenuItems: makeTransportBarItems()
                )
            }
        }
        .task { newPlayer(subtitleID: selectedSubtitleID, audioID: selectedAudioID) }
        .ignoresSafeArea(.all)
    }
    
    private func makeTransportBarItems() -> [UIMenuElement] {
        [
            UIMenu(title: "Subtitles", image: UIImage(systemName: "captions.bubble"), children: [
                {
                    let action = UIAction(title: "None") { _ in
                        newPlayer(subtitleID: nil, audioID: selectedAudioID)
                    }
                    action.state = selectedSubtitleID == nil ? .on : .off
                    return action
                }()
            ] + mediaSource.subtitleStreams.map({ subtitleStream in
                let action = UIAction(title: subtitleStream.title) { _ in
                    newPlayer(subtitleID: subtitleStream.id, audioID: selectedAudioID)
                }
                action.state = selectedSubtitleID == subtitleStream.id ? .on : .off
                return action
            })),
            UIMenu(title: "Audio", image: UIImage(systemName: "speaker.wave.2"), children: mediaSource.audioStreams.map({ audioStream in
                let action = UIAction(title: audioStream.title) { _ in
                    newPlayer(subtitleID: selectedSubtitleID, audioID: audioStream.id)
                }
                action.state = selectedAudioID == audioStream.id ? .on : .off
                return action
            })),
            //            UIAction(title: "Next Episode", image: UIImage(systemName: "forward.end")) { _ in
            //                print("Next episode tapped")
            //            }
        ]
    }
    
    private func newPlayer(subtitleID: Int?, audioID: Int) {
        let currentTime = player?.currentTime()
        if let existingPlayer = player {
            existingPlayer.pause()
        }
        guard let playerItem = streamingService.getStreamingContent(mediaSource: mediaSource, subtitleID: subtitleID, audioID: audioID)
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
