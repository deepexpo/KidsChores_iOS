//
//  PressableButtonStyle.swift
//  KidsChores
//
//  Tactile press feedback that's purely *visual* — a subtle scale + spring on
//  touch. No haptic (haptics are reserved for meaningful confirmations only, to
//  avoid overuse). Applied to cards/tiles/rows so the app feels responsive.
//

import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// `.buttonStyle(.pressable)` — visual scale feedback, no haptic.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
