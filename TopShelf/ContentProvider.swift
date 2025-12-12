//
//  ContentProvider.swift
//  TopShelf
//
//  Created by Ben Roberts on 12/11/25.
//

import TVServices

class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        let streamingModel: StreamingServiceBasicProtocol
        do {
            streamingModel = try StreamingServiceBasicModel()
        } catch {
            print("TopShelf: Failed to initialize StreamingServiceBasicModel: \(error)")
            return nil
        }
        
        // Fetch content concurrently
        print("TopShelf: Loading content...")
        async let upNextMedia = streamingModel.retrieveUpNext()
        async let recentlyAddedMedia = streamingModel.retrieveRecentlyAdded(.all)
        
        let (upNext, recentlyAdded) = await (upNextMedia, recentlyAddedMedia)
        
        print("TopShelf: Retrieved \(upNext.count) up next items and \(recentlyAdded.count) recently added items")
        
        // Create sections
        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
        
        // Up Next section - using landscape/wide images
        if !upNext.isEmpty {
            let upNextItems = upNext.compactMap { media -> TVTopShelfSectionedItem? in
                createTopShelfItem(from: media, streamingModel: streamingModel, imageStyle: .landscape)
            }
            
            if !upNextItems.isEmpty {
                let upNextSection = TVTopShelfItemCollection(items: upNextItems)
                upNextSection.title = "Up Next"
                sections.append(upNextSection)
            }
        }
        
        // Recently Added section - using portrait/poster images
        if !recentlyAdded.isEmpty {
            let recentlyAddedItems = recentlyAdded.compactMap { media -> TVTopShelfSectionedItem? in
                createTopShelfItem(from: media, streamingModel: streamingModel, imageStyle: .poster)
            }
            
            if !recentlyAddedItems.isEmpty {
                let recentlyAddedSection = TVTopShelfItemCollection(items: recentlyAddedItems)
                recentlyAddedSection.title = "Recently Added"
                sections.append(recentlyAddedSection)
            }
        }
        
        guard !sections.isEmpty else {
            print("TopShelf: No sections to display")
            return nil
        }
        
        print("TopShelf: Returning \(sections.count) sections with content")
        let sectionedContent = TVTopShelfSectionedContent(sections: sections)
        return sectionedContent
    }
    
    private enum ImageStyle {
        case landscape  // For horizontal/wide images (Up Next)
        case poster     // For vertical/portrait images (Recently Added)
    }
    
    private func createTopShelfItem(from media: SlimMedia, streamingModel: StreamingServiceBasicProtocol, imageStyle: ImageStyle) -> TVTopShelfSectionedItem? {
        // Create the content identifier for deep linking into your app
        let mediaID = media.id
        
        let item = TVTopShelfSectionedItem(identifier: mediaID)
        
        // Set the title
        item.title = media.title
        
        // Set the image based on the style
        switch imageStyle {
        case .landscape:
            // Use backdrop images for horizontal layout
            item.imageShape = .hdtv  // 16:9 aspect ratio for horizontal items
            if let imageURL = streamingModel.getImageURL(imageType: .backdrop, mediaID: mediaID, width: 320) {
                item.setImageURL(imageURL, for: .screenScale1x)
            }
            if let imageURL2x = streamingModel.getImageURL(imageType: .backdrop, mediaID: mediaID, width: 640) {
                item.setImageURL(imageURL2x, for: .screenScale2x)
            }
            
        case .poster:
            // Use poster images for vertical layout (common width is ~500-1000px for posters)
            item.imageShape = .poster  // Vertical aspect ratio for poster items
            if let imageURL = streamingModel.getImageURL(imageType: .primary, mediaID: mediaID, width: 500) {
                item.setImageURL(imageURL, for: .screenScale1x)
            }
            if let imageURL2x = streamingModel.getImageURL(imageType: .primary, mediaID: mediaID, width: 1000) {
                item.setImageURL(imageURL2x, for: .screenScale2x)
            }
        }
        
        // Set the display action to open your app with this content
        // URL scheme: stingray://media?id=<mediaID>&parentID=<parentID>
        if let displayURL = URL(string: "stingray://media?id=\(mediaID)&parentID=\(media.parentID ?? "None")") {
            item.displayAction = TVTopShelfAction(url: displayURL)
        }
        
        return item
    }

}
