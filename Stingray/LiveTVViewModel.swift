//
//  LiveTVViewModel.swift
//  Stingray
//
//  ViewModel for managing Live TV state, channels, and EPG data.
//

import AVKit
import SwiftUI

/// Current state of the Live TV feature
public enum LiveTVState: Equatable {
    case loading
    case unavailable
    case available
    case error(String)
    
    public static func == (lhs: LiveTVState, rhs: LiveTVState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.unavailable, .unavailable), (.available, .available):
            return true
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

@Observable
public final class LiveTVViewModel {
    // MARK: - State
    
    /// Current state of Live TV
    var state: LiveTVState = .loading
    
    /// All available channels
    var channels: [LiveTVChannel] = []
    
    /// Currently selected channel
    var selectedChannel: LiveTVChannel?
    
    /// EPG guide data
    var guide: LiveTVGuide?
    
    /// Current time slot being viewed
    var currentTimeSlot: Date = Date()
    
    /// Is the EPG loading
    var isLoadingGuide = false
    
    /// Selected category filter
    var selectedCategory: ChannelCategory = .all
    
    /// Is player visible
    var isPlayerVisible = false
    
    /// Current player
    var player: AVPlayer?
    
    /// Mini guide visibility
    var showMiniGuide = false
    
    /// Current program for selected channel
    var currentProgram: LiveTVProgram? {
        guard let channelId = selectedChannel?.id else { return nil }
        return guide?.currentProgram(for: channelId)
    }
    
    /// Next program for selected channel
    var nextProgram: LiveTVProgram? {
        guard let channelId = selectedChannel?.id else { return nil }
        return guide?.nextProgram(for: channelId)
    }
    
    // MARK: - Dependencies
    
    private var streamingService: (any StreamingServiceProtocol)?
    
    // MARK: - EPG Configuration
    
    /// How many hours of guide data to fetch
    private let guideHoursAhead: Int = 24
    
    /// How many hours of guide data to fetch from the past
    private let guideHoursBehind: Int = 2
    
    // MARK: - Computed Properties
    
    /// Channels filtered by the selected category
    var filteredChannels: [LiveTVChannel] {
        guard selectedCategory != .all else { return channels }
        
        return channels.filter { channel in
            guard let program = guide?.currentProgram(for: channel.id) else { return false }
            
            switch selectedCategory {
            case .all:
                return true
            case .movies:
                return program.isMovie
            case .series:
                return program.isSeries
            case .sports:
                return program.isSports
            case .news:
                return program.isNews
            case .kids:
                return program.isKids
            case .favorites:
                // TODO: Implement favorites
                return false
            }
        }
    }
    
    /// Time slots for the EPG grid
    var timeSlots: [EPGTimeSlot] {
        let startTime = roundToHalfHour(currentTimeSlot.addingTimeInterval(-TimeInterval(guideHoursBehind * 3600)))
        let endTime = currentTimeSlot.addingTimeInterval(TimeInterval(guideHoursAhead * 3600))
        return EPGTimeSlot.generateSlots(from: startTime, to: endTime)
    }
    
    // MARK: - Initialization
    
    func configure(with streamingService: any StreamingServiceProtocol) {
        self.streamingService = streamingService
    }
    
    // MARK: - Data Loading
    
    /// Check if Live TV is available and load channels
    func loadLiveTV() async {
        guard let service = streamingService else {
            await MainActor.run { state = .error("Service not configured") }
            return
        }
        
        await MainActor.run { state = .loading }
        
        do {
            // Check if Live TV is enabled
            let info = try await service.getLiveTVInfo()
            
            guard info.isEnabled else {
                await MainActor.run { state = .unavailable }
                return
            }
            
            // Load channels with current program
            let loadedChannels = try await service.getLiveTVChannels(includeCurrentProgram: true)
            
            guard !loadedChannels.isEmpty else {
                await MainActor.run { state = .unavailable }
                return
            }
            
            await MainActor.run {
                self.channels = loadedChannels
                self.state = .available
            }
            
            // Load EPG data
            await loadGuide()
            
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }
    
    /// Load EPG guide data
    func loadGuide() async {
        guard let service = streamingService else { return }
        
        await MainActor.run { isLoadingGuide = true }
        
        let startDate = Date().addingTimeInterval(-TimeInterval(guideHoursBehind * 3600))
        let endDate = Date().addingTimeInterval(TimeInterval(guideHoursAhead * 3600))
        
        do {
            let programs = try await service.getLiveTVPrograms(
                channelIds: nil,
                startDate: startDate,
                endDate: endDate
            )
            
            await MainActor.run {
                self.guide = LiveTVGuide(
                    channels: self.channels,
                    programs: programs,
                    startTime: startDate,
                    endTime: endDate
                )
                self.isLoadingGuide = false
            }
        } catch {
            await MainActor.run { isLoadingGuide = false }
            print("Failed to load guide: \(error)")
        }
    }
    
    /// Refresh channel data
    func refreshChannels() async {
        guard let service = streamingService else { return }
        
        do {
            let loadedChannels = try await service.getLiveTVChannels(includeCurrentProgram: true)
            await MainActor.run {
                self.channels = loadedChannels
            }
        } catch {
            print("Failed to refresh channels: \(error)")
        }
    }
    
    // MARK: - Channel Selection
    
    /// Select and play a channel
    func selectChannel(_ channel: LiveTVChannel) {
        guard let service = streamingService else { return }
        
        // Stop current playback
        stopPlayback()
        
        selectedChannel = channel
        
        // Start new playback
        if let newPlayer = service.playLiveTVChannel(channelId: channel.id, channelName: channel.name) {
            player = newPlayer
            isPlayerVisible = true
            newPlayer.play()
        }
    }
    
    /// Change to the next channel
    func nextChannel() {
        guard let current = selectedChannel,
              let currentIndex = filteredChannels.firstIndex(where: { $0.id == current.id }),
              currentIndex < filteredChannels.count - 1 else { return }
        
        selectChannel(filteredChannels[currentIndex + 1])
    }
    
    /// Change to the previous channel
    func previousChannel() {
        guard let current = selectedChannel,
              let currentIndex = filteredChannels.firstIndex(where: { $0.id == current.id }),
              currentIndex > 0 else { return }
        
        selectChannel(filteredChannels[currentIndex - 1])
    }
    
    /// Jump to a specific channel number
    func jumpToChannel(number: String) {
        if let channel = channels.first(where: { $0.number == number }) {
            selectChannel(channel)
        }
    }
    
    // MARK: - Playback Control
    
    /// Stop current playback
    func stopPlayback() {
        player?.pause()
        player = nil
        isPlayerVisible = false
    }
    
    /// Toggle mini guide visibility
    func toggleMiniGuide() {
        showMiniGuide.toggle()
    }
    
    // MARK: - Time Navigation
    
    /// Move the EPG view forward in time
    func moveTimeForward(minutes: Int = 30) {
        currentTimeSlot = currentTimeSlot.addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    /// Move the EPG view backward in time
    func moveTimeBackward(minutes: Int = 30) {
        currentTimeSlot = currentTimeSlot.addingTimeInterval(-TimeInterval(minutes * 60))
    }
    
    /// Jump to current time
    func jumpToNow() {
        currentTimeSlot = Date()
    }
    
    // MARK: - URL Helpers
    
    /// Get channel logo URL
    func channelLogoURL(for channelId: String, width: Int = 200) -> URL? {
        streamingService?.getChannelLogoURL(channelId: channelId, width: width)
    }
    
    /// Get program image URL
    func programImageURL(for programId: String, width: Int = 400) -> URL? {
        streamingService?.getProgramImageURL(programId: programId, imageType: .primary, width: width)
    }
    
    // MARK: - Helpers
    
    private func roundToHalfHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = components.minute ?? 0
        components.minute = minute < 30 ? 0 : 30
        components.second = 0
        return calendar.date(from: components) ?? date
    }
}
