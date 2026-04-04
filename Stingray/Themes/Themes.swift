//
//  Themes.swift
//  Stingray
//
//  Created by Ben Roberts on 4/2/26.
//

import SwiftUI

/// How a theme needs to be built
public protocol ThemeProtocol {
    /// Prefer dark mode or light mode SwiftUI rendering
    var colorScheme: ColorScheme { get }
    
    /// How the app's background should be rendered
    func appBackground() -> AnyView
    
    /// The background color of a normal button or menu
    func buttonBackground() -> AnyShapeStyle
    
    /// When an option is active but not selected
    func activeColor() -> Color
    
    /// View used when there is no default image on profiles
    func defaultProfileImage() -> AnyShapeStyle
    
    /// Color to use for shading the add profile icon
    func addProfileStyle() -> AnyShapeStyle
    
    /// The normal color used on labels
    func labelPrimary() -> AnyShapeStyle
    
    /// If a button has a secondary element, shade it accordingly
    func labelSecondary() -> AnyShapeStyle
    
    /// Style to use for some of the largest text used
    func header1() -> AnyShapeStyle
    
    /// Style to use for slightly smaller than the largest text
    func header2() -> AnyShapeStyle
}

/// A dark blue color scheme, like deep in the ocean
public final class ThemeDeepSea: ThemeProtocol {
    public let colorScheme: ColorScheme = .dark
    
    public func appBackground() -> AnyView {
        AnyView(
            LinearGradient(
                colors: [Color(red: 0, green: 0.145, blue: 0.223), Color(red: 0, green: 0.063, blue: 0.153)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    public func buttonBackground() -> AnyShapeStyle { AnyShapeStyle(Color.clear) }
    
    public func labelPrimary() -> AnyShapeStyle { AnyShapeStyle(Color.white) }
    
    public func labelSecondary() -> AnyShapeStyle { AnyShapeStyle(Color.gray) }
    
    public func activeColor() -> Color { Color.white.opacity(0.25) }
    
    public func defaultProfileImage() -> AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0, green: 0.729, blue: 1),
                    Color(red: 0, green: 0.09, blue: 0.945)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    public func addProfileStyle() -> AnyShapeStyle { AnyShapeStyle(.white) }
    
    public func header1() -> AnyShapeStyle { AnyShapeStyle(Color.white) }
    
    public func header2() -> AnyShapeStyle { AnyShapeStyle(Color.white) }
}

/// A white theme and grayscale theme
public final class ThemeNotesAppLight: ThemeProtocol {
    public let colorScheme: ColorScheme = .light
    
    public func appBackground() -> AnyView { AnyView(Color.white) }
    
    public func buttonBackground() -> AnyShapeStyle { AnyShapeStyle(Color.gray.opacity(0.15)) }
    
    public func labelPrimary() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
    
    public func labelSecondary() -> AnyShapeStyle { AnyShapeStyle(Color.gray) }
    
    public func activeColor() -> Color { Color.gray.opacity(0.15) }
    
    public func defaultProfileImage() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
    
    public func addProfileStyle() -> AnyShapeStyle { self.defaultProfileImage() }
    
    public func header1() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
    
    public func header2() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
}

/// A light theme with a little splash of color in the background
public final class ThemeBeachLight: ThemeProtocol {
    public let colorScheme: ColorScheme = .light
    public static let tan = Color(red: 1, green: 0.973, blue: 0.863)
    
    public func appBackground() -> AnyView {
        AnyView(
            LinearGradient(
                colors: [
                    Color(red: 0.094, green: 0.635, blue: 0.996),
                    Self.tan
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    public func buttonBackground() -> AnyShapeStyle { AnyShapeStyle(.thinMaterial) }
    
    public func labelPrimary() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
    
    public func labelSecondary() -> AnyShapeStyle { AnyShapeStyle(Color.gray) }
    
    public func activeColor() -> Color { Color.white.opacity(0.5) }
    
    public func defaultProfileImage() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
    
    public func addProfileStyle() -> AnyShapeStyle { self.defaultProfileImage() }
    
    public func header1() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
    
    public func header2() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
}

/// A super dark theme
public final class ThemeVoidDark: ThemeProtocol {
    public let colorScheme: ColorScheme = .dark
    
    public func appBackground() -> AnyView { AnyView(Color.black) }
    
    public func buttonBackground() -> AnyShapeStyle { AnyShapeStyle(Color(red: 0.1, green: 0.1, blue: 0.1)) }
    
    public func labelPrimary() -> AnyShapeStyle { AnyShapeStyle(Color.white.opacity(0.9)) }
    
    public func labelSecondary() -> AnyShapeStyle { AnyShapeStyle(Color.gray) }
    
    public func activeColor() -> Color { Color.gray.opacity(0.15) }
    
    public func defaultProfileImage() -> AnyShapeStyle { AnyShapeStyle(Color.gray) }
    
    public func addProfileStyle() -> AnyShapeStyle { self.defaultProfileImage() }
    
    public func header1() -> AnyShapeStyle { AnyShapeStyle(Color.white) }
    
    public func header2() -> AnyShapeStyle { AnyShapeStyle(Color.white) }
}
