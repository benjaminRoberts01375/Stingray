//
//  LocalExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 5/2/26.
//

import SwiftUI

/// Support displaying the language of a locale
extension Locale {
    /// The localized display name of the locale's language
    public var languageDisplayName: LocalizedStringKey? {
        guard let languageCode = self.language.languageCode?.identifier,
              let language = self.localizedString(forLanguageCode: languageCode)
        else { return nil }
        return LocalizedStringKey(language)
    }
}
