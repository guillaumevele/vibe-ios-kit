import SwiftUI

/// Applies the `sheen` Metal color effect to any content, with the animation
/// clock GATED so the GPU is idle at rest:
///
/// - drives `TimelineView(.animation)` only while the scene is `.active`,
/// - freezes to a static frame when inactive or when Reduce Motion is on.
///
/// This is the gated pattern AGENTS.md §1 / §4 require — an ungated
/// `TimelineView(.animation)` would keep the GPU busy off-screen.
///
/// Starter template. Build and run before shipping; not yet device-verified.
@available(iOS 17.0, *)
struct SheenView<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    private var animating: Bool { scenePhase == .active && !reduceMotion }

    var body: some View {
        if animating {
            TimelineView(.animation) { timeline in
                content.modifier(
                    Sheen(time: timeline.date.timeIntervalSinceReferenceDate)
                )
            }
        } else {
            content.modifier(Sheen(time: 0))   // frozen frame — no per-frame work
        }
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
