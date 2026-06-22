import SwiftUI

/// PrimaryButtonStyle — the ONE primary call-to-action surface.
///
/// Every primary button in the app is `Button(…) { … }.buttonStyle(.dsPrimary)`.
/// No screen hand-rolls a CTA with `.background(DS.Color.accent).cornerRadius(…)`
/// — that ad-hoc form is exactly what `vibe-ios-doctor`'s §6 rule FAILs, because
/// it drifts (a slightly different radius, padding, or pressed state every time
/// the agent re-derives it). Composing this style is how the button stays
/// coherent by construction.
///
/// It is built ENTIRELY from `DS` tokens — accent, radius, spacing, type, motion
/// — so a re-skin is a token change, not a per-button edit.
///
/// iOS 26 path (verified against the SDK): reads `@Environment(\.buttonSizing)`
/// and styles `configuration.content`, so the button adapts to `.buttonSizing(
/// .flexible)` like a native control. Pre-26 path styles `configuration.label`
/// with a sensible fixed width. The pressed state is driven by
/// `configuration.isPressed` (ButtonStyleConfiguration, iOS 13+).
///
/// Premium per AGENTS.md §6: solid accent, white label, token corner, a brief
/// scale + opacity press feedback (easing, not bounce), respectful of Reduce
/// Motion. No emoji.
///
/// Starter template. Build and run before shipping; not yet device-verified.
@available(iOS 17.0, *)
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        // The press feedback is a finite, state-driven animation (no clock,
        // nothing to gate per AGENTS.md §1): it settles on release.
        let pressed = configuration.isPressed
        let scale: CGFloat = (pressed && !reduceMotion) ? 0.97 : 1.0

        return styledContent(configuration)
            .font(DS.Font.button)
            .foregroundStyle(DS.Color.textOnAccent)
            .padding(.vertical, DS.Space.md)
            .padding(.horizontal, DS.Space.xl)
            .background(DS.Color.accent, in: .rect(cornerRadius: DS.Radius.lg))
            .opacity(isEnabled ? (pressed ? 0.85 : 1.0) : 0.4)
            .scaleEffect(scale)
            .animation(DS.Motion.quick, value: pressed)
            .contentShape(.rect(cornerRadius: DS.Radius.lg))
    }

    @ViewBuilder
    private func styledContent(_ configuration: Configuration) -> some View {
        // `configuration.label` is the universal ButtonStyle content. (An earlier
        // draft used `configuration.content` + `\.buttonSizing` for an iOS 26
        // "flexible" path — neither symbol exists in the iOS 27 SDK, so it is gone.)
        configuration.label
            .frame(minWidth: 120)
    }
}

// MARK: - Ergonomic call site: `.buttonStyle(.dsPrimary)`

@available(iOS 17.0, *)
public extension ButtonStyle where Self == PrimaryButtonStyle {
    /// The app's primary CTA style. Usage:
    /// `Button("Start scan") { … }.buttonStyle(.dsPrimary)`
    static var dsPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

@available(iOS 17.0, *)
#Preview {
    ZStack {
        DS.Color.surface.ignoresSafeArea()
        VStack(spacing: DS.Space.lg) {
            Button("Start scan") {}
                .buttonStyle(.dsPrimary)

            Button("Disabled") {}
                .buttonStyle(.dsPrimary)
                .disabled(true)
        }
        .dsScreenPadding()
    }
}
