//
//  MediaModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import Foundation

// MARK: Protocols

/// Define the shape of a piece of media
public protocol MediaProtocol: Identifiable, MediaRepresentableProtocol, Hashable, MediaMetadataProtocol {
    /// Denotes TV show, vs movie, vs... and contains relevant data for that type.
    var mediaType: MediaType { get }
    /// Tracks if the special features have been fetched. If they have been successfully fetched, they'll available through this variable.
    var specialFeatures: SpecialFeaturesStatus { get set }
    
    /// Load special features for this media
    func loadSpecialFeatures(specialFeatures: [SpecialFeature])
    /// Load season data
    func loadSeasons(_ newState: TVSeasonsStatus)
}

/// Extend the MediaSourceProtocol to allow for getting similar streams
extension MediaSourceProtocol {
    /// Gets a streams based on stream type and title. This is good for having an existing stream for an episode, and finding a similar one
    /// for the next episode.
    /// - Parameters:
    ///   - baseStream: Initial stream to pull metadata from.
    ///   - streamType: Desired type of stream.
    /// - Returns: A potential matching stream.
    public func getSimilarStream(baseStream: any MediaStreamProtocol, streamType: StreamType) -> (any MediaStreamProtocol)? {
        var streams: [any MediaStreamProtocol]
        switch streamType {
        case .video:
            streams = videoStreams
        case .audio:
            streams = audioStreams
        case .subtitle:
            streams = subtitleStreams
        case .unknown:
            return nil
        }
        return streams.first { $0.title == baseStream.title }
    }
}

// MARK: Concrete types
/// Stores all high-level information about a piece of media.
@Observable
public final class MediaModel: MediaProtocol, Decodable {
    public var title: String
    public var sortTitle: String
    public var tagline: String
    public var description: String
    public var imageTags: (any MediaImagesProtocol)?
    public var imageBlurHashes: (any MediaImageBlurHashesProtocol)?
    public var id: String
    public var genres: [String]
    public var maturity: String?
    public var releaseDate: Date?
    public var mediaType: MediaType
    public var duration: Duration?
    public var people: [any MediaPersonProtocol]
    public var specialFeatures: SpecialFeaturesStatus
    
    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case title = "Name"
        case sortTitle = "SortName"
        case taglines = "Taglines"
        case description = "Overview"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case mediaSources = "MediaSources"
        case genres = "Genres"
        case maturity = "OfficialRating"
        case releaseDate = "PremiereDate"
        case mediaType = "Type"
        case duration = "RunTimeTicks"
        case people = "People"
        case userData = "UserData"
    }
    
    /// Sets up a Media Model from JSON
    /// - Parameter decoder: JSON decoder
    /// - throws: `DecodingError.typeMismatch` if the encountered stored value is not a keyed container.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.specialFeatures = .unloaded
        
        // Easy to decode stuff
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        let title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Unknown Title"
        self.title = title
        self.sortTitle = (try? container.decodeIfPresent(String.self, forKey: .sortTitle)) ?? title
        self.tagline = (try? container.decodeIfPresent([String].self, forKey: .taglines))?.first ?? ""
        self.description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.imageTags = (try? container.decodeIfPresent(MediaImages.self, forKey: .imageTags)) ??
        MediaImages(thumbnail: nil, logo: nil, primary: nil)
        self.imageBlurHashes = try? container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.genres = (try? container.decodeIfPresent([String].self, forKey: .genres)) ?? []
        self.maturity = try? container.decodeIfPresent(String.self, forKey: .maturity)
        self.people = (try? container.decodeIfPresent([MediaPerson].self, forKey: .people)) ?? []
        
        // Harder to decode stuff
        guard let mediaType = try? container.decode(MediaType.self, forKey: .mediaType)
        else { throw JSONError.missingKey("Media Type", "Media Model") }
        
        switch mediaType {
        case .movies:
            let movieSources: [MediaSource]
            do { movieSources = try container.decode([MediaSource].self, forKey: .mediaSources) }
            catch let error as RError {
                self.mediaType = .error(error)
                break
            }

            struct UserData: Decodable {
                let playbackPositionTicks: Int
                let mediaItemID: String
                
                enum CodingKeys: String, CodingKey {
                    case playbackPositionTicks = "PlaybackPositionTicks"
                    case mediaItemID = "ItemId"
                }
            }
            
            let userDataContainer = (try? container.decodeIfPresent(UserData.self, forKey: .userData)) ??
            UserData(playbackPositionTicks: .zero, mediaItemID: UUID().uuidString)
            
            if let defaultIndex = movieSources.firstIndex(where: { $0.id == userDataContainer.mediaItemID }) {
                movieSources[defaultIndex].startPoint = TimeInterval(ticks: userDataContainer.playbackPositionTicks)
            }
            self.mediaType = .movies(movieSources)
        case .homeVideo:
            let sources: [MediaSource]
            do { sources = try container.decode([MediaSource].self, forKey: .mediaSources) }
            catch let error as RError {
                self.mediaType = .error(error)
                break
            }
            self.mediaType = .homeVideo(sources)
        case .error, .tv: self.mediaType = mediaType
        }
        
        // Runtime ticks need conversion
        if let runtimeTicks = try? container.decodeIfPresent(Int.self, forKey: .duration), runtimeTicks != 0 {
            self.duration = .nanoseconds(100 * runtimeTicks)
        }
        
        // Date needs to be interpreted
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .releaseDate) {
            self.releaseDate = ISO8601DateFormatter.jellyfin.date(from: dateString)
        }
    }
    
    /// Stores and formats the special features for this media.
    /// - Parameter specialFeatures: Special features to add.
    public func loadSpecialFeatures(specialFeatures: [SpecialFeature]) {
        let specialFeatures = specialFeatures.map { feature in
            if feature.featureType == "Unknown" { feature.featureType = "Extras" }
            else {
                feature.featureType =
                feature.featureType.pascalCaseToSpaces()
                if !feature.featureType.hasSuffix("s") && feature.featureType != "theme-music" { // Make plural
                    feature.featureType += "s"
                }
            }
            return feature
        }
        // Group by featureType
        let groupedFeatures = Dictionary(grouping: specialFeatures, by: \.featureType)
            .values
            .map { $0 as [any SpecialFeatureProtocol] }
        
        self.specialFeatures = .loaded(groupedFeatures)
    }

    public func loadSeasons(_ newState: TVSeasonsStatus) {
        // Save the episodes
        self.mediaType = .tv(newState)

        switch newState {
        case .unloaded, .loading: return
        case .loaded(let newSeasons):
            // Save all the people
            var people: [any MediaPersonProtocol] = self.people
            // We don't use IDs here because people across a series can have different IDs. This prevents duplicates
            var seenIDs: Set<String> = Set(self.people.map { $0.name + $0.role })
            for season in newSeasons {
                for episode in season.episodes {
                    for person in episode.people where seenIDs.insert(person.name + person.role).inserted {
                        people.append(person)
                    }
                }
            }
            self.people = people
        }
    }

    // Hashable conformance
    public static func == (lhs: MediaModel, rhs: MediaModel) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Denotes the type of media a `MediaModel` is.
public enum MediaType: Decodable {
    /// A movie (and its versions) with its media streams.
    case movies([any MediaSourceProtocol])
    /// TV type with the associated seasons. Nil indicates that media has not yet been loaded
    case tv(TVSeasonsStatus)
    /// The type failed to load media
    case error(RError)
    /// A single home video with its media streams
    case homeVideo([any MediaSourceProtocol])

    /// Create a media type that does not populate its data. Ex. Creates a movie media type with no media sources attached.
    /// - Parameter decoder: JSON decoder.
    public init(from decoder: Decoder) throws(JSONError) {
        let container: any SingleValueDecodingContainer
        let stringValue: String
        
        do {
            container = try decoder.singleValueContainer()
            stringValue = try container.decode(String.self)
        }
        catch DecodingError.keyNotFound(let key, _) {
            Log.error("Key \(key) was not found to determine the library type with")
            throw JSONError.missingKey(key.stringValue, "Media Type")
        }
        catch DecodingError.valueNotFound(_, let context) {
            if let key = context.codingPath.last {
                Log.error("Key \"\(key)\" was found, however value was missing to determine the library type with")
                throw JSONError.missingContainer(key.stringValue, "Media Type")
            }
            else {
                Log.error("A key was found, however value was missing to determine the library type with")
                throw JSONError.failedJSONDecode("Media Image Blur Hash", DecodingError.valueNotFound(Any.self, context))
            }
        }
        catch let error {
            Log.error("Media Type failed to decode: \(error.localizedDescription)")
            throw JSONError.failedJSONDecode("Media Type", error)
        }

        switch stringValue {
        case "Movie": self = .movies([])
        case "Series": self = .tv(.unloaded)
        case "Video": self = .homeVideo([])
        default: self = .error(JSONError.unexpectedKey(MediaError.unknownMediaType(stringValue)))
        }
    }
    
    /// To be used in the URL when requesting library content
    public var rawValue: String {
        switch self {
        case .movies: return "Movie"
        case .tv: return "Series"
        case .homeVideo: return "Video"
        case .error: return "Error"
        }
    }
}
