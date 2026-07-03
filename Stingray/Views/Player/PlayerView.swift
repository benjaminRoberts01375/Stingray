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
            if AVPlayerViewControllerRepresentable.Coordinator.activePiPCoordinator == nil {
                Log.info("Stopping player")
                self.vm.stopPlayer()
            }
        }
        .ignoresSafeArea(.all)
    }
}

// MARK: Description Tab
fileprivate struct PlayerDescriptionView: View {
    let media: any MediaProtocol
    let mediaSource: any MediaSourceProtocol
    
    var body: some View {
        VStack {
            MediaLogoHeader(media: self.media)
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
                .padding()
                .availableGlass()
                
                switch media.mediaType {
                case .movies: EmptyView()
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
                        .padding()
                        .availableGlass()
                    }
                }
            }
        }
    }
}

// MARK: People Tab
fileprivate struct PlayerPeopleView: View {
    let people: [any MediaPersonProtocol]
    let streamingService: MediaImageProviding

    var body: some View {
        PeopleBrowserView(people: self.people, streamingService: self.streamingService)
            .padding()
            .padding(.horizontal, 24)
            .clipped()
            .availableGlass()
    }
}

// MARK: Stats Tab
fileprivate struct PlayerStreamingStats: View {
    /// All data regarding current playback
    public var vm: PlayerViewModel
    
    init(vm: PlayerViewModel) {
        self.mediaSourceID = vm.playerProgress?.mediaSource.id ?? "Unknown"
        self.mediaSourceTitle = vm.playerProgress?.mediaSource.name ?? "Untitled"
        self.videoStreamID = vm.playerProgress?.videoID ?? "Unknown"
        self.audioStreamID = vm.playerProgress?.audioID ?? "Unknown"
        self.subtitleStreamID = vm.playerProgress?.subtitleID
        self.vm = vm
    }
    
    /// Network usage
    @State private var networkThroughput: Int = 0
    /// Video bitrate of the playing content
    @State private var bitrate: Int = 0
    /// Current playback resolution
    @State private var resolution: CGSize = .zero
    /// Current frame rate
    @State private var frameRate: Float = 0
    /// The amount of content loaded in the playback buffer in seconds
    @State private var bufferDuration: Int = 0
    /// Video codec and profile
    @State private var videoCodec = "Unknown"
    /// ID of the media source given by the server
    private let mediaSourceID: String
    /// Name of the current media source
    private let mediaSourceTitle: String
    /// ID of the video source given by the server
    private let videoStreamID: String
    /// ID of the audio source given by the server
    private let audioStreamID: String
    /// ID of the subtitle source given by the server. `nil` means no subtitles are being used
    private let subtitleStreamID: String?
    /// Screen resolution
    private let screenResolution: CGSize = UIScreen.main.nativeBounds.size
    
    var body: some View {
        HStack {
            VStack {
                VStack(alignment: .leading) {
                    Text("Metadata")
                        .font(.title3.bold())
                        .padding(.bottom)
                    (Text("Media Source Name" + ": ").bold() + Text(self.mediaSourceTitle))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    (Text("Media Source ID" + ": ").bold() + Text(self.mediaSourceID))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Video Stream" + ": ").bold() + Text(self.videoStreamID)
                    Text("Audio Stream" + ": ").bold() + Text(self.audioStreamID)
                    Text("Subtitle Stream" + ": ").bold() + Text(self.subtitleStreamID ?? "None")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .availableGlass()
                .padding(.bottom)
                VStack(alignment: .leading) {
                    Text("Live Data")
                        .font(.title3.bold())
                        .padding(.bottom)
                    Text("Typical Network Usage" + ": ").bold() + Text("\(self.networkThroughput) bits per second")
                    Text("Video Bitrate" + ": ").bold() + Text("\(self.bitrate) bits per second")
                    Text("Buffer Duration" + ": ").bold() + Text("\(bufferDuration) seconds")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .availableGlass()
                .padding(.top)
            }
            VStack(alignment: .leading) {
                Text("Playback Metadata")
                    .font(.title3.bold())
                    .padding(.bottom)
                Text("Screen Resolution" + ": ").bold() + Text("\(Int(screenResolution.width)) × \(Int(screenResolution.height))px")
                Text("Playback Resolution" + ": ").bold() + Text("\(Int(resolution.width)) × \(Int(resolution.height))px")
                Text("Framerate" + ": ").bold() + Text("\(String(format: "%.2f", frameRate)) fps")
                Text("Video Codec" + ": ").bold() + Text(videoCodec)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .availableGlass()
        }
        .task { // Update stats periodically
            while !Task.isCancelled {
                await updateStats()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    /// Updates the real-time stats
    private func updateStats() async {
        guard let currentItem = self.vm.player.currentItem,
              let track = currentItem.tracks.first,
              let accessLog = currentItem.accessLog(),
              let lastEvent = accessLog.events.last
        else { return }
        
        // Bits per second
        self.networkThroughput = Int(lastEvent.observedBitrate) // Represents network usage
        self.bitrate = Int(lastEvent.averageVideoBitrate) // Represents typical video bitrate
        
        // Get presentation size (actual displayed resolution)
        self.resolution = currentItem.presentationSize
        
        // Get real frame rate and playback resolution
        self.resolution = currentItem.presentationSize
        self.frameRate = track.currentVideoFrameRate
        
        // Get codec and profile
        if let assetTrack = track.assetTrack,
           let formatDescription = try? await assetTrack.load(.formatDescriptions).first {
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
            let fourCC = withUnsafeBytes(of: codecType.bigEndian) { String(bytes: $0, encoding: .ascii) ?? "????" }
            if fourCC.hasPrefix("hvc") || fourCC.hasPrefix("hev") { self.videoCodec = getHEVCProfile(from: formatDescription) ?? "HEVC" }
            else if fourCC.hasPrefix("avc") { self.videoCodec = getH264Profile(from: formatDescription) ?? "H.264" }
            else { self.videoCodec = fourCC }
        }
        
        // Calculate buffer duration in seconds
        if let timeRange = currentItem.loadedTimeRanges.first?.timeRangeValue {
            let bufferedStart = CMTimeGetSeconds(timeRange.start)
            let bufferedDuration = CMTimeGetSeconds(timeRange.duration)
            let currentTime = CMTimeGetSeconds(currentItem.currentTime())
            
            // Calculate how many seconds ahead are buffered from current position
            let bufferEnd = bufferedStart + bufferedDuration
            self.bufferDuration = max(0, Int(bufferEnd - currentTime))
        }
        else { self.bufferDuration = 0 }
    }
    
    func getH264Profile(from formatDescription: CMFormatDescription) -> String? {
        guard let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any],
              let atoms = extensions["SampleDescriptionExtensionAtoms"] as? [String: Any],
              let avcC = atoms["avcC"] as? Data,
              avcC.count > 1
        else { return nil }
        
        switch avcC[1] {
        case 66:  return "H.264 Baseline"
        case 77:  return "H.264 Main"
        case 100: return "H.264 High"
        default:  return "H.264"
        }
    }
    
    func getHEVCProfile(from formatDescription: CMFormatDescription) -> String? {
        guard let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any],
              let atoms = extensions["SampleDescriptionExtensionAtoms"] as? [String: Any],
              let hvcC = atoms["hvcC"] as? Data,
              hvcC.count > 1
        else { return nil }
        
        return hvcC[1] == 2 ? "HEVC Main10" : "HEVC Main"
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
    
    public func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            id: self.vm.mediaSourceID,
            onStartPiP: self.onStartPiP,
            onRestoreFromPiP: self.onRestoreFromPiP,
            onStopFromPiP: self.onStopFromPiP,
        )
        
        // Should we kill the current PiP stream because the user is now watching something new?
        if Self.Coordinator.activePiPCoordinator?.id != nil && self.vm.mediaSource.id != Self.Coordinator.activePiPCoordinator?.id {
            Log.info("Killing PiP Coordinator")
            // Stop the previous player to kill PiP
            Self.Coordinator.activePiPCoordinator?.stopPlayer()
            Self.Coordinator.activePiPCoordinator = nil
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
        var items: [UIMenuElement] = []
        
        // MARK: Subtitle stream choices
        // Add Subtitles menu only if there are subtitle tracks available
        if !self.vm.mediaSource.subtitleStreams.isEmpty {
            items.append(UIMenu(title: "Subtitles", image: UIImage(systemName: "captions.bubble"), children: [
                {
                    let action = UIAction(title: "None") { _ in
                        self.vm.newPlayer(startTime: self.vm.player.currentTime(), subtitleID: .newID(nil))
                    }
                    action.state = self.vm.playerProgress?.subtitleID == nil ? .on : .off
                    return action
                }()
            ] + self.vm.mediaSource.subtitleStreams.map({ subtitleStream in
                let action = UIAction(title: subtitleStream.title) { _ in
                    self.vm.newPlayer(startTime: self.vm.player.currentTime(), subtitleID: .newID(subtitleStream.id))
                }
                action.state = self.vm.playerProgress?.subtitleID == subtitleStream.id ? .on : .off
                return action
            })))
        }
        
        // MARK: Audio stream choices
        // Add Audio menu only if there's more than one option
        if self.vm.mediaSource.audioStreams.count > 1 {
            items.append(
                UIMenu(
                    title: "Audio",
                    image: UIImage(systemName: "speaker.wave.2"),
                    children: self.vm.mediaSource.audioStreams.map({ audioStream in
                        let action = UIAction(title: audioStream.title) { _ in
                            self.vm.newPlayer(startTime: self.vm.player.currentTime(), audioID: .newID(audioStream.id))
                        }
                        action.state = self.vm.playerProgress?.audioID == audioStream.id ? .on : .off
                        return action
                    })
                )
            )
        }
        
        // MARK: Video stream choices
        // Add Video menu only if there's more than one option
        if self.vm.mediaSource.videoStreams.count > 1 {
            items.append(
                UIMenu(
                    title: "Video",
                    image: UIImage(systemName: "display"),
                    children: self.vm.mediaSource.videoStreams.map({ videoStream in
                        let action = UIAction(title: videoStream.title) { _ in
                            self.vm.newPlayer(startTime: self.vm.player.currentTime(), videoID: .newID(videoStream.id))
                        }
                        action.state = self.vm.playerProgress?.videoID == videoStream.id ? .on : .off
                        return action
                    })
                )
            )
        }
        
        // MARK: Bitrate choices
        if let videoStream = (self.vm.mediaSource.videoStreams.first { self.vm.playerProgress?.videoID == $0.id }),
           videoStream.bitrate > 1_500_000 {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            
            let fullBitrateString = numberFormatter.string(from: NSNumber(value: videoStream.bitrate))
            ?? "\(videoStream.bitrate)"
            let fullBitrate = UIAction(title: "Full - \(fullBitrateString) Bits/sec") { _ in
                self.vm.newPlayer(startTime: self.vm.player.currentTime(), bitrate: nil)
            }
            fullBitrate.state = {
                if SettingsModel.bitrateOptions.contains(self.vm.playerProgress?.bitrate ?? -1) {
                    return .off
                }
                return .on
            }()
            var bitrateOptions: [UIAction] = [fullBitrate]
            
            // Helper function to create a bitrate action
            func makeBitrateAction(bitrate: Int) -> UIAction {
                let action = UIAction(title: Int.formatMegabitsPerSec(bitrate)) { _ in
                    self.vm.newPlayer(startTime: self.vm.player.currentTime(), bitrate: bitrate)
                }
                action.state = {
                    if self.vm.playerProgress?.bitrate == bitrate {
                        return .on
                    } else {
                        return .off
                    }
                }()
                return action
            }
            
            // Add bitrate options if applicable
            for bitrate in SettingsModel.bitrateOptions where videoStream.bitrate > bitrate {
                bitrateOptions.append(makeBitrateAction(bitrate: bitrate))
            }
            
            let bitrateIcon: String = {
                if SettingsModel.bitrateOptions.contains(self.vm.playerProgress?.bitrate ?? -1) {
                    return "wifi.badge.lock"
                }
                return "wifi"
            }()
            
            items.append(
                UIMenu(
                    title: "Target Bitrate",
                    image: UIImage(systemName: bitrateIcon),
                    children: bitrateOptions
                )
            )
        }
        
        // MARK: Playback speed picker
        var playbackSpeeds: [UIAction] = []
        for speed in PlaybackSpeed.allCases {
            let action = UIAction(title: speed.name) { _ in
                self.vm.changeSpeed(speed)
            }
            action.state = vm.player.rate == speed.value ? .on : .off
            playbackSpeeds.append(action)
        }
        
        items.append(
            UIMenu(
                title: "Playback Speed",
                image: UIImage(systemName: "gauge.with.dots.needle.33percent"),
                children: playbackSpeeds
            )
        )
        
        // MARK: Episode picker
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
                        self.vm.savePlaybackDate()
                        self.vm.mediaSourceID = episode.mediaSources.first?.id ?? self.vm.mediaSourceID
                        self.vm.newPlayer(episode: episode)
                    }), at: 0)
                }
                
                // Previous episode
                if index - 1 >= 0 {
                    let episode = allEpisodes[index - 1]
                    items.insert(UIAction(title: "Next Episode", image: UIImage(systemName: "arrow.left"), handler: { _ in
                        self.vm.savePlaybackDate()
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
                        self.vm.savePlaybackDate()
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
    
    public class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        public let onStartPiP: () -> Void
        public let onRestoreFromPiP: () -> Void
        public let onStopFromPiP: () -> Void
        /// Used for PiP identification
        public let id: String
        
        // Maintain a reference to a PiP instance
        public weak var playerViewController: AVPlayerViewController?
        // Maintain a reference to this Coordinator while PiP is active
        public static var activePiPCoordinator: Coordinator?
        
        // Track whether we're restoring vs closing
        private var isRestoringFromPiP = false
        
        public init(
            id: String,
            onStartPiP: @escaping () -> Void,
            onRestoreFromPiP: @escaping () -> Void,
            onStopFromPiP: @escaping () -> Void,
        ) {
            self.id = id
            self.onStartPiP = onStartPiP
            self.onRestoreFromPiP = onRestoreFromPiP
            self.onStopFromPiP = onStopFromPiP
        }
        
        public func stopPlayer() {
            // On tvOS, stopping the player will end PiP automatically
            playerViewController?.player?.pause()
            playerViewController?.player?.replaceCurrentItem(with: nil)
        }
        
        public func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            Log.info("PiP starting")
            self.onStartPiP()
            Self.activePiPCoordinator = self // Keep self alive
        }
        
        public func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            Log.info("PiP stopped")
            if !isRestoringFromPiP {
                onStopFromPiP()
            }
            
            isRestoringFromPiP = false // Reset for next time
            Self.activePiPCoordinator = nil
        }
        
        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            failedToStartPictureInPictureWithError error: Error
        ) {
            Log.warning("PiP failed to start: \(error)")
            Self.activePiPCoordinator = nil
        }
        
        public func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
            _ playerViewController: AVPlayerViewController
        ) -> Bool {
            true
        }
        
        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            Log.info("Restoring UI from PiP")
            isRestoringFromPiP = true // Flag that this is a restore, not a close
            onRestoreFromPiP()
            completionHandler(true)
        }
    }
}
