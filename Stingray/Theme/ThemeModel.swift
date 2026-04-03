//
//  ThemeModel.swift
//  Stingray
//
//  Created by Ben Roberts on 3/31/26.
//

import SwiftUI

/// Manages the current theme
@Observable
final class ThemeModel {
    /// Theme for system dark mode
    var darkTheme: any ThemeProtocol
    /// Theme for system light mode
    var lightTheme: any ThemeProtocol
    /// The implementation of the current theme
    var currentTheme: any ThemeProtocol { systemColorScheme == .dark ? darkTheme : lightTheme }
    
    /// Represents the theme for dark mode
    var dark: Themes {
        willSet(newValue) {
            self.darkTheme = Self.concreteThemeFromTheme(newValue)
        }
    }
    /// Represents the theme for light mode
    var light: Themes {
        willSet(newValue) {
            self.lightTheme = Self.concreteThemeFromTheme(newValue)
        }
    }
    
    /// Variable for switching between modes
    var systemColorScheme: ColorScheme
    
    /// Setup the theme with a default value
    init(darkTheme: Themes, lightTheme: Themes, colorScheme: ColorScheme) {
        self.systemColorScheme = colorScheme
        self.darkTheme = Self.concreteThemeFromTheme(darkTheme)
        self.dark = darkTheme
        self.lightTheme = Self.concreteThemeFromTheme(lightTheme)
        self.light = lightTheme
    }
    
    /// Map the `Themes` type to a concrete theme protocol implementation
    /// - Parameter theme: Theme to convert
    /// - Returns: Mapped concrete theme
    static func concreteThemeFromTheme(_ theme: Themes) -> any ThemeProtocol {
        switch theme {
        case .deepSea: return ThemeDefaultDark()
        case .notesApp: return NotesAppLight()
        case .beach: return BeachLight()
        case .void: return ThemeVoidDark()
        }
    }
    
    /// Available themes to choose from
    public enum Themes: Codable, CaseIterable {
        case deepSea
        case notesApp
        case beach
        case void
        
        /// User facing name of the theme
        var displayName: String {
            switch self {
            case .deepSea: return "Deep Sea"
            case .notesApp: return "Notes App"
            case .beach: return "Beach"
            case .void: return "Void"
            }
        }
        
        /// About the theme
        var description: String {
            switch self {
            case .deepSea: return "Deep sea blues"
            case .notesApp: return "No thrills light grayscale"
            case .beach: return "A day at the beach"
            case .void: return "The void consumed all color"
            }
        }
    }
}
