//
//  MarqueeText.swift
//  Stingray
//
//  Created by Ben Roberts on 7/30/26.
//

import SwiftUI

/// Text that scrolls horizontally when it is too wide to fit, and sits statically centered when it fits.
/// Widths are measured by rendering hidden copies of the text and the separator, so the view starts out assuming it fits
/// and switches to scrolling once measurement comes back.
public struct MarqueeText: View {
    /// Measured width of a single copy of the text
    @State private var textWidth: CGFloat = .zero
    /// Measured height of the text, used to size the whole view
    @State private var textHeight: CGFloat = 20
    /// Measured width of the `" • "` separator between repeats
    @State private var separatorWidth: CGFloat = 20
    /// Measured width of the space available. Starts effectively infinite so nothing scrolls before measurement
    @State private var containerWidth: CGFloat = .greatestFiniteMagnitude
    /// Drives the scroll. Set on appear and cleared on disappear so the animation doesn't run offscreen
    @State private var animating: Bool = false
    /// Whether the text is too wide for the space available
    private var doesOverflow: Bool { self.containerWidth - self.textWidth < 0 }

    /// Seconds for one full scroll cycle
    private let duration: Double = 6
    /// Seconds to wait before the scroll starts
    private let delay: Double = 0
    /// Text to display
    private let text: String
    /// Whether overflowing text should scroll, or simply truncate
    private let animate: Bool
    /// Font applied to both the displayed text and the hidden measurement copies
    private let font: Font?

    /// Horizontally scrolling text when text cannot fit
    /// - Parameters:
    ///   - text: Text to display
    ///   - animate: Whether or not to animate the text or simply truncate it
    ///   - font: How the text is displayed
    public init(text: String, animate: Bool, font: Font?) {
        self.text = text
        self.animate = animate
        self.font = font
    }

    public var body: some View {
        GeometryReader { containerGeo in
            if self.doesOverflow && self.animate { // Long scrolling text
                Text(String(repeating: self.text + " • ", count: 3))
                    .font(self.font)
                    .fixedSize()
                    .offset(x: self.animating ? -(self.textWidth + self.separatorWidth) * 2 : -(self.textWidth + self.separatorWidth))
                    .onAppear { self.animating = true }
                    .onDisappear { self.animating = false }
                    .animation(
                        self.animating
                        ? Animation.linear(duration: self.duration)
                            .delay(self.delay)
                            .repeatForever(autoreverses: false)
                        : .default,
                        value: self.animating
                    )
            }
            else { // Short static text
                ZStack {
                    Text(self.text) // Only used for calculations
                        .font(self.font)
                        .lineLimit(1)
                        .fixedSize()
                        .background {
                            GeometryReader { textGeo in
                                Color.clear
                                    .onAppear {
                                        self.containerWidth = containerGeo.size.width
                                        self.textWidth = textGeo.size.width
                                        self.textHeight = textGeo.size.height
                                    }
                            }
                        }
                        .frame(width: self.containerWidth, alignment: .leading)
                        .hidden()
                    Text(" • ") // Has to be calculated separately from base text since base text determines if need to animate
                        .font(self.font)
                        .lineLimit(1)
                        .fixedSize()
                        .background {
                            GeometryReader { separatorGeo in
                                Color.clear
                                    .onAppear { self.separatorWidth = separatorGeo.size.width }
                            }
                        }
                        .frame(width: self.containerWidth, alignment: .leading)
                        .hidden()
                    Text(self.text) // Actual text
                        .lineLimit(1)
                        .font(self.font)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(height: self.textHeight)
        .clipped()
    }
}
