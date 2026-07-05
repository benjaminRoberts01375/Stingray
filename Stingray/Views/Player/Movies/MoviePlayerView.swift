//
//  MoviePlayerView.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import AVKit
import SwiftUI

public struct MoviePlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State public var vm: MoviePlayerViewModel
    @Binding public var navigation: NavigationPath

    public var body: some View {
        VStack {
            PlayerViewControllerRepresentable(vm: self.vm) {
                self.vm.navigationPath = self.navigation
                dismiss()
            }
            onRestoreFromPiP: {
                if let restoredPath = self.vm.navigationPath {
                    self.navigation = restoredPath
                }
            }
            onStopFromPiP: { self.vm.stopPlayer() }
                .id( // Force reload the AVPlayerViewControllerRepresentable when the underlying content changes
                    self.vm.mediaSource.id +
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

fileprivate struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {

    public let vm: MoviePlayerViewModel

    // Let's keep SwiftUI to SwiftUI, and UIKit to UIKit
    public let onStartPiP: () -> Void
    public let onRestoreFromPiP: () -> Void
    public let onStopFromPiP: () -> Void

    @Environment(ThemeModel.self) private var theme

    public func makeCoordinator() -> AVPlayerCoordinator {
        let coordinator = AVPlayerCoordinator(
            id: self.vm.mediaSource.id,
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
        Log.info("Loading movie player...")
        let controller = AVPlayerViewController()
        controller.player = self.vm.player
        controller.showsPlaybackControls = true
        controller.transportBarCustomMenuItems = PlayerButtons.AVPlayerTransportBarItems(vm: self.vm)
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        controller.allowsPictureInPicturePlayback = true
        controller.allowedSubtitleOptionLanguages = .init(["nerd"])
        controller.delegate = context.coordinator

        context.coordinator.playerViewController = controller

        var playerTabs: [UIViewController] = []

        if !self.vm.media.description.isEmpty {
            // Series & episode description
            let descTab = UIHostingController(rootView: MoviePlayerDescriptionView(media: self.vm.media))
            descTab.title = "Description"
            descTab.preferredContentSize = CGSize(width: 0, height: 350)
            playerTabs.append(descTab)
        }

        if !self.vm.media.people.isEmpty {
            let peopleTab = UIHostingController(
                rootView: PlayerPeopleView(people: self.vm.media.people, streamingService: self.vm.streamingService)
                    .environment(self.theme)
            )
            peopleTab.title = "People"
            peopleTab.preferredContentSize = CGSize(width: 0, height: 350)
            playerTabs.append(peopleTab)
        }

        let streamingStatsTab = UIHostingController(rootView: PlayerStreamingStats(vm: self.vm))
        streamingStatsTab.title = "Stats"
        playerTabs.append(streamingStatsTab)

        controller.customInfoViewControllers = playerTabs
        return controller
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = self.vm.player
        uiViewController.transportBarCustomMenuItems = PlayerButtons.AVPlayerTransportBarItems(vm: self.vm)
    }
}
