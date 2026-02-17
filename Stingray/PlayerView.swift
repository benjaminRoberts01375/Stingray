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
            if self.vm.player != nil {
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
            }
        }
        .onDisappear { // Only stop the player if PiP is not active
            if AVPlayerViewControllerRepresentable.Coordinator.activePiPCoordinator == nil {
                print("Stopping player")
                self.vm.stopPlayer()
            }
        }
        .ignoresSafeArea(.all)
    }
}

fileprivate struct PlayerDescriptionView: View {
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
                .padding()
                .modifier(MaterialEffectModifier())
                
                switch media.mediaType {
                case .movies, .unknown:
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
                        .padding()
                        .modifier(MaterialEffectModifier())
                    }
                }
            }
        }
    }
}

fileprivate struct PlayerPeopleView: View {
    let media: any MediaProtocol
    let streamingService: any StreamingServiceProtocol
    
    var body: some View {
        PeopleBrowserView(media: self.media, streamingService: self.streamingService)
            .padding()
            .padding(.horizontal, 24)
            .modifier(MaterialEffectModifier())
    }
}

fileprivate struct PlayerStreamingStats: View {
    init(_ vm: PlayerViewModel) {
        self.vm = vm
        self.screenResolution = UIScreen.main.nativeBounds.size
        self.frameRate = 0
        self.bitrate = 0
        self.networkThroughput = 0
        self.bufferDuration = 0
        self.videoCodec = "Unknown"
        self.resolution = .zero
    }
    
    /// Holds the player data for the view
    @State private var vm: PlayerViewModel
    /// Network usage
    @State private var networkThroughput: Int
    /// Video bitrate of the playing content
    @State private var bitrate: Int
    /// Current playback resolution
    @State private var resolution: CGSize
    /// Current frame rate
    @State private var frameRate: Float
    /// The amount of content loaded in the playback buffer in seconds
    @State private var bufferDuration: Int
    /// Video codec and profile
    @State private var videoCodec: String
    /// Screen resolution
    private let screenResolution: CGSize
    
    var body: some View {
        if self.vm.playerProgress != nil {
            HStack(spacing: 20) {
                VStack {
                    VStack(alignment: .leading) {
                        Text("Media Metadata")
                            .font(.title3.bold())
                            .padding(.bottom)
                        (Text("Media Source Name: ").bold() + Text("\(self.vm.mediaSource.name)"))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        (Text("Media Source ID: ").bold() + Text("\(self.vm.mediaSourceID)"))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Video Stream: ").bold() + Text("\(self.vm.playerProgress?.videoID ?? "Not yet playing...")")
                        Text("Audio Stream: ").bold() + Text("\(self.vm.playerProgress?.audioID ?? "Not yet playing...")")
                        Text("Subtitle Stream: ").bold() + Text("\(self.vm.playerProgress?.subtitleID ?? "None")")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .modifier(MaterialEffectModifier())
                    VStack(alignment: .leading) {
                        Text("Streaming Metadata")
                            .font(.title3.bold())
                            .padding(.bottom)
                        Text("Typical Network Usage: ").bold() + Text("\(self.networkThroughput) bits per second")
                        Text("Buffer Duration: ").bold() + Text("\(bufferDuration) seconds")
                        Text("Player Session ID: ").bold() + Text("\(self.vm.playerProgress?.id ?? "Not yet playing...")")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .modifier(MaterialEffectModifier())
                }
                VStack(alignment: .leading) {
                    Text("Playback Metadata")
                        .font(.title3.bold())
                        .padding(.bottom)
                    Text("Screen Resolution: ").bold() + Text("\(Int(screenResolution.width)) × \(Int(screenResolution.height))px")
                    Text("Playback Resolution: ").bold() + Text("\(Int(resolution.width)) × \(Int(resolution.height))px")
                    Text("Video Bitrate: ").bold() + Text("\(self.bitrate) bits per second")
                    Text("Framerate: ").bold() + Text("\(String(format: "%.2f", frameRate)) fps")
                    Text("Video Codec: ").bold() + Text("\(videoCodec)")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .modifier(MaterialEffectModifier())
            }
            .task { // Update stats periodically
                // Give the player a moment to initialize before first stats update
                try? await Task.sleep(for: .milliseconds(500))
                while !Task.isCancelled {
                    await updateStats()
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
        else {
            Text("Not playing yet")
                .font(.headline)
                .bold()
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .modifier(MaterialEffectModifier())
        }
    }
    
    /// Updates the real-time stats
    private func updateStats() async {
        guard let currentItem = self.vm.player?.currentItem
        else { return }
        
        // Bits per second
        if self.vm.player?.timeControlStatus != .playing { self.bitrate = .zero } // Short circuit to zero if paused
        else if let accessLog = currentItem.accessLog(), let lastEvent = accessLog.events.last {
            self.networkThroughput = Int(lastEvent.observedBitrate) // Represents network usage
            self.bitrate = Int(lastEvent.averageVideoBitrate) // Represents typical video bitrate
        }
        
        // Get presentation size (actual displayed resolution)
        self.resolution = currentItem.presentationSize
        
        // Get frame rate from player item tracks
        if let track = currentItem.tracks.first(where: { $0.assetTrack?.mediaType == .video }) {
            self.frameRate = track.currentVideoFrameRate
        }
        
        // Get codec and profile - use the AVPlayerItemTrack's assetTrack
        if let videoPlayerTrack = currentItem.tracks.first(where: { $0.assetTrack?.mediaType == .video }),
           let assetTrack = videoPlayerTrack.assetTrack {
            do {
                let formatDescriptions = try await assetTrack.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    let fourCC = withUnsafeBytes(of: codecType.bigEndian) { String(bytes: $0, encoding: .ascii) ?? "????" }
                    
                    if fourCC.hasPrefix("hvc") || fourCC.hasPrefix("hev") {
                        self.videoCodec = getHEVCProfile(from: formatDescription) ?? "HEVC"
                    }
                    else if fourCC.hasPrefix("avc") {
                        self.videoCodec = getH264Profile(from: formatDescription) ?? "H.264"
                    }
                    else { self.videoCodec = fourCC }
                }
                else { print("No format description available") }
            }
            catch { print("Error loading codec info: \(error)") }
        }
        else { print("No video track found in player item tracks") }
        
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

fileprivate struct MaterialEffectModifier: ViewModifier {
    let padding = 20.0
    let radius = 24.0
    
    func body(content: Content) -> some View {
        if #available(tvOS 26.0, *) {
            content
                .padding(padding)
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
                .padding(-padding)
                .clipShape(RoundedRectangle(cornerRadius: radius))
        } else {
            content
                .padding(padding)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: radius))
                .padding(-padding)
                .clipShape(RoundedRectangle(cornerRadius: radius))
        }
    }
}

struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let vm: PlayerViewModel
    
    // Let's keep SwiftUI to SwiftUI, and UIKit to UIKit
    let onStartPiP: () -> Void
    let onRestoreFromPiP: () -> Void
    let onStopFromPiP: () -> Void
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            id: self.vm.mediaSourceID,
            onStartPiP: self.onStartPiP,
            onRestoreFromPiP: self.onRestoreFromPiP,
            onStopFromPiP: self.onStopFromPiP,
        )
        
        // Should we kill the current PiP stream because the user is now watching something new?
        if Self.Coordinator.activePiPCoordinator?.id != nil && self.vm.mediaSource.id != Self.Coordinator.activePiPCoordinator?.id {
            print("Killing PiP Coordinator")
            // Stop the previous player to kill PiP
            Self.Coordinator.activePiPCoordinator?.stopPlayer()
            Self.Coordinator.activePiPCoordinator = nil
        }
        return coordinator
    }
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        if let player = self.vm.player { controller.player = player }
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
            let peopleTab = UIHostingController(
                rootView: PlayerPeopleView(media: self.vm.media, streamingService: self.vm.streamingService)
            )
            peopleTab.title = "People"
            peopleTab.preferredContentSize = CGSize(width: 0, height: 350)
            playerTabs.append(peopleTab)
        }
        
        let streamingStatsTab = UIHostingController(rootView: PlayerStreamingStats(self.vm))
        streamingStatsTab.title = "Stats"
        playerTabs.append(streamingStatsTab)
        
        controller.customInfoViewControllers = playerTabs
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if let player = self.vm.player { uiViewController.player = player }
        uiViewController.transportBarCustomMenuItems = makeTransportBarItems()
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
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onStartPiP: () -> Void
        let onRestoreFromPiP: () -> Void
        let onStopFromPiP: () -> Void
        /// Used for PiP identification
        let id: String
        
        // Maintain a reference to a PiP instance
        weak var playerViewController: AVPlayerViewController?
        // Maintain a reference to this Coordinator while PiP is active
        static var activePiPCoordinator: Coordinator?
        
        // Track whether we're restoring vs closing
        private var isRestoringFromPiP = false
        
        init(
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
        
        func stopPlayer() {
            // On tvOS, stopping the player will end PiP automatically
            playerViewController?.player?.pause()
            playerViewController?.player?.replaceCurrentItem(with: nil)
        }
        
        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            print("PiP starting")
            self.onStartPiP()
            Self.activePiPCoordinator = self // Keep self alive
        }
        
        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            print("PiP stopped")
            if !isRestoringFromPiP {
                onStopFromPiP()
            }
            
            isRestoringFromPiP = false // Reset for next time
            Self.activePiPCoordinator = nil
        }
        
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            failedToStartPictureInPictureWithError error: Error
        ) {
            print("PiP failed to start: \(error)")
            Self.activePiPCoordinator = nil
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
