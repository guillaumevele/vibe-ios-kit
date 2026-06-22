# The fixture corpus + golden harness — `device-prove` becomes `fixture-prove`

`FixtureProveTests.swift` proves the **seam** (frames flow, depth presence is
honest). This directory is the **harness layer above it**: a deterministic corpus
of face/skin fixtures, committed **goldens** (recorded expected outputs), and the
`ScanFixtureTests.swift` XCTest that runs the *whole* scan→analysis→result
pipeline on each fixture and asserts the output stays correct within a tolerance
band. That is what turns the human-blocking inner loop —

> "go stand in front of your phone, do a scan, tell me the redness looked right"

— into one an agent runs on every change, headless, in the Simulator:

```bash
xcodebuild test -scheme YourApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:YourAppTests/ScanFixtureTests
```

The real camera is then needed only for a **final acceptance pass** (AGENTS.md
§10/F3), not every iteration.

---

## Directory layout (the contract)

```
Corpus/
  corpus.json                      # the manifest — every fixture the sweep runs
  Goldens/
    neutral_fitz3_front.json       # recorded expected result for one fixture
    ...                            # one golden per fixture you assert numbers on
  <fixtures live in the TEST BUNDLE's resources, not here>
    neutral_fitz2_front.jpg
    neutral_fitz3_front.jpg
    neutral_fitz5_front.jpg
    offaxis_fitz3_front.jpg
    neutral_fitz3_truedepth.heic   # RECORDED RGBD — large, gitignore/LFS it
```

- **`corpus.json`** is the source of truth for the sweep. Adding a fixture is a
  one-line edit here + dropping the image in the test bundle. `fitzpatrick` is not
  decoration: a redness/`a*` metric tuned only on Fitz II–III is a real, shipped
  failure mode — keep at least one fixture per skin-tone band you ship to.
- **`Goldens/<name>.json`** is the recorded `ScanResult` for `<name>`. Committed,
  reviewed, and compared against within bands. `depthDerivedRelief` is `null` for
  every flat-RGB fixture — a non-null relief golden on an RGB fixture is itself a
  bug.
- **The image/HEIC fixtures** belong in the **test bundle's resources** (so they
  ship only with the test target, never the app). `corpus.json` and `Goldens/`
  must also be bundle resources — the harness loads them via `Bundle(for:)`.

Wire these into your test target (Xcode: add `Corpus/` as a folder reference, or
in SwiftPM: `.testTarget(..., resources: [.copy("Corpus")])`).

---

## Capturing a golden ONCE

A golden is the expected output, recorded on a run you trust, then frozen. The
flow:

1. **Get the pipeline green and eyeball it.** Run the fixture through the real
   pipeline once and confirm the result is *actually* right (the redness looks
   right for that face, the capture-quality is plausible). A golden is only as
   good as the run you capture it from.
2. **Harvest the actual result.** Each test attaches its result as
   `XCTAttachment` (`<name>.actual.json`, `lifetime = .keepAlways`). Find it in
   the `.xcresult` bundle (Xcode Report navigator → the test → Attachments, or
   `xcrun xcresulttool`).
3. **Commit it as the golden.** Copy `<name>.actual.json` to
   `Goldens/<name>.json`, sanity-check the numbers, commit. That value is now the
   regression baseline.

> A capture flag (`-FixtureGoldenCapture YES`) is the ergonomic version: branch
> `GoldenStore.load` to *write* the actual result to a known path instead of
> asserting, so re-baselining a whole corpus is one run. Wire it to your needs;
> the attachment path above works with zero extra plumbing.

**Never hand-edit a golden number to make a test pass.** If the result changed,
either it's a real regression (fix the code) or an intended behaviour change
(re-capture deliberately, and say so in the PR). Editing the golden to match a
broken output is the exact dishonesty AGENTS.md §0 bans.

---

## How regressions are detected (and why it's a band, not `==`)

The pipeline's structural facts are asserted **exactly**: a face *is* detected; a
flat fixture's `depthDerivedRelief` *is* `nil`; `sourceKind` *is*
`"fixtureImage"`. No tolerance — these are not noisy.

The pipeline's **ML/float outputs** (capture-quality, redness, depth-derived
relief) are asserted against the golden within a **tolerance band**
(`GoldenStore.qualityTol` etc.). Equality is the wrong tool: `VNDetectFaceCapture`
`QualityRequest` and any Core ML stage drift by tiny floats across OS point
releases and hardware, so `XCTAssertEqual(x, golden)` would flake. A band catches
a *real* drift (a math change, a regressed model) while tolerating sub-threshold
noise. The bands live in **one place** (`GoldenStore`), so widening one is a
visible, reviewable decision — never a silent `accuracy:` bump scattered across
tests.

Three regression nets, layered:

| Test | Catches |
|---|---|
| `test_knownFace_RGBPath_isDeterministicWithinTolerance` | a number drifted past its band vs the committed golden |
| `test_sameFixture_isStableAcrossRuns` | nondeterminism — an unseeded model, a race, a clock leaking into a "measurement" |
| `test_corpusSweep_invariantsHoldForEveryFixture` | a per-fixture invariant broke anywhere in the corpus (no face found; a flat fixture produced a depth number) |
| `test_flatFixture_depthStageDegradesNotCrashes...` | the un-gameable honesty guard: you cannot launder a depth claim out of a flat photo |

---

## What this proves — and what it does NOT

A green `ScanFixtureTests` run is a **real proof token** (AGENTS.md §0, §10/F5)
for the **FAKEABLE** rows (face detection, capture-quality, RGB color/redness) and
— *only if you committed a real RGBD asset* — the **REPLAYABLE** row (depth math).
It exercised the pipeline and asserted output.

It is **not** proof for the **NOT-FAKEABLE** rows. Match the proof to the row
(F5):

- **ARKit face mesh / `ARFaceTrackingConfiguration` / `ARFrame.capturedDepthData`**
  — `ARSession` has no public replay ingress; `capturedDepthData` is get-only and
  `nil` outside a live front-camera face session. **Device gate, period.**
- **Live-sensor timing/illumination** — auto-exposure convergence, the TrueDepth
  IR projector, focus hunting, real-time depth at the user's actual distance.
  **Hardware only.**

A synthetic depth map handed to the depth stage proves *plumbing* ("the code reads
depth and branches"), never a *number* ("the measurement is right"). If you use
one, label it and assert plumbing only.

So the inner loop is: **fixture-prove on every change** (this harness) →
**device-prove once at the end** (a human, a real face, the real camera). The
harness collapses the expensive, human-blocking loop to a final acceptance pass.

---

## APIs the harness relies on (verified vs apple-docs 2026-06-22)

- `VNImageRequestHandler`, `VNDetectFaceRectanglesRequest`,
  `VNDetectFaceCaptureQualityRequest` (`faceCaptureQuality` 0…1) — the FAKEABLE
  vision asserts on a flat `CVPixelBuffer`.
- `AVDepthData.depthDataMap : CVPixelBuffer` — the verified accessor the depth
  metric reads; only reached when a real `AVDepthData` was reconstructed.
- `AVDepthData.init(fromDictionaryRepresentation:)` +
  `CGImageSourceCopyAuxiliaryDataInfoAtIndex(_:_:kCGImageAuxiliaryDataTypeDisparity)`
  — how `FixtureSource` reconstructs REAL depth from a recorded HEIC (the
  REPLAYABLE path).
- `ARFrame.capturedDepthData` — get-only, `nil` off a live face session; named
  here to mark the NOT-FAKEABLE boundary, not used.
- `XCTAttachment` (`lifetime = .keepAlways`) — how the actual result is emitted so
  a golden can be harvested and a CI failure debugged without a device.
```
