import SwiftUI

/// DesignTokens — the single source of truth for the app's visual language.
///
/// A screen composes *tokens*, never raw values. This is the construction that
/// keeps an AI coding agent coherent: it cannot see the rendered UI, so it must
/// not be allowed to pick a hex colour, a padding number, or a corner radius by
/// "feel". Every such decision is named here once, and `vibe-ios-doctor`'s
/// consistency rules FAIL the build when a screen reaches for a raw value
/// instead of a token (see AGENTS.md §6 and the doctor's §6 detectors).
///
/// What this file gives you, and what it deliberately does NOT:
///   - It enforces *use of the system* — one palette, one spacing scale, one
///     radius scale, one type ramp, one button style. That is statically
///     checkable, so it is gated.
///   - It does NOT certify the system looks good. Taste — does THIS accent read
///     premium, is THIS spacing balanced on a real screen — needs a rendered
///     check. That is the snapshot harness (a sibling task), not this file.
///
/// Aesthetic posture (AGENTS.md §6): restrained palette, ONE accent, a real
/// spacing scale, materials over flat fills, considered type, zero emoji.
///
/// Starter template. Build and run before shipping; not yet device-verified.
@available(iOS 17.0, *)
public enum DS {

    // MARK: Colour — semantic, never raw

    /// Semantic colours. Callers use `DS.Color.accent`, never `Color(red:…)` or
    /// a hex literal. Names describe ROLE (accent, surface, separator), not hue,
    /// so a re-skin changes one definition and every screen follows.
    ///
    /// In a shipping app, back these with an Asset Catalog colour set (so light
    /// and dark resolve per the system) and load via `Color("AccentCoral",
    /// bundle: .main)`. The literal RGB seeds below are the *one* sanctioned
    /// place a raw component value may appear — the doctor's hex/RGB rule
    /// whitelists this type by name (see its §6 detector). Everywhere else, a
    /// raw component is a FAIL.
    public enum Color {
        // One accent. The premium coral the kit's §6 aesthetic calls for.
        // invariant: this is the ONLY sanctioned raw-RGB site in the app.
        public static let accent      = SwiftUI.Color(red: 0.93, green: 0.45, blue: 0.38)
        public static let accentMuted = accent.opacity(0.14)

        // Text roles map to the system's adaptive hierarchy (free dark mode,
        // free contrast, free Dynamic Type colours).
        public static let textPrimary   = SwiftUI.Color.primary
        public static let textSecondary = SwiftUI.Color.secondary
        public static let textOnAccent  = SwiftUI.Color.white

        // Surfaces. Prefer materials; these are the flat fallbacks.
        public static let surface   = SwiftUI.Color(.systemBackground)
        public static let surfaceUp  = SwiftUI.Color(.secondarySystemBackground)
        public static let separator = SwiftUI.Color(.separator)
    }

    // MARK: Spacing — an 8pt scale, named by step

    /// The spacing scale. Padding and stack spacing come from here — never a
    /// bare number. An 8pt base with two sub-steps (2, 4) for tight optical
    /// nudges. The doctor flags a numeric literal in `.padding(_:)` /
    /// `spacing:` that is not one of these.
    public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs:  CGFloat = 4
        public static let sm:  CGFloat = 8
        public static let md:  CGFloat = 12
        public static let lg:  CGFloat = 16
        public static let xl:  CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 48
    }

    // MARK: Radius — the corner scale

    /// Corner radii. `.rect(cornerRadius:)` / `RoundedRectangle(cornerRadius:)`
    /// take a token, not a literal. `pill` is sentinel-large for capsule-ish
    /// shapes; prefer `Capsule()` where a true pill is wanted.
    public enum Radius {
        public static let sm:   CGFloat = 8
        public static let md:   CGFloat = 12
        public static let lg:   CGFloat = 18
        public static let xl:   CGFloat = 28
        public static let pill: CGFloat = 999
    }

    // MARK: Typography — the type ramp

    /// The type ramp. Prefer these over `.font(.system(size: 17, …))`: they ride
    /// Dynamic Type by mapping to the system text styles (AGENTS.md §5 — type
    /// must not clip). The doctor flags a raw `.font(.system(size:…))` numeric.
    public enum Font {
        public static let largeTitle = SwiftUI.Font.largeTitle.weight(.semibold)
        public static let title      = SwiftUI.Font.title2.weight(.semibold)
        public static let headline   = SwiftUI.Font.headline
        public static let body       = SwiftUI.Font.body
        public static let callout    = SwiftUI.Font.callout
        public static let caption    = SwiftUI.Font.caption
        // The button label weight, named once so every CTA matches.
        public static let button     = SwiftUI.Font.headline.weight(.semibold)
    }

    // MARK: Motion — the durations, named

    /// Animation timings. Purposeful and brief (AGENTS.md §6: easing, not
    /// bounce). One quick, one standard.
    public enum Motion {
        public static let quick    = Animation.easeOut(duration: 0.18)
        public static let standard = Animation.smooth(duration: 0.28)
    }
}

// MARK: - Composable view modifiers (so a screen never re-derives a surface)

@available(iOS 17.0, *)
public extension View {
    /// The one card surface: material, token radius, hairline stroke. A screen
    /// applies `.dsCard()` instead of hand-rolling `.background(...).overlay(...)`,
    /// so every card is identical by construction.
    func dsCard(radius: CGFloat = DS.Radius.lg) -> some View {
        self
            .background(.ultraThinMaterial, in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(DS.Color.separator.opacity(0.5), lineWidth: 1)
            )
    }

    /// Standard screen gutter. One value for the leading/trailing margin app-wide.
    func dsScreenPadding() -> some View {
        self.padding(.horizontal, DS.Space.lg)
    }
}
