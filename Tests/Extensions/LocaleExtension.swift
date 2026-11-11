//
//  LocaleExtension.swift
//  StingrayTVOSTests
//
//  Created by Ben Roberts on 11/10/26.
//

import Foundation
import SwiftUI
import Testing
@testable import Stingray

@Suite("Locale.languageDisplayName") // AI used to get special characters
struct LocaleLanguageDisplayNameTests {
    /// Test that a locale's language is named in that locale's own language
    /// - Parameters:
    ///   - identifier: Locale identifier to test
    ///   - expected: Language name as written in that language
    @Test(arguments: [
        ("en", "English"),
        ("fr", "français"),
        ("de", "Deutsch"),
        ("es", "español"),
        ("it", "italiano"),
        ("ja", "日本語"),
    ])
    func namesOwnLanguage(identifier: String, expected: String) {
        #expect(Locale(identifier: identifier).languageDisplayName == LocalizedStringKey(expected))
    }

    /// Test that region and script components don't affect the language name
    /// - Parameters:
    ///   - identifier: Locale identifier with a region or script
    ///   - expected: Language name without region or script
    @Test(arguments: [
        ("en_US", "English"),
        ("en_GB", "English"),
        ("fr_CA", "français"),
        ("es_MX", "español"),
        ("pt_BR", "português"),
        ("zh-Hans", "中文"),
    ])
    func ignoresRegionAndScript(identifier: String, expected: String) {
        #expect(Locale(identifier: identifier).languageDisplayName == LocalizedStringKey(expected))
    }

    /// Test that a locale without a language code returns nil
    @Test
    func returnNil() {
        #expect(Locale(identifier: "").languageDisplayName == nil)
    }
}
