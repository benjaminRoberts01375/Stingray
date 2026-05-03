//
//  LocalExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 5/2/26.
//

import Foundation

/// Support displaying the language of a locale
extension Locale {
    /// The localized display name of the locale's language
    public var languageDisplayName: String? {
        guard let languageCode = self.language.languageCode?.identifier
        else { return nil }
        return self.localizedString(forLanguageCode: languageCode)
    }
}
