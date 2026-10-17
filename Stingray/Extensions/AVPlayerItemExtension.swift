//
//  AVPlayerItemExtension.swift
//  Stingray
//
//  Created by kristofferR on 10/11/26.
//

import AVKit

/// Extend the AVPlayerItem type to share how titles are shown on the player
extension AVPlayerItem {
    /// Shows the title, and possibly a subtitle, on the player
    /// - Parameters:
    ///   - title: Main title of the content to be shown
    ///   - subtitle: An optional descriptor of the content (ex. season 2, episode 4)
    public func setTitle(_ title: String, subtitle: String?) {
        // Set the title metadata
        let titleMetadata = AVMutableMetadataItem()
        titleMetadata.identifier = .commonIdentifierTitle
        titleMetadata.value = title as NSString
        titleMetadata.extendedLanguageTag = "und"

        // Set the subtitle/description metadata
        let subtitleMetadata = AVMutableMetadataItem()
        subtitleMetadata.identifier = .iTunesMetadataTrackSubTitle
        subtitleMetadata.value = (subtitle ?? "") as NSString // Empty string for no subtitle
        subtitleMetadata.extendedLanguageTag = "und"

        self.externalMetadata = [titleMetadata, subtitleMetadata]
    }
}
