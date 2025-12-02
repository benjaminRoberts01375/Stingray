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
    @State private var selectedVideoID: Int
    let streamingService: StreamingServiceProtocol
    let mediaSource: any MediaSourceProtocol
    let seasons: [(any TVSeasonProtocol)]?
    
    init(player: AVPlayer? = nil, streamingService: StreamingServiceProtocol, mediaSource: any MediaSourceProtocol, seasons: [(any TVSeasonProtocol)]? = nil) {
        self.player = player
        self.streamingService = streamingService
        self.mediaSource = mediaSource
        self.selectedSubtitleID = mediaSource.subtitleStreams.first(where: { $0.isDefault })?.id ?? mediaSource.subtitleStreams.first?.id
        self.selectedAudioID = mediaSource.audioStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.audioStreams.first?.id ?? 1)
        self.selectedVideoID = mediaSource.videoStreams.first(where: { $0.isDefault })?.id ?? (mediaSource.videoStreams.first?.id ?? 1)
        self.seasons = seasons
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
        .task { newPlayer(subtitleID: selectedSubtitleID, audioID: selectedAudioID, videoID: selectedVideoID, mediaSource: mediaSource, keepTime: true) }
        .ignoresSafeArea(.all)
    }
    
    private func makeTransportBarItems() -> [UIMenuElement] {
        var items: [UIMenuElement] = [
            UIMenu(title: "Subtitles", image: UIImage(systemName: "captions.bubble"), children: [
                {
                    let action = UIAction(title: "None") { _ in
                        self.selectedSubtitleID = nil
                        newPlayer(subtitleID: nil, audioID: selectedAudioID, videoID: selectedVideoID, mediaSource: mediaSource, keepTime: true)
                    }
                    action.state = selectedSubtitleID == nil ? .on : .off
                    return action
                }()
            ] + mediaSource.subtitleStreams.map({ subtitleStream in
                let action = UIAction(title: subtitleStream.title) { _ in
                    self.selectedSubtitleID = subtitleStream.id
                    newPlayer(subtitleID: subtitleStream.id, audioID: selectedAudioID, videoID: selectedVideoID, mediaSource: mediaSource, keepTime: true)
                }
                action.state = selectedSubtitleID == subtitleStream.id ? .on : .off
                return action
            })),
            UIMenu(title: "Audio", image: UIImage(systemName: "speaker.wave.2"), children: mediaSource.audioStreams.map({ audioStream in
                let action = UIAction(title: audioStream.title) { _ in
                    self.selectedAudioID = audioStream.id
                    newPlayer(subtitleID: selectedSubtitleID, audioID: audioStream.id, videoID: selectedVideoID, mediaSource: mediaSource, keepTime: true)
                }
                action.state = selectedAudioID == audioStream.id ? .on : .off
                return action
            })),
            UIMenu(title: "Video", image: UIImage(systemName: "display"), children: mediaSource.videoStreams.map({ videoStream in
                let action = UIAction(title: videoStream.title) { _ in
                    self.selectedVideoID = videoStream.id
                    newPlayer(subtitleID: selectedSubtitleID, audioID: selectedAudioID, videoID: videoStream.id, mediaSource: mediaSource, keepTime: true)
                }
                action.state = selectedVideoID == videoStream.id ? .on : .off
                return action
            })),
        ]
        
        if let seasons = seasons {
            let seasonItems = seasons.map { season in
                let episodeActions = season.episodes.map { episode in
                    let action = UIAction(title: episode.title) { _ in
                        self.selectedVideoID = episode.mediaSources.first?.videoStreams.first?.id ?? 0
                        self.selectedSubtitleID = episode.mediaSources.first?.subtitleStreams.first?.id
                        self.selectedAudioID = episode.mediaSources.first?.audioStreams.first?.id ?? 1
                        newPlayer(subtitleID: selectedSubtitleID, audioID: selectedAudioID, videoID: selectedVideoID, mediaSource: episode.mediaSources.first ?? mediaSource, keepTime: false)
                    }
                    action.state = mediaSource.id == episode.mediaSources.first?.id ? .on : .off
                    return action
                }
                
                return UIMenu(title: season.title, options: .displayInline, children: episodeActions) // Awful limitation by Apple to only support menus one level deep here
            }
            items.insert(UIMenu(title: "Seasons", image: UIImage(systemName: "calendar.day.timeline.right"), children: seasonItems), at: 0)
        }
        return items
    }
    
    private func newPlayer(subtitleID: Int?, audioID: Int, videoID: Int, mediaSource: any MediaSourceProtocol, keepTime: Bool) {
        let currentTime = player?.currentTime()
        if let existingPlayer = player {
            existingPlayer.pause()
        }
        guard let playerItem = streamingService.getStreamingContent(mediaSource: mediaSource, subtitleID: subtitleID, audioID: audioID, videoID: videoID)
        else {
            player = nil
            return
        }
        
        self.player = AVPlayer(playerItem: playerItem)
        if let currentTime, keepTime {
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
