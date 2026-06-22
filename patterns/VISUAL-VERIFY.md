# VISUAL-VERIFY.md — a way for the agent to SEE rendered SwiftUI UI

A premium iOS app has the same structural problem for an agent that a camera
feature does: **the agent cannot see the rendered screen.** It writes a button, it
compiles, and then it has no way to tell whether the button uses the token style,
whether spacing is consistent, whether an emoji crept in, or whether the screen
still matches the design. So it claims "the screen looks right", drifts, loses the
thread on a hard app, and loses work — the exact pain this kit exists to remove.

This is the **visual analogue of `patterns/FIXTURE-CAPTURE.md`**. There, a
`FixtureCaptureSource` lets a camera pipeline run against a bundled frame so the
inner loop needs no human in front of the phone. Here, a **snapshot harness** turns
a SwiftUI view into a PNG on disk so the inner loop is: render → capture → the agent
*reads the image back with its vision tool* → check against the design intent and a
golden. The human eyeball moves to a single final pass, not every iteration.

Every API below was verified against `apple-docs` (and the local SDK / `simctl`) on
2026-06-22; the lookup is named at each row. Nothing here is invented.

---

## 1. The two rendering mechanisms (pick by what you're verifying)

There are two real, verified ways to get a PNG of SwiftUI UI without a human. They
capture **different things** — that distinction is load-bearing, not pedantic.

| Mechanism | What it captures | What it MISSES | Verified API (apple-docs / SDK, 2026-06-22) |
|---|---|---|---|
| **`ImageRenderer`** (templates `VisualSnapshot.swift` / `SnapshotHarness.swift`) — rasterize a view's layer tree to a `UIImage`, write PNG. Runs in `xcodebuild test`, no Simulator boot. | Layout, spacing, color tokens, typography, SF Symbols, **presence of emoji**, light/dark token sets, static composition. | **Live Metal** `.colorEffect`/`.distortionEffect`/`.layerEffect` (bind on the GPU at draw time), **iOS 26 `.glassEffect`** live backdrop refraction, real device `@2x/@3x` rasterization, system blur over real content. | `ImageRenderer` (iOS 16+, "creates images from SwiftUI views"); `.uiImage`/`.cgImage`; `.proposedSize: ProposedViewSize` ("size proposed to the root view"); `.scale` ("ratio of view points to image pixels"). |
| **Simulator screenshot of the RUNNING app** — boot a Simulator, launch the app, navigate, then `xcrun simctl io booted screenshot out.png` (or the XcodeBuildMCP `screenshot` tool / MobAI `get_screenshot`). | The **real composited frame**: live shaders, `.glassEffect`, materials over real scroll content, the actual nav chrome, real device scale. | Determinism — depends on app state, async loads, animation phase; needs a booted Simulator and navigation. | `simctl io <device> screenshot [--type=png] <file>` ("Saves a screenshot as a PNG", local `simctl` help); in a UI test, `XCUIScreen.main.screenshot()` and `XCUIElement.screenshot()` (`XCUIScreenshot`, Xcode 16.3+), attached via `XCTAttachment(screenshot:)`. |

**The one-sentence rule:** use `ImageRenderer` for *static design conformance*
(tokens, spacing, type, no-emoji, light/dark) because it is fast and deterministic
and CI-able; use a **Simulator screenshot of the running app** whenever the thing
under test is a **live shader, `.glassEffect`, or any composited/animated state**,
because `ImageRenderer` does not run those. Claiming a glass/shader screen "looks
right" from an `ImageRenderer` PNG is a lie this table forbids — that PNG never had
the effect in it.

---

## 2. Snapshot rendering — the smallest real mechanism

`ImageRenderer` is the smallest mechanism that needs no Simulator boot. Pin the size
(`proposedSize`) and the scale (`scale`) so the PNG is byte-reproducible run to run:

```swift
let renderer = ImageRenderer(
    content: PrimaryButton(title: "Start analysis") {}
        .frame(width: 390, height: 120)
        .environment(\.colorScheme, .dark)
)
renderer.proposedSize = ProposedViewSize(width: 390, height: 120) // pin layout
renderer.scale = 1.0                                              // pin pixel ratio
let png = renderer.uiImage?.pngData()                            // write to disk
```

The kit ships this as `templates/VisualSnapshot.swift` (`VisualSnapshot.writePNG`)
plus `templates/SnapshotHarness.swift`, an XCTest that renders each component, writes
`<name>.png` to `SNAPSHOT_DIR`, **attaches it to the `.xcresult`**, prints
`SNAPSHOT_WRITTEN name=… path=…` so the agent knows exactly which file to open, and
(if a golden exists) asserts the pixel diff. Run it headless:

```bash
SNAPSHOT_DIR=/tmp/snapshots xcodebuild test -scheme YourApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:YourAppTests/SnapshotHarness
# then the agent opens /tmp/snapshots/primary_button.png with its vision tool
```

For a **live-shader or glass** screen, snapshot the running app instead:

```bash
xcrun simctl io booted screenshot /tmp/snapshots/home_live.png   # real composited frame
```

> **Scale & determinism note (mirror of the Float32 note in `SheenView.swift`):**
> render goldens at `scale = 1.0` so the diff is stable and small; a device renders
> at `@2x`/`@3x`, so a scale-1 golden will *not* pixel-match a device shot. Diff only
> candidates produced by the *same* mechanism. Cross-mechanism comparison is the
> vision-read's job, not the pixel diff's.

---

## 3. The agent verification loop

For any UI change, the inner loop is five steps — and step 4 is the one that is
usually skipped, which is why UI drifts:

```
(a) BUILD the view            – it has to compile; "compiles" is necessary, not sufficient.
(b) SNAPSHOT it               – run SnapshotHarness (ImageRenderer) for static design,
                                or simctl screenshot the running app for shaders/glass.
                                Get a concrete PNG path from SNAPSHOT_WRITTEN=…
(c) READ the PNG BACK         – open that exact file with the vision tool (Claude Code's
                                image read, or the `vision`/Pixtral model). Look at it.
                                Run the §4 checklist against what you SEE, not what you wrote.
(d) DIFF vs golden (optional) – if a committed golden exists, the harness already
                                asserted meanAbsDiff ≤ tolerance. A FAIL is either a
                                regression (fix it) or an intended change (re-bless).
(e) CHECKPOINT                – write one line: what changed, the PNG path, the verdict,
                                and what is still unverified (e.g. "device glass pass owed").
```

The loop's contract: **you may not move to the next todo until you have looked at a
PNG for this one.** A captured-but-unread screenshot is not verification; a model
that "knows" the code is right without reading the image is exactly the drift this
removes.

---

## 4. The pass/fail checklist (what the agent checks in the image)

Read the PNG and answer each, out loud, citing what is visible. Any "no" or "can't
tell" is a FAIL → fix, re-snapshot, re-read. Tie each to the design tokens, not to
taste.

**Tokens & aesthetic (AGENTS.md §6):**
- [ ] **No emoji anywhere.** Iconography is SF Symbols, not emoji. (The single
      highest-value check — a strong model still slips an emoji in.)
- [ ] The **primary action uses the token style** — the project's accent, corner
      radius, and padding, not a default-blue system button.
- [ ] **One accent.** No second competing accent color appeared.
- [ ] Materials/`.ultraThinMaterial` and considered type, not flat default chrome.

**Layout & rhythm:**
- [ ] **Spacing is on the scale** — consistent gaps, aligned edges, no off-by-one
      padding, nothing clipped or overlapping.
- [ ] **Type hierarchy** reads (title vs subtitle vs body distinct; weights sane).
- [ ] **Dynamic Type / dark mode** variant (if snapshotted) is also correct — both
      `card_light` and `card_dark`, not one.

**Intent & regression:**
- [ ] It **matches the stated design intent** for this change (the thing you set out
      to build is what is on screen).
- [ ] If a **golden** exists: `GOLDEN_DIFF … pass=true`. If `pass=false`, decide
      regression vs intended and act — never ignore a failing diff.

State the verdict as `VISUAL_VERIFIED name=<png> pass=<yes/no> notes=<…>`. If you did
not open the PNG, you did not verify it — say so.

---

## 5. Golden images & pixel-diff (regression backstop)

`GoldenDiff.compare` (in `VisualSnapshot.swift`) is a per-channel mean-absolute-diff
with a tolerance, because exact equality is brittle: anti-aliasing and subpixel
rounding shift a handful of edge pixels across SDK point releases, so a 0-tolerance
diff false-fails on a cosmetically identical render. Defaults:

- `tolerance = 0.02` (mean-abs-diff ≈ 5/255) — generous enough for AA noise, tight
  enough to catch a moved element, a changed color token, or a new emoji.
- `perPixelEpsilon = 0.10` drives `changedFraction` (what share of pixels moved
  meaningfully) — useful to distinguish "everything shifted slightly" (AA / a global
  tint change) from "one region changed a lot" (a real element edit).

Workflow: first run prints `GOLDEN_MISSING` and just captures. The agent reads the
PNG, and **only if it passes the §4 checklist** commits it under `Goldens/<name>.png`
as the blessed reference. Thereafter every run asserts against it. An intended visual
change requires a deliberate **re-bless** (delete + recommit the golden) — which puts
a human decision in front of every reference change, the same posture as the camera
fixtures. The pixel diff is the cheap *regression* net; the vision read is the
*conformance* judgment. You need both: the diff catches silent drift the model might
rationalize; the read catches intent the diff is blind to (a diff is happy with a
beautifully-rendered *wrong* screen as long as it doesn't change).

---

## 6. Honest limits (do not overclaim)

This seam removes the human from the *inner* loop. It does not make a final human/
device pass unnecessary, and pretending otherwise is the dishonesty `AGENTS.md §0`
bans.

1. **`ImageRenderer` ≠ on-device rendering.** It rasterizes the layer tree; it does
   **not** run live Metal shaders (`.colorEffect`/`.distortionEffect`/`.layerEffect`)
   or iOS 26 `.glassEffect` backdrop refraction, and it renders at the scale you set,
   not the device's `@2x/@3x`. A glass/shader screen verified only via `ImageRenderer`
   is **not** verified — snapshot the running app for those (§1, row 2).
2. **A model reading a screenshot is a judgment, not a proof.** Vision models miss
   ~1px misalignment, subtle contrast/token mismatches, and sometimes hallucinate
   conformance. Treat `VISUAL_VERIFIED` as *strong evidence*, the pixel diff as a
   *deterministic regression net*, and neither as a substitute for the third leg.
3. **A final real-device visual pass is still wise once.** Run it on the physical
   device before shipping — real glass, real scale, real Dynamic Type, real safe
   areas, motion at speed. Per `AGENTS.md §0` the device run is the proof; the
   snapshot loop is what lets the agent do 20 honest iterations *without* it and
   arrive at that final pass already correct.
4. **Determinism caveats for the running-app path.** A `simctl` screenshot depends on
   app state, async content, and animation phase. Pin them (seed data, await loads,
   freeze the animation clock — the kit already makes shader time a freezable uniform,
   `SheenView.swift`) or the "regression" is just nondeterminism.

The dishonest version of this seam — saying "the screen looks right" without ever
opening the PNG, or diffing a scale-1 golden against a device shot and calling a
scale mismatch a regression — is exactly the failure mode `AGENTS.md §0` and the new
**§11** exist to stop.
