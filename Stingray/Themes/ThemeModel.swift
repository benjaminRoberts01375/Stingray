//
//  ThemeModel.swift
//  Stingray
//
//  Created by Ben Roberts on 3/31/26.
//

import SwiftUI

/// Manages the current theme
@Observable
public final class ThemeModel: Identifiable {
    /// Theme for system dark mode
    public var darkTheme: any ThemeProtocol
    /// Theme for system light mode
    public var lightTheme: any ThemeProtocol
    /// The implementation of the current theme
    public var currentTheme: any ThemeProtocol { systemColorScheme == .dark ? darkTheme : lightTheme }
    
    /// Represents the theme for dark mode
    public var dark: Themes {
        willSet(newValue) {
            self.darkTheme = Self.concreteThemeFromTheme(newValue)
        }
    }
    /// Represents the theme for light mode
    public var light: Themes {
        willSet(newValue) {
            self.lightTheme = Self.concreteThemeFromTheme(newValue)
        }
    }
    
    /// Variable for switching between modes
    public var systemColorScheme: ColorScheme
    
    /// Setup the theme with a default value
    public init(darkTheme: Themes, lightTheme: Themes, colorScheme: ColorScheme) {
        self.systemColorScheme = colorScheme
        self.darkTheme = Self.concreteThemeFromTheme(darkTheme)
        self.dark = darkTheme
        self.lightTheme = Self.concreteThemeFromTheme(lightTheme)
        self.light = lightTheme
    }
    
    /// Map the `Themes` type to a concrete theme protocol implementation
    /// - Parameter theme: Theme to convert
    /// - Returns: Mapped concrete theme
    public static func concreteThemeFromTheme(_ theme: Themes) -> any ThemeProtocol {
        switch theme {
        case .deepSea: return ThemeDeepSeaDark()
        case .notesApp: return ThemeNotesAppLight()
        case .beach: return ThemeBeachLight()
        case .void: return ThemeVoidDark()
        case .spaceVampires: return ThemeSpaceVampiresDark()
        case .frosty: return ThemeFrostyLight()
        case .retro: return ThemeRetroMid()
        }
    }
    
    /// Available themes to choose from
    public enum Themes: Codable, CaseIterable {
        case notesApp
        case frosty
        case beach
        case retro
        case deepSea
        case spaceVampires
        case void
        
        /// User facing name of the theme
        public var displayName: String {
            switch self {
            case .deepSea: return "Deep Sea"
            case .notesApp: return "Notes App"
            case .beach: return "Beach"
            case .void: return "Void"
            case .spaceVampires: return "Space Vampires"
            case .frosty: return "Frosty"
            case .retro: return "Synth"
            }
        }
        
        /// About the theme
        public var description: String {
            switch self {
            case .deepSea: return "Deep sea blues"
            case .notesApp: return "No thrills light grayscale"
            case .beach: return "A day at the beach"
            case .void: return "The void consumes all color"
            case .spaceVampires: return "Dracula on a clear night"
            case .frosty: return "Little splashes of color"
            case .retro: return "Ride like the 2000's"
            }
        }
        
        /// Check if the theme requires being a supporter
        public var requiresSupporter: Bool {
            switch self {
            case .retro, .frosty, .spaceVampires: return true
            default: return false
            }
        }
    }
}
