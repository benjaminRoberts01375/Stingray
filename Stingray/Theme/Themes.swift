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
    
    /// If a button has a secondary element, shade it accordingly
    func buttonSecondary() -> Color
    
    /// When an option is active but not selected
    func activeColor() -> Color
    
    /// View used when there is no default image on profiles
    func defaultProfileImage() -> AnyShapeStyle
}

/// A dark blue color scheme, like deep in the ocean
public final class ThemeDefaultDark: ThemeProtocol {
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
    
    public func buttonSecondary() -> Color { Color.gray }
    
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
}

/// A white theme with a little splash of color in the background
public final class NotesAppLight: ThemeProtocol {
    public let colorScheme: ColorScheme = .light
    
    public func appBackground() -> AnyView { AnyView(Color.white) }
    
    public func buttonBackground() -> AnyShapeStyle { AnyShapeStyle(Color.gray.opacity(0.15)) }
    
    public func buttonSecondary() -> Color { Color.gray }
    
    public func activeColor() -> Color { Color.gray.opacity(0.15) }
    
    public func defaultProfileImage() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
}
