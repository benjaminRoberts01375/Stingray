//
//  SubFolderModel.swift
//  Stingray
//
//  Created by Ben Roberts on 10/18/26.
//

import SwiftUI

public protocol SubFolderProtocol: AnyObject, MediaMetadataProtocol {
    /// Media within this folder
    var media: [MediaStorage] { get set }
}

@Observable
public final class SubFolderModel: SubFolderProtocol, Decodable {
    public var media: [MediaStorage]
    public let id: String
    public let parentID: String
    public let title: String
    public let sortTitle: String
    public let maturity: String?
    public let releaseDate: Date?
    public let genres: [String]
    public let duration: Duration?
    public let description: String
    public let people: [any MediaPersonProtocol]
    public let imageBlurHashes: (any MediaImagesProtocol)?
    public let imageTags: (any MediaImagesProtocol)?

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case parentID = "ParentId"
        case title = "Name"
        case sortTitle = "SortName"
        case taglines = "Taglines"
        case description = "Overview"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case genres = "Genres"
        case maturity = "OfficialRating"
        case releaseDate = "PremiereDate"
        case duration = "RunTimeTicks"
        case people = "People"
        case userData = "UserData"
    }

    public init(from decoder: any Decoder) throws(JSONError) {
        let container: KeyedDecodingContainer<SubFolderModel.CodingKeys>
        do { container = try decoder.container(keyedBy: CodingKeys.self) }
        catch { throw JSONError.missingContainer("Base Container", "Sub-Folder Model") }

        // Easy decodable stuff
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        self.parentID = (try? container.decodeIfPresent(String.self, forKey: .parentID)) ?? UUID().uuidString
        let title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? String(localized: "Unknown Movie")
        self.title = title
        self.sortTitle = (try? container.decodeIfPresent(String.self, forKey: .sortTitle)) ?? title
        self.description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.imageTags = (try? container.decodeIfPresent(MediaImages.self, forKey: .imageTags)) ??
        MediaImages(thumbnail: nil, logo: nil, primary: nil)
        self.imageBlurHashes = try? container.decodeIfPresent(MediaImageBlurHashes.self, forKey: .imageBlurHashes)
        self.genres = (try? container.decodeIfPresent([String].self, forKey: .genres)) ?? []
        self.maturity = try? container.decodeIfPresent(String.self, forKey: .maturity)
        self.people = (try? container.decodeIfPresent([MediaPerson].self, forKey: .people)) ?? []

        // Setup later
        self.media = []

        // Doesn't matter
        self.duration = nil
        self.releaseDate = nil
    }
}
