//
//  PlayerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/19/25.
//

import AVKit
import SwiftUI

// MARK: Parent view
public struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State public var vm: PlayerViewModel
    @Binding public var navigation: NavigationPath

    public var body: some View {
        VStack {
            AVPlayerViewControllerRepresentable(vm: self.vm) {
                self.vm.navigationPath = self.navigation
                dismiss()
            } onRestoreFromPiP: {
                if let restoredPath = self.vm.navigationPath {
                    self.navigation = restoredPath
                }
            } onStopFromPiP: {
                self.vm.stopPlayer()
            }
            .id( // Force reload the AVPlayerViewControllerRepresentable when the underlying content changes
                self.vm.mediaSourceID +
                (self.vm.playerProgress?.subtitleID ?? "") +
                (self.vm.playerProgress?.videoID ?? "") +
                (self.vm.playerProgress?.audioID ?? "") +
                (String(self.vm.transportBarNeedsUpdate))
            )
        }
        .onDisappear { // Only stop the player if PiP is not active
            if AVPlayerCoordinator.activePiPCoordinator == nil {
                Log.info("Stopping player")
                self.vm.stopPlayer()
            }
        }
        .ignoresSafeArea(.all)
    }
}

// MARK: UIKit Player
public struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    public let vm: PlayerViewModel

    // Let's keep SwiftUI to SwiftUI, and UIKit to UIKit
    public let onStartPiP: () -> Void
    public let onRestoreFromPiP: () -> Void
    public let onStopFromPiP: () -> Void

    @Environment(ThemeModel.self) private var theme

    public func makeCoordinator() -> AVPlayerCoordinator {
        let coordinator = AVPlayerCoordinator(
            id: self.vm.mediaSourceID,
            onStartPiP: self.onStartPiP,
            onRestoreFromPiP: self.onRestoreFromPiP,
            onStopFromPiP: self.onStopFromPiP,
        )

        // Should we kill the current PiP stream because the user is now watching something new?
        if AVPlayerCoordinator.activePiPCoordinator?.id != nil && self.vm.mediaSource.id != AVPlayerCoordinator.activePiPCoordinator?.id {
            Log.info("Killing PiP Coordinator")
            // Stop the previous player to kill PiP
            AVPlayerCoordinator.activePiPCoordinator?.stopPlayer()
            AVPlayerCoordinator.activePiPCoordinator = nil
        }
        return coordinator
    }

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        Log.info("Loading player...")
        let controller = AVPlayerViewController()
        controller.player = self.vm.player
        controller.showsPlaybackControls = true
        controller.transportBarCustomMenuItems = makeTransportBarItems()
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        controller.allowsPictureInPicturePlayback = true
        controller.allowedSubtitleOptionLanguages = .init(["nerd"])
        controller.delegate = context.coordinator

        context.coordinator.playerViewController = controller

        var playerTabs: [UIViewController] = []

        if !self.vm.media.description.isEmpty {
            // Series & episode description
            let descTab = UIHostingController(
                rootView: PlayerDescriptionView(media: self.vm.media, mediaSource: self.vm.mediaSource)
            )
            descTab.title = "Description"
            descTab.preferredContentSize = CGSize(width: 0, height: 350)
            playerTabs.append(descTab)
        }

        if !self.vm.media.people.isEmpty {
            switch self.vm.media.mediaType {
            case .movies:
                let peopleTab = UIHostingController(
                    rootView: PlayerPeopleView(people: self.vm.media.people, streamingService: self.vm.streamingService)
                        .environment(self.theme)
                )
                peopleTab.title = "People"
                peopleTab.preferredContentSize = CGSize(width: 0, height: 350)
                playerTabs.append(peopleTab)
            case .tv(let seasons):
                guard let seasons = seasons else { break }
                for season in seasons { // Find this episode's people
                    for episode in season.episodes {
                        if let mediaSource = episode.mediaSources.first, mediaSource.id == self.vm.mediaSourceID {
                            let peopleTab = UIHostingController(
                                rootView: PlayerPeopleView(people: episode.people, streamingService: self.vm.streamingService)
                                    .environment(self.theme)
                            )
                            peopleTab.title = "People"
                            peopleTab.preferredContentSize = CGSize(width: 0, height: 350)
                            playerTabs.append(peopleTab)
                            break
                        }
                    }
                }
            }
        }

        let streamingStatsTab = UIHostingController(rootView: PlayerStreamingStats(vm: self.vm))
        streamingStatsTab.title = "Stats"
        playerTabs.append(streamingStatsTab)

        controller.customInfoViewControllers = playerTabs
        return controller
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = self.vm.player
        uiViewController.transportBarCustomMenuItems = makeTransportBarItems()
    }

    private func makeTransportBarItems() -> [UIMenuElement] {
        // Typical buttons
        var items = PlayerButtons.AVPlayerTransportBarItems(vm: self.vm)

        // MARK: Episode picker
        // TV Season-related buttons
        if let seasons = self.vm.seasons {
            let allEpisodes = seasons.flatMap(\.episodes)
            var setPreviousEpisode: Bool = false

            if let currentEpisodeIndex = allEpisodes.firstIndex(where: { episode in
                for mediaSource in episode.mediaSources {
                    return mediaSource.id == self.vm.mediaSource.id
                }
                return false
            }) {
                // Next episode
                if currentEpisodeIndex + 1 < allEpisodes.count {
                    items.insert(PlayerButtons.nextEpisodeButton(vm: self.vm, nextEpisode: allEpisodes[currentEpisodeIndex + 1]), at: 0)
                }

                // Previous episode
                if currentEpisodeIndex - 1 >= 0 {
                    items.insert(
                        PlayerButtons.previousEpisodeButton(vm: self.vm, previousEpisode: allEpisodes[currentEpisodeIndex - 1]), at: 0
                    )
                    setPreviousEpisode = true
                }
            }

            // Episode selector
            items.insert(
                PlayerButtons.episodePicker(vm: self.vm, seasons: seasons),
                at: setPreviousEpisode ? 1 : 0
            )
        }
        return items
    }
}
