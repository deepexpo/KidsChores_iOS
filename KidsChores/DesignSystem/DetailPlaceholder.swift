//
//  DetailPlaceholder.swift
//  KidsChores
//
//  The "nothing selected yet" state for an iPad detail pane. Replaces a stark
//  ContentUnavailableView with the brand mark on a soft tinted backdrop so the
//  two-column layout never looks empty/plain.
//

import SwiftUI

struct DetailPlaceholder: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Soft brand glow behind the mark.
            Circle()
                .fill(Brand.clay.opacity(0.10))
                .frame(width: 240, height: 240)
                .blur(radius: 40)

            VStack(spacing: 16) {
                BrandMark(size: 84)
                    .padding(20)
                    .background(Brand.backdrop, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                Text(title)
                    .font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
        }
    }
}

#Preview {
    DetailPlaceholder(title: "Select a task", subtitle: "Pick something from the list to see the details.")
}
