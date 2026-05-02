//
//  ThemeViewModel.swift
//  Stingray
//
//  Created by Ben Roberts on 4/2/26.
//

import SwiftUI

public struct StingrayBackground: ViewModifier {
    @Environment(ThemeModel.self) private var theme
    
    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { self.theme.currentTheme.appBackground() }
    }
}

/// An extension for adding theme-related modifers to views
public extension View {
    /// Load the background for Stingray
    func stingrayBackground() -> some View {
        modifier(StingrayBackground())
    }
}

/// Style buttons in a `Form` view.
public struct StingrayFormButtonStyle: ButtonStyle {
    @Environment(\.isFocused) public var isFocused
    @Environment(ThemeModel.self) private var theme
    
    public func makeBody(configuration: Configuration) -> some View {
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

/// A button designed for a `Form` view that shows a label on the left, and some status or information on the right
public struct DoubleButton: View {
    /// Primary label to show on left-hand side of button
    public let label: String
    /// Secondary label to show on right-hand side of button
    public let sublabel: String
    /// The type of action the button may cause
    public let role: ButtonRole?
    /// Code to run when the button's pressed
    public let action: () -> Void
    
    @Environment(ThemeModel.self) private var theme
    
    @FocusState private var isFocused: Bool
    
    public init(label: String, sublabel: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.label = label
        self.sublabel = sublabel
        self.action = action
        self.role = role
    }
    
    public var body: some View {
        Button(role: role) { action() }
        label: {
            HStack {
                Text(label)
                    .foregroundStyle({
                        if self.isFocused { return AnyShapeStyle(Color.black) }
                        else if self.role == .destructive { return AnyShapeStyle(Color.red) }
                        else { return self.theme.currentTheme.labelPrimary() }
                    }())
                Spacer()
                Text(sublabel)
                    .foregroundStyle(self.theme.currentTheme.labelSecondary())
                    .fontWeight(.regular)
            }
        }
        .buttonStyle(StingrayFormButtonStyle())
        .focused($isFocused, equals: true)
    }
}

/// A menu designed for a `Form` view that shows a label on the left, and some status or information on the right
public struct DoubleMenu<Content: View>: View {
    /// Primary label to show on left-hand side of button
    public let label: String
    /// Secondary label to show on right-hand side of button
    public let sublabel: String
    /// Content to show in the menu
    @ViewBuilder public let content: () -> Content
    
    @Environment(ThemeModel.self) private var theme
    
    @FocusState private var isFocused: Bool
    
    public var body: some View {
        Menu { content() }
        label: {
            HStack {
                Text(label)
                    .foregroundStyle(self.isFocused ? AnyShapeStyle(Color.black) : self.theme.currentTheme.labelPrimary())
                Spacer()
                Text(sublabel)
                    .foregroundStyle(self.theme.currentTheme.labelSecondary())
                    .fontWeight(.regular)
            }
        }
        .buttonStyle(StingrayFormButtonStyle())
        .focused($isFocused, equals: true)
    }
}

/// Uses liquid glass if available, and falls back to `ultraThinMaterial` if needed (with a shape)
public struct AvailableGlass<S: Shape>: ViewModifier {
    /// Shape for either the material or liquid glass to take
    public let shape: S
    /// Padding between content and edge
    public let padding: CGFloat
    
    public func body(content: Content) -> some View {
        if #available(tvOS 26.0, *) {
            content
                .padding(self.padding)
                .glassEffect(.regular, in: self.shape)
                .padding(-self.padding)
        }
        else {
            content
                .padding(self.padding)
                .background(.ultraThinMaterial, in: self.shape)
                .padding(-self.padding)
        }
    }
}

/// An extension for adding theme-related modifers to views
public extension View {
    /// Switches between iOS 18's `ultraThinMaterial` and tvOS 26's regular `glassEffect`
    /// - Parameter shape: Shape the background takes
    /// - Parameter padding: Padding between edge and content
    /// - Returns: View with background
    func availableGlass<S: Shape>(in shape: S = .rect(cornerRadius: 24.0), padding: CGFloat = 20) -> some View {
        modifier(AvailableGlass(shape: shape, padding: padding))
    }
}
