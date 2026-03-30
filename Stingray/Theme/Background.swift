//
//  Background.swift
//  Stingray
//
//  Created by Ben Roberts on 3/29/26.
//

import SwiftUI

public struct StingrayBackground: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: [Color(red: 0, green: 0.145, blue: 0.223), Color(red: 0, green: 0.063, blue: 0.153)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
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
