import SwiftUI

/// A premium, institutional card: material background, one restrained accent, an
/// SF Symbol (non-smiley), considered spacing and type. No emoji, no default
/// blue button. See AGENTS.md §6.
///
/// Composes the `DesignTokens` (`DS`) single source of truth — spacing, radius,
/// type and the card surface (`.dsCard()`) all come from tokens, not raw values.
/// This is what `vibe-ios-doctor`'s §6 consistency rules enforce, and what keeps
/// the card coherent with every other surface in the app.
///
/// Starter template. Build and run before shipping; not yet device-verified.
@available(iOS 17.0, *)
struct PremiumCard: View {
    let title: String
    let subtitle: String
    let symbol: String          // an SF Symbol name, e.g. "waveform.path.ecg"
    var accent: Color = DS.Color.accent

    var body: some View {
        HStack(spacing: DS.Space.lg) {
            Image(systemName: symbol)
                .font(DS.Font.title)
                .foregroundStyle(accent)
                .frame(width: DS.Space.xxxl, height: DS.Space.xxxl)
                .background(accent.opacity(0.12), in: .rect(cornerRadius: DS.Radius.md))

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(title)
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.textPrimary)
                Text(subtitle)
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(DS.Font.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DS.Space.lg)
        .dsCard()
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
