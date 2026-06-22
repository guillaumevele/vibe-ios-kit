import SwiftUI

/// Applies the `sheen` Metal color effect to any content, with the animation
/// clock GATED so the GPU is idle at rest:
///
/// - drives `TimelineView(.animation)` only while the view is on screen AND the
///   scene is `.active`,
/// - freezes to a static frame when off screen, inactive, or when Reduce Motion
///   is on (a frozen-frame fallback — the shader runs with a constant uniform,
///   so there is zero per-frame work).
///
/// This is the gated pattern AGENTS.md §1 / §4 require — an ungated
/// `TimelineView(.animation)` would keep the GPU busy off-screen.
///
/// The clock is ELAPSED seconds since the view appeared, not the absolute
/// reference date: at ~7.9e8 s (a 2026 absolute timestamp) a Float32 uniform has
/// a ~64 s quantum, so `time` could not change between 60fps frames and the
/// sheen would be frozen, not smooth. Elapsed seconds stay small and precise.
///
/// Starter template. Build and run before shipping; not yet device-verified.
@available(iOS 17.0, *)
struct SheenView<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var start = Date()

    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    private var animating: Bool { isVisible && scenePhase == .active && !reduceMotion }

    var body: some View {
        Group {
            if animating {
                TimelineView(.animation) { timeline in
                    content.modifier(
                        Sheen(time: timeline.date.timeIntervalSince(start))
                    )
                }
            } else {
                content.modifier(Sheen(time: 0))   // frozen frame — no per-frame work
            }
        }
        .onAppear { isVisible = true; start = Date() }
        .onDisappear { isVisible = false }
    }
}

@available(iOS 17.0, *)
private struct Sheen: ViewModifier {
    let time: TimeInterval

    func body(content: Content) -> some View {
        content.visualEffect { effect, proxy in
            effect.colorEffect(
                ShaderLibrary.sheen(.float2(proxy.size), .float(time))
            )
        }
    }
}
