//
//  ThemeViewModel.swift
//  Stingray
//
//  Created by Ben Roberts on 4/2/26.
//

import SwiftUI

public struct StingrayBackground: ViewModifier {
    @Environment(ThemeModel.self) var theme
    
    public func body(content: Content) -> some View {
        content
            .background { theme.currentTheme.appBackground() }
            .ignoresSafeArea()
    }
}

/// An extension for adding theme-related modifers to views
public extension View {
    /// Load the background for Stingray
    func stingrayBackground() -> some View {
        modifier(StingrayBackground())
    }
}

struct StingrayFormButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    @Environment(ThemeModel.self) var theme
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            configuration.label
                .foregroundStyle(isFocused ? Color.black : Color.primary)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background {
                    Capsule()
                        .fill(isFocused ? AnyShapeStyle(Color.white) : self.theme.currentTheme.buttonBackground())
                        .shadow(color: .black.opacity(isFocused ? 0.45 : 0), radius: isFocused ? 15 : 0, y: isFocused ? 16 : 0)
                }
                .padding(.horizontal, -20)
                .padding(.vertical, -15)
                .listRowBackground(Color.clear)
                .frame(width: geo.size.width * (isFocused ? 1.005 : 1), height: geo.size.height * (isFocused ? 1.12 : 1))
                .offset(x: isFocused ? -geo.size.width * 0.0025 : 0, y: isFocused ? -geo.size.height * 0.06 : 0)
        }
        .animation(.easeOut(duration: 0.1), value: self.isFocused)
    }
}

public struct DoubleButton: View {
    /// Primary label to show on left-hand side of button
    let label: String
    /// Secondary label to show on right-hand side of button
    let sublabel: String
    /// Code to run when the button's pressed
    let action: () -> Void
    
    @Environment(ThemeModel.self) var theme: ThemeModel
    
    public var body: some View {
        Button { action() }
        label: {
            HStack {
                Text(label)
                Spacer()
                Text(sublabel)
                    .foregroundStyle(theme.currentTheme.buttonSecondary())
                    .fontWeight(.regular)
            }
        }
        .buttonStyle(StingrayFormButtonStyle())
    }
}

public struct DoubleMenu<Content: View>: View {
    /// Primary label to show on left-hand side of button
    let label: String
    /// Secondary label to show on right-hand side of button
    let sublabel: String
    /// Content to show in the menu
    @ViewBuilder let content: () -> Content
    
    @Environment(ThemeModel.self) var theme: ThemeModel
    
    public var body: some View {
        Menu { content() }
        label: {
            HStack {
                Text(label)
                Spacer()
                Text(sublabel)
                    .foregroundStyle(theme.currentTheme.buttonSecondary())
                    .fontWeight(.regular)
            }
        }
        .buttonStyle(StingrayFormButtonStyle())
    }
}
