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

A single unguarded animation can pin a core and drain the battery. This is the
**single most-violated rule in real code**: across 36 `TimelineView` shader files
mined from 67 production sample projects, exactly **1** used `scenePhase`, **0**
used `isLowPowerModeEnabled`, **0** used `accessibilityReduceMotion`
(see `PATTERNS.md`). These are **banned** unless explicitly gated:

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
- Provide a **frozen-uniform or non-Metal fallback** for previews and reduced
  motion: feeding a constant `time` freezes the effect with zero per-frame work,
  which satisfies §5's "static state" without a second code path.

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

## 9. On-device AI & iOS 26 system UI (corpus-validated)

Non-negotiables distilled from 67 real projects. Deeper, attributed techniques
with examples live in **`PATTERNS.md`** — consult it before building any of these.

- **FoundationModels is the privacy-aligned default.** Inference stays on-device;
  treat `SystemLanguageModel.default.availability` as a *product state* (branch
  the whole view to a `ContentUnavailableView` per `.unavailable` reason, with an
  `@unknown default`), re-read it (it changes at runtime). **Never** silently fall
  back to a server LLM or Private Cloud Compute — any off-device escalation is an
  explicit, labelled user opt-in. For structured output use `@Generable` with
  **closed enums** so the model cannot invent categories. Streaming snapshots are
  **cumulative** — `output = snap.content` (assign, never append). Trust the SDK
  spelling (`@Guide(description:)` on a property, `call(arguments:)`), not the
  bundled SKILL.md tutorials, which ship stale forms that do not compile.
- **iOS 26 glass is native and cheap.** Use `.glassEffect(.regular, in:)` in a
  `GlassEffectContainer`; never hand-roll fake glass via per-frame snapshot + blur
  over scrolling content (the canonical material-over-scroll trap). Ship a pre-26
  fallback behind `if #available(iOS 26)`. Keep glass on small surfaces only.
- **Scroll/size reads:** prefer `onScrollGeometryChange` / `onGeometryChange`
  (change-driven) over `GeometryReader` + `PreferenceKey` (frame-driven). Return a
  `Bool` for crossing detection so work fires once, not every frame.
- **Drag against a ScrollView:** bridge `UIGestureRecognizerRepresentable` + a
  delegate — a SwiftUI `DragGesture` silently drops `.onEnded` when it loses the
  gesture race, the root cause of stuck mid-dismiss animations.
- **Stitchable shaders fail SILENTLY** (name-resolved at runtime): a typo or
  arg-count mismatch yields a blank layer with no error. Pass `size` explicitly to
  `.colorEffect`; pick the right entry point (`colorEffect` / `distortionEffect` /
  `layerEffect`). Verify the effect visually, never assume it bound.
- **Let the platform own the hard parts:** `SubscriptionStoreView` for paywalls
  (verify `VerificationResult` before unlocking); `Text(timerInterval:)` for Live
  Activity time (advances natively at zero CPU — never a per-second update loop);
  keep the native `TabView` and overlay custom chrome rather than hand-rolling.

## 10. Camera / scan / sensor features — fixture-prove, don't beg for a face

The single most-lost thread on a camera app: the Simulator has no camera, a flat
photo is not a sensor, so the agent keeps saying **"go stand in front of your
phone"**, blocks, and loses work. That is banned. Put a **debug capture seam** in
the pipeline (a `CaptureSource` protocol with a `FixtureCaptureSource`) so the
inner loop runs against a bundled fixture — deterministic, no camera, no human —
and reserve the real camera for ONE final acceptance pass. The full seam, the
honest fakeable/replayable/not table, and the test harness are in
**`patterns/FIXTURE-CAPTURE.md`** — read it before building any capture feature.

The hard rules:

- **F1 — Inner loop = fixture, never the human.** For any camera/scan/sensor
  feature, drive iteration through `FixtureCaptureSource` + the fixture XCTest
  harness on the **Simulator** (the owner's stack: `xcodebuild test` /
  XcodeBuildMCP). NEVER ask the human to run a scan to check your own work in
  progress. If you catch yourself about to write "stand in front of the phone"
  mid-iteration, stop and write a fixture test instead.

- **F2 — Be honest about what a fixture can drive (the table is law).** A flat RGB
  photo drives the **vision path only** (`VNImageRequestHandler` and friends — face
  detection, capture-quality, RGB/redness). The **depth path** needs a *recorded
  RGBD asset* replayed (`AVDepthData(fromDictionaryRepresentation:)` from a HEIC's
  disparity aux channel) — it is NOT derivable from a flat photo. **ARKit face
  tracking and the live TrueDepth/LiDAR sensor are NOT fakeable at all.** Never
  report a depth/relief/mesh number from a flat fixture; that is a §0 violation.
  Synthetic depth is allowed only to prove plumbing, and only when labelled as
  such — it never yields a clinical number.

- **F3 — Real camera = ONE acceptance pass, asked once, with a checklist.** The
  real device is the LAST gate, not the inner loop. When the fixture loop is green,
  ask the human a single time, via MobAI on the real iPhone, with an explicit
  checklist of exactly what only the sensor can prove, e.g.:
  - [ ] Live scan completes on the real TrueDepth camera (no fixture).
  - [ ] Depth-derived result (relief/mesh) is plausible on a real face at arm's length.
  - [ ] Capture-quality gate behaves under real lighting (bright / dim / backlit).
  - [ ] 3-minute on-device idle-CPU soak passes (AGENTS.md §1) during/after scan.

  One ask, one checklist — not a stream of "try it now?" interruptions.

- **F4 — Small fixture-proved steps, each with a written checkpoint.** Structure
  the work so a lost thread loses ONE step, not the session. After each step:
  (1) state which fixture test now passes, (2) write a one-line checkpoint —
  `done: <step>; proof: <test/result>; next: <step>` — to the PR/scratch notes.
  A fresh session resumes from the last checkpoint, not from zero. (Pairs with the
  surgical-edit discipline §7: small bounded edits, each independently proved.)

- **F5 — No "scan works" claim without a proof token.** You may only say a scan or
  capture feature works if you attach one of: a **fixture-test run** (names the
  test + the asserted output) for the fakeable/replayable rows, OR a **stated
  real-device acceptance** (the human confirmed the F3 checklist) for the
  not-fakeable rows. "It builds" / "it should work" is not a proof token (§0).
  Match the proof to the row: a fixture test does NOT prove the ARKit/sensor path.

- **F6 — Branch on capability, don't assume it.** The pipeline reads `sourceKind`
  / `depth == nil` and degrades honestly when depth is absent (same posture as the
  FoundationModels availability gate in §9): a missing-depth path is a normal
  product state to handle, not a crash and not a silently-faked number.

- **F7 — The fixture seam never ships.** Gate `FixtureCaptureSource` and its
  selector behind `#if DEBUG`; the Release composition root compiles only
  `LiveCameraSource`. A fixture must be impossible to load in a shipped build.

## 11. Rendered UI — snapshot and SEE it, don't claim it looks right

The visual analogue of §10. You cannot see the running app, so for a premium UI you
keep *saying* a screen "looks right" without ever looking — and the design drifts:
a default-blue button slips in, spacing goes off-scale, an emoji appears, a token
changes. On a hard app this is where the thread and the work get lost. The fix is a
**snapshot seam**: render the view to a PNG, then **read that PNG back with your
vision tool** and check it. The full mechanism, the verified-API table, the loop and
the checklist are in **`patterns/VISUAL-VERIFY.md`** (kit templates
`VisualSnapshot.swift` + `SnapshotHarness.swift`) — read it before any UI change.

The hard rules:

- **V1 — Every UI change runs the five-step loop.** (a) build the view, (b) snapshot
  it (`SnapshotHarness` via `ImageRenderer` for static design; `simctl io booted
  screenshot` / a `XCUIScreen.screenshot()` UI test for live shaders & `.glassEffect`),
  (c) **read the PNG back with the vision tool and run the §4 checklist on what you
  SEE**, (d) diff against the golden if one exists, (e) write a checkpoint. "Compiles"
  is step (a) only — necessary, never sufficient (§0).

- **V2 — Never claim a screen looks right without a captured screenshot you actually
  opened.** A captured-but-unread PNG is not verification. State the verdict as
  `VISUAL_VERIFIED name=<png> pass=<yes/no> notes=<…>`; if you did not open the
  image, say "unverified — owed a visual read", do not imply you saw it.

- **V3 — Match the mechanism to what you're verifying.** `ImageRenderer` rasterizes
  the layer tree: it captures layout / spacing / color tokens / type / SF Symbols /
  emoji / light+dark, and it is fast and CI-able. It does **NOT** run live Metal
  shaders or iOS 26 `.glassEffect` refraction, and it renders at the scale you set,
  not device `@2x/@3x`. Verifying a glass/shader screen via `ImageRenderer` is a §0
  lie — that PNG never had the effect in it. Snapshot the *running app* for those.

- **V4 — The no-emoji + token check is mandatory on every snapshot.** Read the image
  and confirm: no emoji; the primary action uses the token style (accent / corner /
  padding), not default-blue; one accent; spacing on the scale; nothing clipped.
  These are §6 made checkable — a strong model still slips an emoji or a stock button
  in, and only looking at the pixels catches it.

- **V5 — Goldens are a regression net, blessed by a human-grade decision.** Commit a
  reference PNG under `Goldens/<name>.png` only AFTER it passed the §4 read. The
  harness then asserts `GoldenDiff` mean-abs-diff ≤ tolerance (default 0.02, AA-tolerant)
  on every run. A failing diff is a regression to fix OR an intended change to
  **re-bless** (delete + recommit) — never silently ignored. Diff only same-mechanism,
  same-scale candidates; a scale-1 golden vs a device shot is a mismatch, not a bug.

- **V6 — Small verified steps, each with a written checkpoint** (mirrors §10 F4, ties
  to the lost-thread pain). One component, one snapshot, one read, one checkpoint
  line — `done: <view>; proof: <png + VISUAL_VERIFIED/GOLDEN_DIFF>; next: <view>` —
  in the PR/scratch notes. A fresh session resumes from the last verified screen, not
  from zero. Pairs with surgical edits (§7): bounded change, captured proof.

- **V7 — Honest limits, stated, not papered over.** `ImageRenderer` ≠ on-device
  rendering; a model reading a screenshot is a judgment, not a proof; the running-app
  screenshot is only as deterministic as the app state you pinned. So a **final
  real-device visual pass is still wise once** before shipping (real glass, real
  scale, Dynamic Type, safe areas, motion at speed) — asked once, per §10 F3 style.
  The snapshot loop is what lets you reach that pass already correct after many honest
  iterations; it does not replace it.
