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
            .background { self.theme.currentTheme.appBackground }
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
                        .fill(isFocused ? AnyShapeStyle(Color.white) : self.theme.currentTheme.buttonBackground)
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
    public let label: LocalizedStringKey
    /// Secondary label to show on right-hand side of button
    public let sublabel: LocalizedStringKey
    /// The type of action the button may cause
    public let role: ButtonRole?
    /// Code to run when the button's pressed
    public let action: () -> Void
    
    @Environment(ThemeModel.self) private var theme
    
    @FocusState private var isFocused: Bool
    
    public init(label: LocalizedStringKey, sublabel: LocalizedStringKey, role: ButtonRole? = nil, action: @escaping () -> Void) {
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
                        else { return self.theme.currentTheme.labelPrimary }
                    }())
                Spacer()
                Text(sublabel)
                    .foregroundStyle(self.theme.currentTheme.labelSecondary)
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
    public let label: LocalizedStringKey
    /// Secondary label to show on right-hand side of button
    public let sublabel: LocalizedStringKey
    /// Content to show in the menu
    @ViewBuilder public let content: () -> Content
    
    @Environment(ThemeModel.self) private var theme
    
    @FocusState private var isFocused: Bool
    
    public var body: some View {
        Menu { content() }
        label: {
            HStack {
                Text(label)
                    .foregroundStyle(self.isFocused ? AnyShapeStyle(Color.black) : self.theme.currentTheme.labelPrimary)
                Spacer()
                Text(sublabel)
                    .foregroundStyle(self.theme.currentTheme.labelSecondary)
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

/// Makes text taste the rainbow
public struct RainbowText: View {
    /// Text to rainbow-ify
    public let text: String
    /// Animation phase
    @State private var phase: Double = 0
    /// Colors of the rainbow starting with red
    private static let colors: [RGB] = [
        RGB(red: 1.0, green: 0.0, blue: 0.0), // Red
        RGB(red: 1.0, green: 0.5, blue: 0.0), // Orange
        RGB(red: 1.0, green: 1.0, blue: 0.0), // Yellow
        RGB(red: 0.0, green: 1.0, blue: 0.0), // Green
        RGB(red: 0.0, green: 1.0, blue: 1.0), // Cyan
        RGB(red: 0.0, green: 0.0, blue: 1.0), // Blue
        RGB(red: 0.5, green: 0.0, blue: 0.5)  // Purple
    ]
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            HStack(spacing: 0) {
                ForEach(Array(self.text.enumerated()), id: \.offset) { index, character in
                    Text(String(character))
                        .foregroundStyle(self.colorForIndex(index, at: timeline.date))
                        .saturation(0.75)
                }
            }
        }
    }
    
    /// Calculate the interpolated rainbow color for a character at a specific index and time.
    /// - Parameters:
    ///   - index: The position of the character in the text string.
    ///   - date: The current date/time used to animate the rainbow effect.
    /// - Returns: The interpolated color for this character at this moment in time.
    private func colorForIndex(_ index: Int, at date: Date) -> Color {
        let colorCount = Double(Self.colors.count)
        let timeOffset = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.0) / 2.0
        let letterOffset = Double(index) / Double(self.text.count)
        var animatedOffset = (letterOffset - timeOffset).truncatingRemainder(dividingBy: 1.0)
        
        // Ensure animatedOffset is always positive
        if animatedOffset < 0 { animatedOffset += 1.0 }
        
        let colorIndex = Int(animatedOffset * colorCount)
        let nextColorIndex = (colorIndex + 1) % Self.colors.count
        let fraction = (animatedOffset * colorCount).truncatingRemainder(dividingBy: 1.0)
        
        // Interpolate between colors for smooth transitions
        return interpolateColor(
            from: Self.colors[colorIndex],
            to: Self.colors[nextColorIndex],
            iFrac: fraction
        )
    }
    
    /// Smoothly blend between two colors using linear interpolation. Helpful if the word doesn't perfectly fit the rainbow
    /// - Parameters:
    ///   - from: The starting color.
    ///   - to: The ending color.
    ///   - iFrac: The interpolation fraction between 0.0 (all `from`) and 1.0 (all `to`).
    /// - Returns: A blended color.
    private func interpolateColor(from fromColor: RGB, to toColor: RGB, iFrac: Double) -> Color {
        // This creates a gradient-like blend between colors
        return Color(
            red: linearInterpolation(from: fromColor.red, to: toColor.red, i: iFrac),
            green: linearInterpolation(from: fromColor.green, to: toColor.green, i: iFrac),
            blue: linearInterpolation(from: fromColor.blue, to: toColor.blue, i: iFrac)
        )
    }
    
    /// Perform linear interpolation between two values.
    /// - Parameters:
    ///   - from: The starting value.
    ///   - to: The ending value.
    ///   - interpolation: The interpolation parameter between 0.0 and 1.0.
    /// - Returns: The interpolated value.
    private func linearInterpolation(from: Double, to: Double, i interpolation: Double) -> Double {
        return from + (to - from) * interpolation
    }
    
    /// RGB color components.
    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }
}
