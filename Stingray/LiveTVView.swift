//
//  LiveTVView.swift
//  Stingray
//
//  Main Live TV view with EPG grid and channel list.
//

import SwiftUI
import AVKit

public struct LiveTVView: View {
    let streamingService: any StreamingServiceProtocol
    @State private var viewModel = LiveTVViewModel()
    @State private var focusedChannelId: String?
    @State private var focusedProgramId: String?
    
    public var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                loadingView
            case .unavailable:
                unavailableView
            case .available:
                mainContent
            case .error(let message):
                errorView(message: message)
            }
        }
        .task {
            viewModel.configure(with: streamingService)
            await viewModel.loadLiveTV()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading Live TV...")
                .font(.headline)
        }
    }
    
    // MARK: - Unavailable View
    
    private var unavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv.slash")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            Text("Live TV Not Available")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Live TV is not configured on your Jellyfin server.\nSet up a tuner (like Tunarr or ErsatzTV) to enable Live TV.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 60)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
            
            Text("Error Loading Live TV")
                .font(.title)
                .fontWeight(.semibold)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button("Try Again") {
                Task { await viewModel.loadLiveTV() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Category Filter Bar
            categoryFilterBar
            
            // EPG Content
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Channel List (left sidebar)
                    channelListView
                        .frame(width: 200)
                    
                    // Time header + Program Grid
                    VStack(spacing: 0) {
                        // Time Header
                        timeHeaderView
                            .frame(height: 50)
                        
                        // Program Grid
                        epgGridView
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.isPlayerVisible) {
            if let player = viewModel.player {
                LiveTVPlayerView(
                    player: player,
                    viewModel: viewModel
                )
            }
        }
    }
    
    // MARK: - Category Filter Bar
    
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(ChannelCategory.allCases) { category in
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: category.systemImage)
                            Text(category.rawValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedCategory == category
                                ? Color.accentColor
                                : Color.secondary.opacity(0.2)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
        }
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Channel List View
    
    private var channelListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredChannels) { channel in
                    ChannelRowView(
                        channel: channel,
                        logoURL: viewModel.channelLogoURL(for: channel.id),
                        isSelected: channel.id == viewModel.selectedChannel?.id
                    )
                    .onTapGesture {
                        viewModel.selectChannel(channel)
                    }
                }
            }
        }
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - Time Header View
    
    private var timeHeaderView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(viewModel.timeSlots) { slot in
                    Text(slot.displayTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: CGFloat(slot.durationMinutes) * 4) // 4 points per minute
                        .background(Color.clear)
                }
            }
            .padding(.leading, 10)
        }
        .background(Color.black.opacity(0.4))
    }
    
    // MARK: - EPG Grid View
    
    private var epgGridView: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.filteredChannels) { channel in
                    ChannelProgramRowView(
                        channel: channel,
                        programs: viewModel.guide?.programs(for: channel.id) ?? [],
                        guideStartTime: viewModel.guide?.startTime ?? Date(),
                        onProgramSelected: { program in
                            viewModel.selectChannel(channel)
                        },
                        programImageURL: { programId in
                            viewModel.programImageURL(for: programId)
                        }
                    )
                    .frame(height: 80)
                }
            }
        }
    }
}

// MARK: - Channel Row View

struct ChannelRowView: View {
    let channel: LiveTVChannel
    let logoURL: URL?
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Channel Logo
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "tv")
                        .foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            .frame(width: 60, height: 40)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 2) {
                // Channel Number
                if let number = channel.number {
                    Text(number)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                // Channel Name
                Text(channel.name)
                    .font(.caption)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 80)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
    }
}

// MARK: - Channel Program Row View

struct ChannelProgramRowView: View {
    let channel: LiveTVChannel
    let programs: [LiveTVProgram]
    let guideStartTime: Date
    let onProgramSelected: (LiveTVProgram) -> Void
    let programImageURL: (String) -> URL?
    
    // Points per minute for width calculation
    private let pointsPerMinute: CGFloat = 4
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(programs) { program in
                ProgramCellView(
                    program: program,
                    width: calculateWidth(for: program),
                    imageURL: programImageURL(program.id)
                )
                .onTapGesture {
                    onProgramSelected(program)
                }
            }
        }
        .padding(.leading, calculateLeadingPadding())
    }
    
    private func calculateWidth(for program: LiveTVProgram) -> CGFloat {
        let durationMinutes = program.duration / 60
        return CGFloat(durationMinutes) * pointsPerMinute
    }
    
    private func calculateLeadingPadding() -> CGFloat {
        guard let firstProgram = programs.first else { return 0 }
        let offsetMinutes = firstProgram.startDate.timeIntervalSince(guideStartTime) / 60
        return max(0, CGFloat(offsetMinutes) * pointsPerMinute)
    }
}

// MARK: - Program Cell View

struct ProgramCellView: View {
    let program: LiveTVProgram
    let width: CGFloat
    let imageURL: URL?
    
    @State private var isFocused = false
    
    var body: some View {
        Button {
            // Selection handled by parent
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                // Program Title
                Text(program.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                // Episode info or time
                if let episodeString = program.episodeString {
                    Text(episodeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(timeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Progress bar for currently airing
                if program.isCurrentlyAiring {
                    ProgressView(value: program.progress)
                        .tint(.accentColor)
                }
                
                // Category badges
                HStack(spacing: 4) {
                    if program.isLive {
                        Badge(text: "LIVE", color: .red)
                    }
                    if program.isPremiere {
                        Badge(text: "NEW", color: .green)
                    }
                    if program.isMovie {
                        Badge(text: "MOVIE", color: .blue)
                    }
                }
            }
            .padding(8)
            .frame(width: width, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if program.isCurrentlyAiring {
            return Color.accentColor.opacity(0.3)
        }
        return Color.secondary.opacity(0.15)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: program.startDate)) - \(formatter.string(from: program.endDate))"
    }
}

// MARK: - Badge View

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Live TV Player View

struct LiveTVPlayerView: View {
    let player: AVPlayer
    @Bindable var viewModel: LiveTVViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Video Player
            VideoPlayer(player: player)
                .ignoresSafeArea()
            
            // Mini Guide Overlay
            if viewModel.showMiniGuide {
                MiniGuideOverlay(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            }
            
            // Channel Info Overlay (brief display on channel change)
            if let channel = viewModel.selectedChannel {
                VStack {
                    Spacer()
                    ChannelInfoOverlay(
                        channel: channel,
                        currentProgram: viewModel.currentProgram,
                        nextProgram: viewModel.nextProgram,
                        logoURL: viewModel.channelLogoURL(for: channel.id)
                    )
                    .padding(.bottom, viewModel.showMiniGuide ? 200 : 40)
                }
            }
        }
        .onAppear {
            player.play()
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }
}

// MARK: - Channel Info Overlay

struct ChannelInfoOverlay: View {
    let channel: LiveTVChannel
    let currentProgram: LiveTVProgram?
    let nextProgram: LiveTVProgram?
    let logoURL: URL?
    
    var body: some View {
        HStack(spacing: 20) {
            // Channel Logo
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Image(systemName: "tv")
                        .font(.largeTitle)
                }
            }
            .frame(width: 80, height: 60)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 8) {
                // Channel Name & Number
                HStack {
                    if let number = channel.number {
                        Text(number)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    Text(channel.name)
                        .font(.title3)
                }
                
                // Current Program
                if let program = currentProgram {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Now: \(program.name)")
                            .font(.headline)
                        
                        if program.isCurrentlyAiring {
                            HStack {
                                ProgressView(value: program.progress)
                                    .frame(width: 200)
                                Text(formatTimeRemaining(program.timeRemaining))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Next Program
                if let next = nextProgram {
                    Text("Next: \(next.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 40)
    }
    
    private func formatTimeRemaining(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 60 {
            return "\(minutes)m left"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m left"
    }
}

// MARK: - Mini Guide Overlay

struct MiniGuideOverlay: View {
    @Bindable var viewModel: LiveTVViewModel
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Time Navigation
                HStack {
                    Button {
                        viewModel.moveTimeBackward()
                    } label: {
                        Image(systemName: "chevron.left")
                            .padding(8)
                    }
                    
                    Spacer()
                    
                    Button("Now") {
                        viewModel.jumpToNow()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button {
                        viewModel.moveTimeForward()
                    } label: {
                        Image(systemName: "chevron.right")
                            .padding(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Channel Quick List
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.filteredChannels) { channel in
                            MiniChannelCard(
                                channel: channel,
                                currentProgram: viewModel.guide?.currentProgram(for: channel.id),
                                logoURL: viewModel.channelLogoURL(for: channel.id),
                                isSelected: channel.id == viewModel.selectedChannel?.id
                            )
                            .onTapGesture {
                                viewModel.selectChannel(channel)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 100)
            }
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Mini Channel Card

struct MiniChannelCard: View {
    let channel: LiveTVChannel
    let currentProgram: LiveTVProgram?
    let logoURL: URL?
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Logo
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Image(systemName: "tv")
                    }
                }
                .frame(width: 40, height: 30)
                
                // Channel info
                VStack(alignment: .leading) {
                    if let number = channel.number {
                        Text(number)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(channel.name)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            
            // Current program
            if let program = currentProgram {
                Text(program.name)
                    .font(.caption2)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(width: 160)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
