//
//  OfflineBanner.swift
//  KidsChores
//
//  Small, non-blocking notice shown when a screen is rendering cached content
//  because the network is unreachable (ios-prd §7.1 offline state / §12).
//

import SwiftUI

struct OfflineBanner: View {
    var message: String = "Showing saved tasks — will sync when back online."

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text(message)
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    OfflineBanner()
}
