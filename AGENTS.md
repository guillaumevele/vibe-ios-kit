# AGENTS.md — iOS / SwiftUI / Metal build posture

Drop this file at the root of an iOS project. `vibe` loads it automatically and
treats it as standing instructions. It encodes the rules that separate a demo
from a shippable, premium iOS app — distilled from a real production build, not
documentation.

The target is **iOS 26/27, Swift 6, SwiftUI, real Metal**, and an aesthetic that
looks intentional. Everything below is a hard rule unless the human overrides it.

---

## 0. Proof, not vibes

- "It compiles" is **not** proof it works. Proof is: a passing test, an
  Instruments trace, a screenshot from a real run, or a device run.
- After any change to a view, animation, or shader: **rebuild and run**, then
  state what you observed. Never claim a visual or performance result you did
  not see.
- If you cannot verify something in this environment, say so explicitly and name
  the gate (e.g. "needs an Xcode build", "needs a device soak"). Do not imply it
  was verified.

## 1. CPU budget — the runaway class (most common production bug)

A single unguarded animation can pin a core and drain the battery. These are
**banned** unless explicitly gated:

- `TimelineView(.animation)` driving work every frame with no stop condition.
- `.repeatForever(autoreverses:)` that is not tied to `isEnabled` / visibility.
- A shader or `Canvas` redraw loop that runs while the view is off-screen or the
  app is backgrounded.

Required guards on any continuous animation or shader:

```swift
// Stop when not visible or app not active.
.onChange(of: scenePhase) { _, phase in isAnimating = (phase == .active) }
.onDisappear { isAnimating = false }
```

Acceptance gate: **3-minute foreground soak with the view on screen → CPU
returns to idle when motion is meant to be at rest.** If CPU stays elevated at
rest, it is a bug, not a polish item.

## 2. Swift 6 strict concurrency

- Assume `-strict-concurrency=complete`. Annotate UI types `@MainActor`.
- Do **not** block the main actor with heavy pixel/image work — hop to a
  background actor or `Task.detached`, return `Sendable` results.
- Never reach for `@unchecked Sendable` to silence the compiler; fix the data
  race. If you genuinely need it, leave a comment explaining the invariant.

## 3. SwiftUI body hygiene

- `body` is pure. **No side effects** in it: no network, no writes, no timers,
  no `print` in hot paths. Side effects go in `.task`, `.onAppear`,
  `.onChange`.
- No allocations per `body` evaluation (no `DateFormatter()`, no gradient or
  shape rebuilt every frame). Hoist to a `let`/`static`.
- Guard `.task` / `.onChange` against loops — a `.task` that mutates state which
  re-triggers the same `.task` is a spin.

## 4. Real Metal, gated

- Shaders via `ShaderLibrary` / the SwiftUI `.colorEffect`, `.distortionEffect`,
  `.layerEffect` modifiers (iOS 17+) or `MTKView` for full control.
- Pass time as a uniform you can **freeze** (set `isEnabled = false` → stop
  feeding `time`), never an unconditional wall clock.
- Keep `.metal` functions branch-light; precompute on the CPU what does not vary
  per pixel.
- Always provide a non-Metal fallback path for previews and reduced-motion.

## 5. Accessibility & reduced motion

- Respect `@Environment(\.accessibilityReduceMotion)` — replace continuous
  motion with a static or crossfade state when it is on.
- Every interactive control has a label. Dynamic Type must not clip.

## 6. Aesthetic — premium, institutional

- **Zero emoji** anywhere in the UI. Use SF Symbols (non-smiley, professional
  weights) for iconography.
- Restrained palette, real spacing scale, one accent. No default-blue-button
  look. Prefer materials (`.ultraThinMaterial`) and considered typography.
- Motion is purposeful and brief — easing, not bounce; reveal, not confetti.

## 7. Editing discipline

- Prefer **surgical edits** to a file that already compiles. When patching a
  known region, use bounded fill-in-the-middle (`vibe-fim`) so the rest of the
  file is provably untouched — see `skills/ios-surgical-edit.md`. Do not
  regenerate a whole working file to change three lines.
- Before recommending an API, verify it exists for the deployment target
  (`apple-docs` / current SDK), do not trust memory for Apple frameworks.

## 8. Definition of done

A change is done when: it builds, it runs, the CPU-at-rest gate passes, reduced
motion is handled, there are no emoji, and you have stated the proof you saw.
