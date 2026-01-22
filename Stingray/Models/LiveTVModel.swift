//
//  LiveTVModel.swift
//  Stingray
//
//  Data models for Live TV channels, programs, and EPG guide.
//  Supports Jellyfin Live TV API with HDHomeRun, M3U (Tunarr/ErsatzTV), and other sources.
//

import Foundation

// MARK: - Channel Models

/// Represents a Live TV channel
public struct LiveTVChannel: Identifiable, Decodable, Equatable {
    public let id: String
    public let name: String
    public let number: String?
    public let channelType: ChannelType
    public let imageTags: ChannelImageTags?
    public let currentProgram: LiveTVProgram?
    
    /// Whether the channel is currently playing live content
    public var isLive: Bool {
        currentProgram != nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case number = "Number"
        case channelType = "ChannelType"
        case imageTags = "ImageTags"
        case currentProgram = "CurrentProgram"
    }
    
    public static func == (lhs: LiveTVChannel, rhs: LiveTVChannel) -> Bool {
        lhs.id == rhs.id
    }
}

/// Channel type enumeration
public enum ChannelType: String, Decodable {
    case tv = "TV"
    case radio = "Radio"
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ChannelType(rawValue: rawValue) ?? .unknown
    }
}

/// Image tags for channel logos
public struct ChannelImageTags: Decodable {
    public let primary: String?
    
    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
    }
}

// MARK: - Program Models

/// Represents a Live TV program/show in the EPG
public struct LiveTVProgram: Identifiable, Decodable, Equatable {
    public let id: String
    public let channelId: String
    public let name: String
    public let overview: String?
    public let startDate: Date
    public let endDate: Date
    public let episodeTitle: String?
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let year: Int?
    public let genres: [String]
    public let imageTags: ProgramImageTags?
    public let isMovie: Bool
    public let isSeries: Bool
    public let isLive: Bool
    public let isNews: Bool
    public let isSports: Bool
    public let isKids: Bool
    public let isPremiere: Bool
    public let isRepeat: Bool
    
    /// Duration of the program
    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    /// Whether the program is currently airing
    public var isCurrentlyAiring: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }
    
    /// Progress through the program (0.0 to 1.0)
    public var progress: Double {
        guard isCurrentlyAiring else { return 0 }
        let now = Date()
        let elapsed = now.timeIntervalSince(startDate)
        return min(1.0, max(0.0, elapsed / duration))
    }
    
    /// Time remaining in the program
    public var timeRemaining: TimeInterval {
        let now = Date()
        return max(0, endDate.timeIntervalSince(now))
    }
    
    /// Formatted episode string (e.g., "S2 E5")
    public var episodeString: String? {
        guard let season = seasonNumber, let episode = episodeNumber else { return nil }
        return "S\(season) E\(episode)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case channelId = "ChannelId"
        case name = "Name"
        case overview = "Overview"
        case startDate = "StartDate"
        case endDate = "EndDate"
        case episodeTitle = "EpisodeTitle"
        case seasonNumber = "ParentIndexNumber"
        case episodeNumber = "IndexNumber"
        case year = "ProductionYear"
        case genres = "Genres"
        case imageTags = "ImageTags"
        case isMovie = "IsMovie"
        case isSeries = "IsSeries"
        case isLive = "IsLive"
        case isNews = "IsNews"
        case isSports = "IsSports"
        case isKids = "IsKids"
        case isPremiere = "IsPremiere"
        case isRepeat = "IsRepeat"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        channelId = try container.decode(String.self, forKey: .channelId)
        name = try container.decode(String.self, forKey: .name)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        episodeTitle = try container.decodeIfPresent(String.self, forKey: .episodeTitle)
        seasonNumber = try container.decodeIfPresent(Int.self, forKey: .seasonNumber)
        episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        genres = try container.decodeIfPresent([String].self, forKey: .genres) ?? []
        imageTags = try container.decodeIfPresent(ProgramImageTags.self, forKey: .imageTags)
        isMovie = try container.decodeIfPresent(Bool.self, forKey: .isMovie) ?? false
        isSeries = try container.decodeIfPresent(Bool.self, forKey: .isSeries) ?? false
        isLive = try container.decodeIfPresent(Bool.self, forKey: .isLive) ?? false
        isNews = try container.decodeIfPresent(Bool.self, forKey: .isNews) ?? false
        isSports = try container.decodeIfPresent(Bool.self, forKey: .isSports) ?? false
        isKids = try container.decodeIfPresent(Bool.self, forKey: .isKids) ?? false
        isPremiere = try container.decodeIfPresent(Bool.self, forKey: .isPremiere) ?? false
        isRepeat = try container.decodeIfPresent(Bool.self, forKey: .isRepeat) ?? false
        
        // Parse dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let startDateString = try container.decode(String.self, forKey: .startDate)
        let endDateString = try container.decode(String.self, forKey: .endDate)
        
        if let start = dateFormatter.date(from: startDateString) {
            startDate = start
        } else {
            // Try without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            startDate = dateFormatter.date(from: startDateString) ?? Date()
        }
        
        if let end = dateFormatter.date(from: endDateString) {
            endDate = end
        } else {
            dateFormatter.formatOptions = [.withInternetDateTime]
            endDate = dateFormatter.date(from: endDateString) ?? Date()
        }
    }
    
    public static func == (lhs: LiveTVProgram, rhs: LiveTVProgram) -> Bool {
        lhs.id == rhs.id
    }
}

/// Image tags for program artwork
public struct ProgramImageTags: Decodable {
    public let primary: String?
    public let thumb: String?
    public let backdrop: String?
    
    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case thumb = "Thumb"
        case backdrop = "Backdrop"
    }
}

// MARK: - Guide Models

/// Represents the EPG (Electronic Program Guide) data structure
public struct LiveTVGuide {
    /// Programs organized by channel ID
    public var programsByChannel: [String: [LiveTVProgram]]
    
    /// The time range this guide covers
    public let startTime: Date
    public let endTime: Date
    
    /// All channels in the guide
    public var channels: [LiveTVChannel]
    
    init(channels: [LiveTVChannel], programs: [LiveTVProgram], startTime: Date, endTime: Date) {
        self.channels = channels
        self.startTime = startTime
        self.endTime = endTime
        
        // Organize programs by channel
        var byChannel: [String: [LiveTVProgram]] = [:]
        for program in programs {
            byChannel[program.channelId, default: []].append(program)
        }
        
        // Sort programs by start time within each channel
        for (channelId, channelPrograms) in byChannel {
            byChannel[channelId] = channelPrograms.sorted { $0.startDate < $1.startDate }
        }
        
        self.programsByChannel = byChannel
    }
    
    /// Get programs for a specific channel
    func programs(for channelId: String) -> [LiveTVProgram] {
        programsByChannel[channelId] ?? []
    }
    
    /// Get the current program for a channel
    func currentProgram(for channelId: String) -> LiveTVProgram? {
        programs(for: channelId).first { $0.isCurrentlyAiring }
    }
    
    /// Get the next program for a channel
    func nextProgram(for channelId: String) -> LiveTVProgram? {
        let now = Date()
        return programs(for: channelId).first { $0.startDate > now }
    }
    
    /// Get programs within a time range for a channel
    func programs(for channelId: String, from start: Date, to end: Date) -> [LiveTVProgram] {
        programs(for: channelId).filter { program in
            // Include if the program overlaps with the range
            program.endDate > start && program.startDate < end
        }
    }
}

// MARK: - Live TV Info

/// Information about the Live TV configuration on the server
public struct LiveTVInfo: Decodable {
    public let isEnabled: Bool
    public let enabledUsers: [String]
    
    enum CodingKeys: String, CodingKey {
        case isEnabled = "IsEnabled"
        case enabledUsers = "EnabledUsers"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        enabledUsers = try container.decodeIfPresent([String].self, forKey: .enabledUsers) ?? []
    }
}

// MARK: - Channel Category Filter

/// Categories for filtering channels
public enum ChannelCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case movies = "Movies"
    case series = "Series"
    case sports = "Sports"
    case news = "News"
    case kids = "Kids"
    case favorites = "Favorites"
    
    public var id: String { rawValue }
    
    public var systemImage: String {
        switch self {
        case .all: return "tv"
        case .movies: return "film"
        case .series: return "play.tv"
        case .sports: return "sportscourt"
        case .news: return "newspaper"
        case .kids: return "figure.2.and.child.holdinghands"
        case .favorites: return "star.fill"
        }
    }
}

// MARK: - Time Slot Helper

/// Represents a time slot in the EPG grid
public struct EPGTimeSlot: Identifiable {
    public let id: Date
    public let startTime: Date
    public let endTime: Date
    
    public var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }
    
    /// Duration of the slot in minutes
    public var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    /// Generate time slots for a given range (30-minute increments)
    public static func generateSlots(from start: Date, to end: Date, intervalMinutes: Int = 30) -> [EPGTimeSlot] {
        var slots: [EPGTimeSlot] = []
        var current = start
        
        while current < end {
            let slotEnd = current.addingTimeInterval(TimeInterval(intervalMinutes * 60))
            slots.append(EPGTimeSlot(id: current, startTime: current, endTime: slotEnd))
            current = slotEnd
        }
        
        return slots
    }
}
