//
//  Haptics.swift
//  KidsChores
//
//  Thin wrapper over UIFeedbackGenerator (ios-prd §6.4). Haptics are the
//  primary confirmation channel and are intentionally unaffected by Reduce
//  Motion (§13). No-ops on devices without a Taptic Engine / in the Simulator.
//

import UIKit

@MainActor
enum Haptics {
    /// A completed action succeeded (task complete, approval).
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A cautionary outcome (deny, revert).
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// A light touch confirmation (revealing a sheet, toggling).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// The one moment worth extra weight — a series completing (§6.4).
    static func celebrate() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
