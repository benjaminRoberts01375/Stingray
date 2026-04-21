//
//  Themes.swift
//  Stingray
//
//  Created by Ben Roberts on 4/2/26.
//

import SwiftUI

/// How a theme needs to be built
public protocol ThemeProtocol {
    /// A light-weight stand-in for this theme that holds basic info like the name and description
    var representation: ThemeModel.Themes { get }
    
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
public final class ThemeDeepSeaDark: ThemeProtocol {
    public let representation: ThemeModel.Themes = .deepSea
    
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
    public let representation: ThemeModel.Themes = .notesApp
    
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
    public let representation: ThemeModel.Themes = .beach
    
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
    public let representation: ThemeModel.Themes = .void
    
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

// A theme based on the well-known Dracula theme https://draculatheme.com/spec
public final class ThemeSpaceVampiresDark: ThemeProtocol {
    // Official Dracula colors https://draculatheme.com/spec#color-palette
    public static let background = Color(red: 0.1568627450980392, green: 0.16470588235294117, blue: 0.21176470588235294)
    public static let currentLine = Color(red: 0.3843137254901961, green: 0.4470588235294118, blue: 0.6431372549019608)
    public static let selection = Color(red: 0.26666666666666666, green: 0.2784313725490196, blue: 0.35294117647058826)
    public static let foreground = Color(red: 0.9725490196078431, green: 0.9725490196078431, blue: 0.9490196078431372)
    public static let comment = ThemeSpaceVampiresDark.currentLine
    public static let red = Color(red: 1, green: 0.3333333333333333, blue: 0.3333333333333333)
    public static let orange = Color(red: 1, green: 0.7215686274509804, blue: 0.4235294117647059)
    public static let yellow = Color(red: 0.9450980392156862, green: 0.9803921568627451, blue: 0.5490196078431373)
    public static let green = Color(red: 0.3137254901960784, green: 0.9803921568627451, blue: 0.4823529411764706)
    public static let cyan = Color(red: 0.5450980392156862, green: 0.9137254901960784, blue: 0.9921568627450981)
    public static let purple = Color(red: 0.7411764705882353, green: 0.5764705882352941, blue: 0.9764705882352941)
    public static let pink = Color(red: 1, green: 0.4745098039215686, blue: 0.7764705882352941)
    
    public let representation: ThemeModel.Themes = .spaceVampires
    
    public let colorScheme: ColorScheme = .dark
    
    public func appBackground() -> AnyView {
        AnyView(
            ZStack {
                // Shooting stars
                ShootingStarView()
                
                LinearGradient(colors: [Self.background, .clear], startPoint: .bottom, endPoint: .top)
                
                // Stars
                Canvas { context, size in
                    let starCount = 50
                    let starRegionHeight = size.height / 3
                    
                    for _ in 0..<starCount {
                        let x = Double.random(in: 0..<size.width)
                        let y = Double.random(in: 0..<size.height / 3)
                        let radius = Double.random(in: 0.75..<2)
                        
                        // Handle negative positions
                        let finalX = x < 0 ? x + size.width : x
                        let finalY = y < 0 ? y + starRegionHeight : y
                        
                        let star = Path(ellipseIn: CGRect(x: finalX, y: finalY, width: radius * 2, height: radius * 2))
                        context.fill(star, with: .color(.white.opacity(0.8)))
                    }
                }
                
                // Rolling hills
                RollingHillsView()
            }
                .background(.black)
        )
    }
    
    public struct ShootingStarView: View {
        @State private var angle: Angle = .degrees(0)
        @State private var position: CGPoint = CGPoint(x: 200, y: 100)
        @State private var opacity: CGFloat = .zero
        
        public var body: some View {
            GeometryReader { geo in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.5),
                                .white.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 200, height: 5)
                    .rotationEffect(self.angle)
                    .position(self.position)
                    .opacity(self.opacity)
                    .onAppear {
                        // Start the shooting star animation timer with random intervals
                        self.scheduleNextShootingStar(screenSize: geo.size)
                    }
            }
        }
        
        public func scheduleNextShootingStar(screenSize: CGSize) {
            let randomInterval = Double.random(in: 5...30)
            Timer.scheduledTimer(withTimeInterval: randomInterval, repeats: false) { _ in
                animateShootingStar(screenSize: screenSize)
                scheduleNextShootingStar(screenSize: screenSize)
            }
        }
        
        private func animateShootingStar(screenSize: CGSize) {
            self.opacity = 0
            self.position = CGPoint(
                x: Double.random(in: 0..<screenSize.width),
                y: Double.random(in: 20..<(screenSize.height / 3))
            )
            
            if self.position.x < screenSize.width / 2 { // Left edge
                if self.position.y < screenSize.height / 6 { // Top Left
                    self.angle = .degrees(Double.random(in: 15...75))
                }
                else { // Bottom Left
                    self.angle = .degrees(Double.random(in: 325...380))
                }
            }
            else { // Right edge
                if self.position.y < screenSize.height / 6 { // Top Right
                    self.angle = .degrees(Double.random(in: 105...165))
                }
                else { // Bottom Right
                    self.angle = .degrees(Double.random(in: 145...200))
                }
            }
            
            // Fade in
            withAnimation(.easeIn(duration: 0.5)) {
                self.opacity = 1
            }
            
            // Move along trajectory
            withAnimation(.linear(duration: 1.25)) {
                let distance: CGFloat = 800
                let radians = self.angle.radians
                self.position = CGPoint(
                    x: self.position.x + distance * cos(radians),
                    y: self.position.y + distance * sin(radians)
                )
            }
            
            // Fade out
            withAnimation(.easeOut(duration: 0.3).delay(0.95)) {
                self.opacity = 0
            }
        }
    }
    
    public struct RollingHillsView: View {
        public var body: some View {
            Canvas { context, size in
                // Back hill (darkest purple)
                let backHillPath = createHillPath(
                    size: size,
                    yOffset: size.height * 0.65,
                    amplitude: 60,
                    frequency: 1.5,
                    seed: Int.random(in: 0..<1000)
                )
                context.fill( // ThemeSpaceVampires.purple.opacity(0.03)
                    backHillPath,
                    with: .color(Color(red: 0.12549019607843137, green: 0.12549019607843137, blue: 0.16470588235294117))
                )
                
                // Middle hill
                let middleHillPath = createHillPath(
                    size: size,
                    yOffset: size.height * 0.75,
                    amplitude: 80,
                    frequency: 1.2,
                    seed: Int.random(in: 0..<1000)
                )
                context.fill( // ThemeSpaceVampires.purple.opacity(0.06)
                    middleHillPath,
                    with: .color(Color(red: 0.19215686274509805, green: 0.17647058823529413, blue: 0.25882352941176473))
                )
                
                // Front hill (brightest purple)
                let frontHillPath = createHillPath(
                    size: size,
                    yOffset: size.height * 0.85,
                    amplitude: 100,
                    frequency: 1.0,
                    seed: Int.random(in: 0..<1000)
                )
                context.fill( // ThemeSpaceVampires.purple.opacity(0.1)
                    frontHillPath,
                    with: .color(Color(red: 0.23921568627450981, green: 0.21568627450980393, blue: 0.3215686274509804))
                )
            }
        }
        
        /// Creates a single wave pattern
        /// - Parameters:
        ///   - size: Available width and height
        ///   - yOffset: Vertical shift downwards
        ///   - amplitude: How high waves can move up on their own
        ///   - frequency: Waviness
        ///   - seed: Random number
        /// - Returns: Generated wave pattern
        private func createHillPath(size: CGSize, yOffset: CGFloat, amplitude: CGFloat, frequency: CGFloat, seed: Int) -> Path {
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                
                // Create smooth rolling hills using sine waves
                let steps = 100
                for step in 0...steps {
                    let x = (CGFloat(step) / CGFloat(steps)) * size.width
                    let normalizedX = x / size.width
                    
                    // Use seeded random-like behavior with sine combination
                    let wave = sin(normalizedX * .pi * 2 * frequency + CGFloat(seed) * 0.1)
                    let y = yOffset + wave * amplitude
                    
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // Close the path at bottom right
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
            }
        }
    }
    
    public func buttonBackground() -> AnyShapeStyle {
        AnyShapeStyle(Color(red: 0.1568627450980392, green: 0.17254901960784313, blue: 0.23529411764705882))
    }
    
    public func labelPrimary() -> AnyShapeStyle { AnyShapeStyle(Self.pink) }
    
    public func labelSecondary() -> AnyShapeStyle { AnyShapeStyle(Self.yellow) }
    
    public func activeColor() -> Color { Self.foreground.opacity(0.15) }
    
    public func defaultProfileImage() -> AnyShapeStyle { AnyShapeStyle(Color.gray) }
    
    public func addProfileStyle() -> AnyShapeStyle { self.defaultProfileImage() }
    
    public func header1() -> AnyShapeStyle { AnyShapeStyle(Self.pink) }
    
    public func header2() -> AnyShapeStyle { AnyShapeStyle(Color.yellow) }
}
