import SwiftUI

/// A premium, institutional card: material background, one restrained accent, an
/// SF Symbol (non-smiley), considered spacing and type. No emoji, no default
/// blue button. See AGENTS.md §6.
///
/// Starter template. Build and run before shipping; not yet device-verified.
@available(iOS 17.0, *)
struct PremiumCard: View {
    let title: String
    let subtitle: String
    let symbol: String          // an SF Symbol name, e.g. "waveform.path.ecg"
    var accent: Color = .indigo

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.12), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

@available(iOS 17.0, *)
#Preview {
    ZStack {
        Color(white: 0.07).ignoresSafeArea()
        PremiumCard(
            title: "Skin analysis",
            subtitle: "Tap to start a guided, controlled capture.",
            symbol: "waveform.path.ecg"
        )
        .padding()
    }
}
