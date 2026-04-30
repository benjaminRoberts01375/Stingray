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

/// A light theme that has a white base with splashes of color that subtly move around
public final class ThemeFrostyLight: ThemeProtocol {
    public static let darkPink = Color(
        red: 0.3803921568627451,
        green: 0.12941176470588237,
        blue: 0.17647058823529413
    )
    
    public let representation: ThemeModel.Themes = .frosty
    
    public let colorScheme: ColorScheme = .light
    
    public func appBackground() -> AnyView {
        AnyView( SlidingBubblesView() )
    }
    
    public func buttonBackground() -> AnyShapeStyle { AnyShapeStyle(Color.clear) }
    
    public func labelPrimary() -> AnyShapeStyle { AnyShapeStyle(Color.blue) }
    
    public func labelSecondary() -> AnyShapeStyle { AnyShapeStyle(Color.gray) }
    
    public func activeColor() -> Color { Color.blue.opacity(0.15) }
    
    public func defaultProfileImage() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
    
    public func addProfileStyle() -> AnyShapeStyle { AnyShapeStyle(Color.black) }
    
    public func header1() -> AnyShapeStyle { AnyShapeStyle(Color.blue) }
    
    public func header2() -> AnyShapeStyle { AnyShapeStyle(Self.darkPink) }
    
    /// Circles that slowly fade in and fade out with subtle movements
    public struct SlidingBubblesView: View {
        @State private var bubbles: [BubbleModel] = []
        @State private var spawnTimer: Timer?
        
        public var body: some View {
            GeometryReader { geo in
                ZStack {
                    Color.white
                    ForEach(self.bubbles) { SlidingBubbleView(bubble: $0) }
                }
                .drawingGroup() // Render to offscreen buffer for better performance
                .onAppear {
                    // Start some initial bubbles
                    let count = Int(((geo.size.width * geo.size.height) / 207360).rounded(.awayFromZero) ) // 10 at 4k
                    let duration = { return TimeInterval.random(in: 8...15) }
                    self.bubbles = (1...count).map { i in
                        BubbleModel(
                            startPosition: CGPoint(
                                x: CGFloat.random(in: -50...geo.size.width + 50),
                                y: CGFloat.random(in: -50...geo.size.height + 50)
                            ),
                            duration: duration() * Double(i) // Stagger disappear
                        )
                    }
                    
                    // Setup bubble spawning
                    self.spawnTimer = Timer.scheduledTimer(withTimeInterval: 11.5 / Double(count), repeats: true) { _ in
                        self.bubbles.append(
                            BubbleModel(
                                startPosition: CGPoint(
                                    x: CGFloat.random(in: -50...geo.size.width + 50),
                                    y: CGFloat.random(in: -50...geo.size.height + 50)
                                ),
                                duration: duration()
                            )
                        )
                        self.bubbles.removeAll(where: { $0.complete })
                    }
                }
                .onDisappear { self.spawnTimer?.invalidate() }
            }
        }
    }
    
    /// A single circle that fades in, slides a bit, and fades out
    public struct SlidingBubbleView: View {
        /// Data about the bubble to animate
        @State public var bubble: BubbleModel
        
        public var body: some View {
            Circle()
                .fill(self.bubble.color.opacity(self.bubble.opacity))
                .animation(.linear(duration: BubbleModel.fadeTime), value: self.bubble.opacity)
                .frame(width: self.bubble.radius, height: self.bubble.radius)
                .position(self.bubble.startPosition)
                .blur(radius: self.bubble.radius * 0.4)
                .offset(self.bubble.offsetPosition)
                .animation(.linear(duration: self.bubble.duration), value: self.bubble.offsetPosition)
                .onAppear {
                    // Start to fade in
                    self.bubble.opacity = Double.random(in: 0.2...0.5)
                    
                    // Move the bubble
                    let distance: CGFloat = 10
                    self.bubble.offsetPosition = CGSize(
                        width: self.bubble.duration * CGFloat.random(in: -distance...distance),
                        height: self.bubble.duration * CGFloat.random(in: -distance...distance)
                    )
                    
                    // Fade out
                    Task { // Delay the deletion time so the transition can complete
                        try? await Task.sleep(for: .seconds(self.bubble.duration - BubbleModel.fadeTime))
                        self.bubble.opacity = 0
                        try? await Task.sleep(for: .seconds(BubbleModel.fadeTime))
                        await MainActor.run { self.bubble.complete = true }
                    }
                }
        }
    }
    
    /// Animation data for a bubble
    @Observable
    public final class BubbleModel: Identifiable {
        /// Where on screen the bubble starts
        public let startPosition: CGPoint
        /// 1/2 the size of the bubble
        public let radius: CGFloat = CGFloat.random(in: 100...500)
        /// Color of the bubble
        public let color: Color = [.red, .blue, .green, .yellow, .orange, .cyan, .indigo, .mint, .pink, .teal].randomElement() ?? .red
        /// How long the bubble should be shown for
        public let duration: TimeInterval
        
        /// Bubble transparency
        public var opacity: Double = 0
        /// How far the bubble slides
        public var offsetPosition: CGSize = .zero
        /// Tracks when the animation is complete. Set by the `SlidingBubbleView`
        public var complete: Bool = false
        
        /// How long it takes for a bubble to fade in/out
        public static let fadeTime: TimeInterval = 1.5
        
        /// Sets up the data for a bubble
        /// - Parameters:
        ///   - startPosition: Where on screen the bubble should start
        public init(startPosition: CGPoint, duration: TimeInterval) {
            self.startPosition = startPosition
            self.duration = duration
        }
    }
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

/// A beach with water coming in and out
public final class ThemeRetroMid: ThemeProtocol {
    public static let gridColor = Color(red: 0.7411764705882353, green: 0.17254901960784313, blue: 0.4823529411764706) // #BD2C7B
    
    public let representation: ThemeModel.Themes = .retro
    
    public let colorScheme: ColorScheme = .dark
    
    public func appBackground() -> AnyView {
        AnyView(RetroVibes())
    }
    
    public func buttonBackground() -> AnyShapeStyle { AnyShapeStyle(.regularMaterial) }
    
    public func labelPrimary() -> AnyShapeStyle { AnyShapeStyle(Color.white) }
    
    public func labelSecondary() -> AnyShapeStyle { AnyShapeStyle(Color.gray) }
    
    public func activeColor() -> Color { RetroVibes.deepYellow.opacity(0.75) }
    
    public func defaultProfileImage() -> AnyShapeStyle { AnyShapeStyle(RetroVibes.deepPurple) }
    
    public func addProfileStyle() -> AnyShapeStyle { self.defaultProfileImage() }
    
    public func header1() -> AnyShapeStyle { AnyShapeStyle(RetroVibes.deepYellow) }
    
    public func header2() -> AnyShapeStyle { AnyShapeStyle(Color.white) }
    
    public struct RetroVibes: View {
        public static let deepPurple = Color(red: 0.11764705882352941, green: 0.011764705882352941, blue: 0.23529411764705882)
        public static let deepPink = Color(red: 0.7333333333333333, green: 0.0784313725490196, blue: 0.42745098039215684)
        public static let deepYellow = Color(red: 1, green: 0.9372549019607843, blue: 0.615686274509804)
        
        public let columns: Int = 15
        public let rows: Int = 16
        /// X position of the vanishing point (0.0 = left, 1.0 = right)
        public let vanishingPointX: CGFloat = 0.5
        /// Seconds for one row's worth of grid travel toward the camera
        public let cycleDuration: Double = 60.0
        
        public var body: some View {
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .foregroundStyle(
                            RadialGradient(
                                colors: [.clear, .orange.opacity(0.45), Self.deepYellow],
                                center: UnitPoint(x: 1.4, y: -0.3),
                                startRadius: 30,
                                endRadius: 1000
                            )
                        )
                        .brightness(0.1)
                        .offset(y: -geo.size.height / 4)
                        .frame(height: geo.size.height / 2.5)
                    VStack(alignment: .center, spacing: 0) {
                        Spacer(minLength: 0)
                        ZStack {
                            HStack { // Background mountains
                                Triangle()
                                    .frame(width: geo.size.width / 3, height: geo.size.height / 3)
                                    .offset(x: CGFloat.random(in: 100...250))
                                Triangle()
                                    .frame(width: geo.size.width / 3, height: geo.size.height / 3)
                                    .offset(x: CGFloat.random(in: 100...200))
                                Triangle()
                                    .frame(width: geo.size.width / 3, height: geo.size.height / 3)
                                    .offset(x: CGFloat.random(in: -200...100))
                                Triangle()
                                    .frame(width: geo.size.width / 3, height: geo.size.height / 3)
                                    .offset(x: CGFloat.random(in: -300...100))
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    stops: [
                                        Gradient.Stop(
                                            color: Self.deepPurple,
                                            location: 0.5
                                        ),
                                        Gradient.Stop(
                                            color: .pink,
                                            location: 1.2
                                        )
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            
                            HStack(alignment: .bottom) { // Midground mountains
                                ForEach(0..<4) { _ in
                                    Triangle()
                                        .frame(
                                            height: geo.size.height / (CGFloat.random(in: 4...6)),
                                            alignment: .bottom
                                        )
                                        .offset(x: CGFloat.random(in: -400...400))
                                }
                            }
                            .frame(maxWidth: geo.size.width * 1.3, maxHeight: geo.size.height / 3, alignment: .bottom)
                            .foregroundStyle(
                                LinearGradient(
                                    stops: [
                                        Gradient.Stop(
                                            color: Self.deepPurple,
                                            location: 0.3
                                        ),
                                        Gradient.Stop(
                                            color: .pink,
                                            location: 1.2
                                        )
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .brightness(0.03)
                            
                            HStack { // Foreground mountains
                                Triangle()
                                    .frame(maxHeight: geo.size.height / 3 - 40)
                                    .offset(x: CGFloat.random(in: -100...0))
                                Triangle()
                                    .frame(maxHeight: geo.size.height / 3 - 40)
                                Triangle()
                                    .frame(maxHeight: geo.size.height / 3 - 40)
                                    .offset(x: CGFloat.random(in: 0...100))
                            }
                            .frame(maxWidth: geo.size.width, maxHeight: geo.size.height / 3, alignment: .bottom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Self.deepPurple, .pink],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .brightness(0.04)
                        }
                        .frame(width: geo.size.width, height: geo.size.height / 3, alignment: .bottom)
                        .clipped()
                        
                        // Ground
                        TimelineView(.animation) { timeline in
                            Canvas { context, size in
                                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                                let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration)
                                context.stroke(
                                    self.floorGenerator(in: size, phase: phase),
                                    with: .color(ThemeRetroMid.gridColor),
                                    lineWidth: 5
                                )
                            }
                        }
                        .frame(maxHeight: geo.size.height / 3)
                        .background(
                            RadialGradient(
                                colors: [.pink, Self.deepPurple],
                                center: UnitPoint(x: 0.5, y: 1.3),
                                startRadius: 5,
                                endRadius: 400
                            )
                        )
                        .background(Self.deepPurple)
                    }
                }
                .background(
                    LinearGradient(
                        colors: [
                            Self.deepYellow,
                            Self.deepPink,
                            Self.deepPurple
                        ],
                        startPoint: .center,
                        endPoint: .top
                    )
                )
            }
        }
        
        /// Generates a grid floor
        /// - Parameters:
        ///   - size: Available size to draw the floor
        ///   - phase: Offset of the horizontal lines for animation
        /// - Returns: The planned floor
        public func floorGenerator(in size: CGSize, phase: CGFloat = 0) -> Path {
            var path = Path()
            
            // Vanishing point sits above the canvas; horizonOffset controls perspective steepness
            let horizonOffset = size.height * 0.5
            let vanishingPoint = CGPoint(
                x: size.width * vanishingPointX,
                y: -horizonOffset
            )
            
            // Bottom extension factor — how far past the canvas bottom edge the lines reach
            let s = 1 + size.height / horizonOffset
            
            // Column lines: top spans 0...size.width, bottom fans past the canvas edges
            for col in 0...columns {
                let t = CGFloat(col) / CGFloat(columns)
                let topX = t * size.width
                let bottomX = vanishingPoint.x + s * (topX - vanishingPoint.x)
                
                path.move(to: CGPoint(x: topX, y: 0))
                path.addLine(to: CGPoint(x: bottomX, y: size.height))
            }
            
            // Horizontal rows: phase shifts each row toward the camera, wrapping at the horizon
            for row in 0...rows {
                var raw = CGFloat(row) / CGFloat(rows) + phase
                raw -= floor(raw)
                let curved = raw * raw
                let y = curved * size.height
                
                let rowS = (y + horizonOffset) / horizonOffset
                let leftX = vanishingPoint.x + rowS * (0 - vanishingPoint.x)
                let rightX = vanishingPoint.x + rowS * (size.width - vanishingPoint.x)
                
                path.move(to: CGPoint(x: leftX, y: y))
                path.addLine(to: CGPoint(x: rightX, y: y))
            }
            
            return path
        }
    }
}

public struct Triangle: Shape {
    public func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
