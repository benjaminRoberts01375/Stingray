//
//  MovieDetailView.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import AVKit
import BlurHashKit
import SwiftUI

// MARK: Main view
public struct MovieDetailView: View {
    /// Media that contains content to play
    public let media: any MediaProtocol
    /// Streaming service the user is using
    public let streamingService: any StreamingServiceProtocol
    /// All available content sources for this movie and its various versions
    public let mediaSources: [any MediaSourceProtocol]
    
    @Binding public var navigation: NavigationPath
    
    @State private var shouldBackgroundBlur: Bool = false
    @State private var shouldRevealBottomShelf: Bool = false
    @State private var shouldShowMetaData: Bool = false
    @FocusState private var focus: ButtonType?
    
    @Environment(SettingsModel.self) private var settings
    @Environment(ThemeModel.self) private var theme
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            if self.settings.loadMediaBackgroundArt {
                MediaBackgroundView(
                    media: media,
                    backgroundImageURL: streamingService.getImageURL(imageType: .backdrop, mediaID: media.id, width: 0),
                    shouldBlurBackground: $shouldBackgroundBlur
                )
            }
            
            // Content
            ScrollView {
                // Logo and basic metadata
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    MediaLogoView(
                        media: media,
                        logoImageURL: streamingService.getImageURL(imageType: .logo, mediaID: media.id, width: 0)
                    )
                    .background(alignment: .bottom) { // Subtle black shadow
                        if self.settings.loadMediaBackgroundArt {
                            let titleShadowSize = 800.0
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .black, location: 0),
                                            .init(color: .black.opacity(0), location: 1)
                                        ]),
                                        center: UnitPoint(x: 0.5, y: 0.5),
                                        startRadius: 0,
                                        endRadius: titleShadowSize
                                    )
                                    .opacity(0.9)
                                )
                                .frame(width: titleShadowSize * 2, height: titleShadowSize * 2)
                                .offset(y: titleShadowSize)
                        }
                    }
                }
                .padding(.top)
                .frame(height: 350)
                
                // Play buttons
                PlayNavigationView(
                    focus: $focus,
                    navigation: $navigation,
                    media: media,
                    mediaSources: self.mediaSources,
                    streamingService: self.streamingService
                )
                
                // Metadata
                HStack(alignment: .top) {
                    Overview(media: self.media)
                        .focused($focus, equals: .overview)
                    Metadata(media: self.media)
                        .focused($focus, equals: .metadata)
                }
                
                // Special features
                SpecialFeaturesView(streamingService: self.streamingService, media: self.media, navigation: self.$navigation)
                
                // People
                VStack(alignment: .leading, spacing: 3) {
                    Text("People")
                        .font(.title3.bold())
                        .foregroundStyle(self.theme.currentTheme.header1)
                        .padding(.top)
                    PeopleBrowserView(media: media, streamingService: streamingService)
                }
                
            }
            .scrollClipDisabled()
            .padding(32)
            .offset(y: shouldRevealBottomShelf ? 0 : 500)
            .animation(.spring(.smooth), value: shouldRevealBottomShelf)
        }
        .ignoresSafeArea()
        .task { // Yep. I hate it too. Apple TVs are having issues selecting the play button if it changes type.
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                self.focus = .play
            }
        }
        .onChange(of: focus) { _, newValue in
            switch newValue {
            case .overview, .metadata:
                self.shouldBackgroundBlur = true
                self.shouldRevealBottomShelf = true
            case .play:
                self.shouldBackgroundBlur = false
                self.shouldRevealBottomShelf = false
            case nil:
                break
            }
        }
        .navigationDestination(for: PlayerViewModel.self) { vm in
            PlayerView(vm: vm, navigation: $navigation)
        }
        .colorScheme(self.settings.loadMediaBackgroundArt ? .dark : self.theme.currentTheme.colorScheme)
    }
}

// MARK: Background
fileprivate struct MediaBackgroundView: View {
    /// Preview for the background image
    @State private var blurImage: UIImage?
    /// Controls the loaded background opacity
    @State private var fadeBackgroundIn: Double
    /// Blurs the background
    @Binding public var shouldBlurBackground: Bool

    /// Media to pull background info from
    let media: any MediaProtocol
    /// URL to get the image from
    let backgroundImageURL: URL?

    /// Sets up an image that first shows a blurry background, then the loaded image
    /// - Parameters:
    ///   - media: Media to load blur from
    ///   - backgroundImageURL: Image to load
    ///   - shouldBlurBackground: Track if the loaded image should be blurred
    init(media: any MediaProtocol, backgroundImageURL: URL?, shouldBlurBackground: Binding<Bool>) {
        self.fadeBackgroundIn = 0
        self._shouldBlurBackground = shouldBlurBackground
        self.media = media
        self.backgroundImageURL = backgroundImageURL
    }

    var body: some View {
        ZStack {
            AsyncBlurImage(
                blurHash: self.media.imageBlurHashes?.backdrop,
                blurSize: CGSize(width: 32, height: 18),
                imageURL: backgroundImageURL
            )
            Color.clear // Blurry background
                .background(.thinMaterial.opacity(self.shouldBlurBackground ? 1 : 0))
                .animation(.smooth(duration: 0.5), value: self.shouldBlurBackground)
        }
        .allowsHitTesting(false)
    }
}

// MARK: Movie logo and basics
fileprivate struct MediaLogoView: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(ThemeModel.self) private var theme
    
    @State private var logoOpacity: Double = 0
    
    let media: any MediaProtocol
    let logoImageURL: URL?
    
    var body: some View {
        VStack(spacing: 15) {
            if logoImageURL != nil && !self.settings.replaceLogosWithText {
                AsyncImage(url: logoImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(logoOpacity)
                        .animation(.easeOut(duration: 0.5), value: logoOpacity)
                        .onAppear { logoOpacity = 1 }
                } placeholder: {
                    EmptyView()
                }
                .frame(width: 400)
            }
            else {
                Text(self.media.title)
                    .font(.title)
                    .bold()
                    .foregroundStyle(self.theme.currentTheme.header1)
            }
            if !media.tagline.isEmpty {
                Text(media.tagline)
                    .italic()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 800, alignment: .center)
            }
            MediaMetadataView(media: media)
        }
    }
}

// MARK: Play button
fileprivate struct PlayNavigationView: View {
    private let media: any MediaProtocol
    private let streamingService: any StreamingServiceProtocol
    private var title: String
    private let mediaSources: [any MediaSourceProtocol]
    
    @FocusState.Binding var focus: ButtonType?
    @Binding var navigation: NavigationPath
    
    @Environment(SettingsModel.self) var settings: SettingsModel
    
    init(
        focus: FocusState<ButtonType?>.Binding,
        navigation: Binding<NavigationPath>,
        media: any MediaProtocol,
        mediaSources: [any MediaSourceProtocol],
        streamingService: any StreamingServiceProtocol
    ) {
        self._focus = focus
        self._navigation = navigation
        self.media = media
        self.streamingService = streamingService
        self.title = media.title
        self.mediaSources = mediaSources
    }
    
    var body: some View {
        Group {
            // Single source button and menu
            if mediaSources.count == 1 {
                let mediaSource = self.mediaSources[0]
                // Single item that's unwatched - show button
                if mediaSource.startPoint == 0 {
                    Button {
                        self.navigation.append(
                            PlayerViewModel(
                                media: media,
                                mediaSource: mediaSource,
                                startTime: CMTimeMakeWithSeconds(mediaSource.startPoint, preferredTimescale: 1),
                                streamingService: self.streamingService,
                                seasons: [], // TODO: Placeholder
                                settingsModel: self.settings,
                            )
                        )
                    } label: { Label(self.title, systemImage: "play.fill") }
                        .accessibilityLabel("Play button")
                }
                // Single item that's partially watched - show streamlined menu
                else {
                    Menu("\(Image(systemName: "play")) \(title)") {
                        Button { navigateToPlayer(for: mediaSource, startPoint: mediaSource.startPoint) }
                        label: {
                            Label("Resume \(media.title)", systemImage: "play.fill")
                            Text("Continue from \(String(duration: mediaSource.startPoint))")
                        }
                        Button { navigateToPlayer(for: mediaSource, startPoint: .zero) }
                        label: { Label("Restart \(media.title)", systemImage: "memories") }
                    }
                    .accessibilityLabel("Play button menu")
                }
            }
            // Multiple media sources
            else {
                // If there are multiple sources but all unwatched, show only "play" options that start from beginning
                if (mediaSources.allSatisfy { $0.startPoint == 0 }) {
                    Menu("\(Image(systemName: "play")) \(title)") {
                        ForEach(mediaSources, id: \.id) { mediaSource in
                            Button { navigateToPlayer(for: mediaSource, startPoint: mediaSource.startPoint) }
                            label: { Label(mediaSource.name, systemImage: "play.fill") }
                                .id(mediaSource.id)
                        }
                    }
                    .accessibilityLabel("Play button menu")
                }
                // If there's any that are somewhat played, present options to restart
                else {
                    Menu("\(Image(systemName: "play")) \(title)") {
                        Section("Resume") {
                            ForEach(mediaSources, id: \.id) { mediaSource in
                                if mediaSource.startPoint != 0 {
                                    Button { navigateToPlayer(for: mediaSource, startPoint: mediaSource.startPoint)
                                    } label: {
                                        Label(mediaSource.name, systemImage: "play.fill")
                                        Text("Continue from \(String(duration: mediaSource.startPoint))")
                                    }
                                    .id(mediaSource.id)
                                }
                            }
                        }
                        Section("Restart") {
                            ForEach(mediaSources, id: \.id) { mediaSource in
                                Button { navigateToPlayer(for: mediaSource, startPoint: .zero) }
                                label: { Label(mediaSource.name, systemImage: "memories") }
                                    .id(mediaSource.id)
                            }
                        }
                    }
                    .accessibilityLabel("Play button menu")
                }
            }
        }
        .onAppear { self.focus = .play }
        .focused($focus, equals: .play)
        .id("Play-button")
        .defaultFocus($focus, .play, priority: .userInitiated)
    }
    
    func navigateToPlayer(for mediaSource: any MediaSourceProtocol, startPoint: TimeInterval) {
        self.navigation.append(
            PlayerViewModel(
                media: media,
                mediaSource: mediaSource,
                startTime: CMTimeMakeWithSeconds(startPoint, preferredTimescale: 1),
                streamingService: self.streamingService,
                seasons: [], // TODO: Placeholder
                settingsModel: self.settings
            )
        )
    }
}

/// Displays a synopsis of the provided media
fileprivate struct Overview: View {
    @Environment(ThemeModel.self) private var theme
    @FocusState private var isFocused: Bool
    
    /// What to read the synopsis from
    public let media: any MediaProtocol
    
    var body: some View {
        Button {} label: {
            VStack(alignment: .leading) {
                if !media.description.isEmpty {
                    Text("Overview")
                        .font(.headline.bold())
                        .lineLimit(2)
                        .foregroundStyle(
                            self.isFocused ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                        )
                    Text(media.description)
                        .multilineTextAlignment(.leading)
                }
                else {
                    Text("No description available")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .focused($isFocused, equals: true)
    }
}

/// Displays data about the provided media
fileprivate struct Metadata: View {
    @Environment(ThemeModel.self) private var theme
    @FocusState private var isFocused: Bool
    
    /// What to read metadata for
    let media: any MediaProtocol
    
    var body: some View {
        Button {} label: {
            VStack(alignment: .leading, spacing: 16) {
                if !media.genres.isEmpty || media.releaseDate != nil || media.maturity != nil {
                    if !media.genres.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Genres")
                                .font(.headline.bold())
                                .lineLimit(2)
                                .foregroundStyle(
                                    self.isFocused ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                                )
                            Text(media.genres.joined(separator: ", "))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    if let releaseDate = media.releaseDate {
                        VStack(alignment: .leading) {
                            Text("Released")
                                .font(.headline.bold())
                                .lineLimit(2)
                                .foregroundStyle(
                                    self.isFocused ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                                )
                            Text(String(Calendar.current.component(.year, from: releaseDate)))
                                .lineLimit(1)
                        }
                    }
                    if let maturity = media.maturity {
                        Text("Maturity")
                            .font(.headline.bold())
                            .lineLimit(1)
                            .foregroundStyle(
                                self.isFocused ? AnyShapeStyle(.black) : self.theme.currentTheme.header2
                            )
                        Text(maturity)
                            .lineLimit(1)
                    }
                }
                else {
                    Text("No metadata available")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .focused($isFocused, equals: true)
    }
}

// MARK: Actor Photo
fileprivate struct ActorImage: View {
    let media: any MediaProtocol
    let streamingService: any StreamingServiceProtocol
    let person: any MediaPersonProtocol
    @State private var imageOpacity: Double = 0
    
    var body: some View {
        ZStack {
            if let blurHash = media.imageBlurHashes?.backdrop,
               let blurImage = UIImage(blurHash: blurHash, size: .init(width: 30, height: 45)) {
                Image(uiImage: blurImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
            }
            if let url = streamingService.getImageURL(imageType: .primary, mediaID: person.id, width: 0) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    EmptyView()
                }
            }
        }
    }
}

/// Types of buttons available on the `MovieDetailView`
fileprivate enum ButtonType: Hashable {
    case play
    case overview
    case metadata
}
