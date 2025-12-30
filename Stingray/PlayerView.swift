//
//  PlayerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/19/25.
//

import AVKit
import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) var dismiss
    @State var vm: PlayerViewModel
    @Binding var navigation: NavigationPath
    
    var body: some View {
        VStack {
            if let player = self.vm.player {
                AVPlayerViewControllerRepresentable(
                    player: player,
                    transportBarCustomMenuItems: makeTransportBarItems(),
                    media: self.vm.media,
                    mediaSource: self.vm.mediaSource
                ) {
                    self.vm.navigationPath = self.navigation
                    dismiss()
                } onRestoreFromPiP: {
                    if let restoredPath = self.vm.navigationPath {
                        self.navigation = restoredPath
                    }
                } onStopFromPiP: {
                    self.vm.stopPlayer()
                }
            }
        }
        .onAppear {
            // Only run if player hasn't been set up yet
            guard self.vm.player == nil else { return }
            
            let userModel = UserModel()
            var subtitleID: String?
            var bitrate: Bitrate = .full
            if let defaultUser = userModel.getDefaultUser() {
                if defaultUser.usesSubtitles {
                    subtitleID = self.vm.mediaSource.subtitleStreams.first {
                        $0.isDefault
                    }?.id ?? self.vm.mediaSource.subtitleStreams.first?.id
                }
                if let bitrateBits = defaultUser.bitrate {
                    bitrate = .limited(bitrateBits)
                }
            }
            self.vm.newPlayer(
                startTime: self.vm.startTime,
                videoID: self.vm.mediaSource.videoStreams.first { $0.isDefault }?.id ?? (self.vm.mediaSource.videoStreams.first?.id ?? "0"),
                audioID: self.vm.mediaSource.audioStreams.first { $0.isDefault }?.id ?? (self.vm.mediaSource.audioStreams.first?.id ?? "1"),
                subtitleID: subtitleID,
                bitrate: bitrate
            )
        }
        .onDisappear { self.vm.stopPlayer() }
        .ignoresSafeArea(.all)
    }
    
    private func makeTransportBarItems() -> [UIMenuElement] {
        // Typical buttons
        var items: [UIMenuElement] = []
        
        // Add Subtitles menu only if there are subtitle tracks available
        if !self.vm.mediaSource.subtitleStreams.isEmpty {
            items.append(UIMenu(title: "Subtitles", image: UIImage(systemName: "captions.bubble"), children: [
                {
                    let action = UIAction(title: "None") { _ in
                        self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero)
                    }
                    action.state = self.vm.playerProgress?.subtitleID == nil ? .on : .off
                    return action
                }()
            ] + self.vm.mediaSource.subtitleStreams.map({ subtitleStream in
                let action = UIAction(title: subtitleStream.title) { _ in
                    self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero, subtitleID: subtitleStream.id)
                }
                action.state = self.vm.playerProgress?.subtitleID == subtitleStream.id ? .on : .off
                return action
            })))
        }
        
        // Add Audio menu only if there's more than one option
        if self.vm.mediaSource.audioStreams.count > 1 {
            items.append(
                UIMenu(
                    title: "Audio",
                    image: UIImage(systemName: "speaker.wave.2"),
                    children: self.vm.mediaSource.audioStreams.map({ audioStream in
                        let action = UIAction(title: audioStream.title) { _ in
                            self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero, audioID: audioStream.id)
                        }
                        action.state = self.vm.playerProgress?.audioID == audioStream.id ? .on : .off
                        return action
                    })
                )
            )
        }
        
        // Add Video menu only if there's more than one option
        if self.vm.mediaSource.videoStreams.count > 1 {
            items.append(
                UIMenu(
                    title: "Video",
                    image: UIImage(systemName: "display"),
                    children: self.vm.mediaSource.videoStreams.map({ videoStream in
                        let action = UIAction(title: videoStream.title) { _ in
                            self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero, videoID: videoStream.id)
                        }
                        action.state = self.vm.playerProgress?.videoID == videoStream.id ? .on : .off
                        return action
                    })
                )
            )
        }
        
        // Bitrate choices
        if let videoStream = (self.vm.mediaSource.videoStreams.first { self.vm.playerProgress?.videoID == $0.id }),
           videoStream.bitrate > 1_500_000 {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            
            let fullBitrateString = numberFormatter.string(from: NSNumber(value: videoStream.bitrate))
                ?? "\(videoStream.bitrate)"
            let fullBitrate = UIAction(title: "Full - \(fullBitrateString) Bits/sec") { _ in
                self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero, bitrate: .full)
            }
            fullBitrate.state = {
                if case .full = self.vm.playerProgress?.bitrate {
                    return .on
                } else {
                    return .off
                }
            }()
            var bitrateOptions: [UIAction] = [fullBitrate]
            
            // Helper function to create a bitrate action
            func makeBitrateAction(bitrate: Int) -> UIAction {
                let mbps = Double(bitrate) / 1_000_000
                let title = mbps.truncatingRemainder(dividingBy: 1) == 0 
                    ? "\(Int(mbps)) Mbps" 
                    : "\(mbps) Mbps"
                
                let action = UIAction(title: title) { _ in
                    self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero, bitrate: .limited(bitrate))
                }
                action.state = {
                    if case .limited(let limit) = self.vm.playerProgress?.bitrate, limit == bitrate {
                        return .on
                    } else {
                        return .off
                    }
                }()
                return action
            }
            
            // Add common bitrate options if applicable
            let commonBitrates = stride(from: 20_000_000, to: videoStream.bitrate, by: 10_000_000).reversed() +
            [15_000_000, 10_000_000, 5_000_000, 1_500_000, 500_000]
            for bitrate in commonBitrates where videoStream.bitrate > bitrate {
                bitrateOptions.append(makeBitrateAction(bitrate: bitrate))
            }
            
            let bitrateIcon: String = {
                if case .full = self.vm.playerProgress?.bitrate {
                    return "wifi"
                } else {
                    return "wifi.badge.lock"
                }
            }()
            
            items.append(
                UIMenu(
                    title: "Target Bitrate",
                    image: UIImage(systemName: bitrateIcon),
                    children: bitrateOptions
                )
            )
        }
        
        // TV Season-related buttons
        if let seasons = self.vm.seasons {
            let allEpisodes = seasons.flatMap(\.episodes)
            var setPreviousEpisode: Bool = false
            
            if let index = allEpisodes.firstIndex(where: { episode in
                for mediaSource in episode.mediaSources {
                    return mediaSource.id == self.vm.mediaSource.id
                }
                return false
            }) {
                // Next episode
                if index + 1 < allEpisodes.count {
                    let episode = allEpisodes[index + 1]
                    items.insert(UIAction(title: "Next Episode", image: UIImage(systemName: "arrow.right"), handler: { _ in
                        self.vm.mediaSourceID = episode.mediaSources.first?.id ?? self.vm.mediaSourceID
                        self.vm.newPlayer(episode: episode)
                    }), at: 0)
                }
                
                // Previous episode
                if index - 1 >= 0 {
                    let episode = allEpisodes[index - 1]
                    items.insert(UIAction(title: "Next Episode", image: UIImage(systemName: "arrow.left"), handler: { _ in
                        self.vm.mediaSourceID = episode.mediaSources.first?.id ?? self.vm.mediaSourceID
                        self.vm.newPlayer(episode: episode)
                    }), at: 0)
                    setPreviousEpisode = true
                }
            }
            
            // Episode selector
            let seasonItems = seasons.map { season in
                let episodeActions = season.episodes.map { episode in
                    let action = UIAction(title: episode.title) { _ in
                        self.vm.mediaSourceID = episode.mediaSources.first?.id ?? self.vm.mediaSourceID
                        self.vm.newPlayer(episode: episode)
                    }
                    action.state = self.vm.mediaSource.id == episode.mediaSources.first?.id ? .on : .off
                    return action
                }
                
                // Awful limitation by Apple to only support menus one level deep here
                return UIMenu(title: season.title, options: .displayInline, children: episodeActions)
            }
            items.insert(
                UIMenu(
                    title: "Seasons",
                    image: UIImage(systemName: "calendar.day.timeline.right"),
                    children: seasonItems
                ), at: setPreviousEpisode ? 1 : 0
            )
        }
        return items
    }
}

fileprivate struct Description: View {
    let media: any MediaProtocol
    let mediaSource: any MediaSourceProtocol
    
    var body: some View {
        VStack {
            MediaMetadataView(media: media)
                .padding(.bottom)
                .shadow(color: .black.opacity(1), radius: 10)
            
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    let isTVSeries = {
                        if case .tv = self.media.mediaType {
                            return true
                        }
                        return false
                    }()
                    Text("\(isTVSeries ? "Series " : "")Description")
                        .font(.title3.bold())
                        .multilineTextAlignment(.leading)
                        .padding(.bottom)
                    Text(self.media.description)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .modifier(MaterialEffectModifier())
                switch media.mediaType {
                case .collections, .movies:
                    EmptyView()
                case .tv(let seasons):
                    if let seasons = seasons,
                       let episode = (seasons.flatMap(\.episodes).first { $0.mediaSources.first?.id == self.mediaSource.id }),
                       let episodeDescription = episode.overview {
                        VStack(alignment: .leading) {
                            Text("Episode Description")
                                .font(.title3.bold())
                                .multilineTextAlignment(.leading)
                            Text(episodeDescription)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .modifier(MaterialEffectModifier())
                    }
                }
            }
        }
    }
}

fileprivate struct MaterialEffectModifier: ViewModifier {
    let padding = 20.0
    
    func body(content: Content) -> some View {
        if #available(tvOS 26.0, *) {
            content
                .padding(padding)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(-padding)
        } else {
            content
                .padding(padding)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
                .padding(-padding)
        }
    }
}

struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let transportBarCustomMenuItems: [UIMenuElement]
    let media: any MediaProtocol
    let mediaSource: any MediaSourceProtocol
    
    // Let's keep SwiftUI to SwiftUI, and UIKit to UIKit
    let onStartPiP: () -> Void
    let onRestoreFromPiP: () -> Void
    let onStopFromPiP: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onStartPiP: onStartPiP, onRestoreFromPiP: onRestoreFromPiP, onStopFromPiP: onStopFromPiP)
    }
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.transportBarCustomMenuItems = transportBarCustomMenuItems
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        controller.allowsPictureInPicturePlayback = true
        controller.allowedSubtitleOptionLanguages = .init(["nerd"])
        controller.delegate = context.coordinator
        
        // Series & episode description
        let descTab = UIHostingController(
            rootView: Description(media: media, mediaSource: mediaSource)
        )
        descTab.title = "Description"
        descTab.preferredContentSize = CGSize(width: 0, height: 350)
        
        controller.customInfoViewControllers = [descTab]
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.transportBarCustomMenuItems = transportBarCustomMenuItems
    }
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onStartPiP: () -> Void
        let onRestoreFromPiP: () -> Void
        let onStopFromPiP: () -> Void
        
        private static var activePiPCoordinators = Set<Coordinator>()
        
        // Track whether we're restoring vs closing
        private var isRestoringFromPiP = false
        
        init(onStartPiP: @escaping () -> Void, onRestoreFromPiP: @escaping () -> Void, onStopFromPiP: @escaping () -> Void) {
            self.onStartPiP = onStartPiP
            self.onRestoreFromPiP = onRestoreFromPiP
            self.onStopFromPiP = onStopFromPiP
        }
        
        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            print("PiP starting")
            self.onStartPiP()
            Self.activePiPCoordinators.insert(self) // Keep self alive
        }
        
        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            if !isRestoringFromPiP {
                onStopFromPiP()
            }
            
            isRestoringFromPiP = false // Reset for next time
            Self.activePiPCoordinators.remove(self)
        }
        
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            failedToStartPictureInPictureWithError error: Error
        ) {
            print("PiP failed to start: \(error)")
            Self.activePiPCoordinators.remove(self)
        }
        
        func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
            _ playerViewController: AVPlayerViewController
        ) -> Bool {
            true
        }
        
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            print("Restoring UI from PiP")
            isRestoringFromPiP = true // Flag that this is a restore, not a close
            onRestoreFromPiP()
            completionHandler(true)
        }
    }
}
