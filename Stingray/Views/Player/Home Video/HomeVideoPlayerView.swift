//
//  HomeVideoPlayerView.swift
//  Stingray
//
//  Created by Ben Roberts on 9/25/26.
//

import AVKit
import SwiftUI

public struct HomeVideoPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    /// Playback state for this movie
    @State public var vm: HomeVideoPlayerViewModel
    /// App navigation. Stashed on the view model when entering PiP and restored on the way back
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

// MARK: Launcher
/// Since we don't have a nice detail view for launching videos, this is just a little wrapper.
public struct HomeVideoPlayerLauncher: View {
    /// Media the home video belongs to
    public let media: any MediaMetadataProtocol
    /// Source to play
    public let mediaSource: any MediaSourceProtocol
    /// Server to stream from
    public let streamingService: PlayerProviding
    /// App navigation. This view's entry is replaced with the player's view model
    @Binding public var navigation: NavigationPath

    @Environment(SettingsModel.self) private var settings
    /// Guards against swapping the path more than once if the view reappears mid-transition
    @State private var hasLaunched = false

    public var body: some View {
        ProgressView()
            .onAppear {
                guard !self.hasLaunched
                else { return }
                self.hasLaunched = true
                let vm = HomeVideoPlayerViewModel(
                    settingsModel: self.settings,
                    streamingService: self.streamingService,
                    media: self.media,
                    mediaSource: self.mediaSource
                )
                self.navigation.removeLast() // Prevent the user having to do a double back button
                self.navigation.append(vm)
            }
    }
}

// MARK: UIKit Player
/// Wraps `AVPlayerViewController` for the movie player, wiring up the transport bar and the Description, People, and Stats tabs.
/// An existing PiP stream for different content is killed on creation, so only one movie plays at a time.
fileprivate struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {

    /// Playback state for this movie
    public let vm: HomeVideoPlayerViewModel

    // Let's keep SwiftUI to SwiftUI, and UIKit to UIKit
    /// Called when PiP first begins
    public let onStartPiP: () -> Void
    /// Called when a PiP stream is becoming full-screen again
    public let onRestoreFromPiP: () -> Void
    /// Called when PiP ends without being restored
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
        Log.info("Loading home video player...")
        let controller = AVPlayerViewController()
        controller.player = self.vm.player
        controller.showsPlaybackControls = true
        controller.transportBarCustomMenuItems = PlayerButtons.AVPlayerTransportBarItems(vm: self.vm)
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        controller.allowsPictureInPicturePlayback = true
        controller.allowedSubtitleOptionLanguages = .init(["nerd"])
        controller.delegate = context.coordinator

        context.coordinator.playerViewController = controller
        context.coordinator.observeFailures(of: self.vm.player)

        var playerTabs: [UIViewController] = []

        if !self.vm.media.description.isEmpty {
            // Series & episode description
            let descTab = UIHostingController(rootView: MoviePlayerDescriptionView(media: self.vm.media))
            descTab.title = "Description"
            descTab.preferredContentSize = CGSize(width: 0, height: 350)
            playerTabs.append(descTab)
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
