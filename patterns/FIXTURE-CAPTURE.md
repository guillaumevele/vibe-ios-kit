# FIXTURE-CAPTURE.md — a debug seam for camera/scan/sensor features

A camera-dependent feature (a skin scan, a document scanner, a face-quality gate)
has one structural problem for an agent: **the iOS Simulator has no camera, and a
flat photo is not a sensor.** The agent cannot stand in front of the phone, so it
keeps blocking on "go run it on your device", loses the thread, and loses work on
a hard app.

The fix is a **`CaptureSource` seam**: a protocol the capture layer reads from,
with a real implementation (`LiveCameraSource`) and a fixture implementation
(`FixtureCaptureSource`) that replays a bundled asset. The agent's inner loop then
runs against the fixture — deterministic, no camera, no human — and the real
camera is needed only for a final acceptance pass.

This file is **honest about what a fixture can and cannot drive** (the §"Fakeable,
replayable, or not" table is the load-bearing part). Every API below was verified
against `apple-docs` on 2026-06-22; the lookup is named at each row.

---

## The seam

One protocol, two implementations, injected at the composition root. The scan and
analysis pipeline depends on the protocol, never on `AVCaptureSession` directly.

```swift
import AVFoundation
import CoreVideo

/// One frame the pipeline can analyze: the color buffer is ALWAYS present; depth
/// is present only when the source actually has it (TrueDepth/LiDAR live, or a
/// recorded RGBD asset). A flat RGB fixture leaves `depth == nil` — and that is
/// the honest signal the pipeline must branch on, never paper over.
struct CapturedFrame: Sendable {
    let color: CVPixelBuffer          // always present
    let depth: AVDepthData?           // nil for a flat-RGB fixture (no real depth)
    let calibration: AVCameraCalibrationData?
    let sourceKind: CaptureSourceKind // .liveCamera, .recordedRGBD, .flatRGBFixture
}

enum CaptureSourceKind: String, Sendable {
    case liveCamera        // real sensor — only here is depth real-time + correlatable
    case recordedRGBD      // replayed HEIC/MOV that carried a real depth aux channel
    case flatRGBFixture    // a plain photo — color only, depth is nil or synthetic
}

protocol CaptureSource: Sendable {
    /// Async stream of frames. Live: from the camera. Fixture: replays the asset
    /// once (still) or at a paced cadence (clip), then finishes.
    func frames() -> AsyncStream<CapturedFrame>
}
```

The composition root picks the implementation. **The selector is the only place
that knows about fixtures**, and it is gated so a fixture can never load in a
Release build (see the AGENTS.md fixture section, rule F7):

```swift
#if DEBUG
enum CaptureSourceFactory {
    static func make() -> CaptureSource {
        if let name = ProcessInfo.processInfo.environment["VERDICT_FIXTURE"] {
            return FixtureCaptureSource(assetNamed: name)   // agent-driven inner loop
        }
        return LiveCameraSource()
    }
}
#else
enum CaptureSourceFactory {
    static func make() -> CaptureSource { LiveCameraSource() }  // fixture path not compiled
}
#endif
```

Why an env var, not a hidden UI toggle: an agent (or an XCTest, or a launch
argument from `xcodebuild test`) can set it without tapping anything, so the same
seam serves the fixture unit test AND a manual simulator run.

---

## Fakeable, replayable, or not — the honest table

This is the part you cannot get wrong. "Feed it a photo" is true for the vision
path and **false** for the depth path, and a skin scan usually touches both.

| Pipeline stage | What it consumes | Fixture posture | Verified API (apple-docs 2026-06-22) |
|---|---|---|---|
| Face / landmark detection, capture-quality gate, redness/RGB color analysis | a single `CGImage` / `CVPixelBuffer` | **FAKEABLE** from a flat RGB photo. No camera. | `VNImageRequestHandler` "processes one or more image-analysis requests pertaining to a single image"; `VNDetectFaceLandmarksRequest`; `VNDetectFaceCaptureQualityRequest` (0…1 quality on a still) |
| Depth / disparity stage (contour, relief, real face-mesh from TrueDepth) | `AVDepthData` | **REPLAYABLE** only from an asset that actually carried depth — a Portrait/TrueDepth HEIC or a recorded depth stream. NOT derivable from a flat photo. | `AVDepthData.init(fromDictionaryRepresentation:)` reads depth "such as that found in an image file" via `CGImageSourceCopyAuxiliaryDataInfoAtIndex(_:_:kCGImageAuxiliaryDataTypeDisparity)` |
| Photo-capture-with-depth (how you RECORD a replayable RGBD fixture in the first place) | `AVCapturePhoto` → `.depthData` | Record once on a real device with `isDepthDataDeliveryEnabled = true`, save the HEIC; thereafter replayable forever as a fixture. | `AVCapturePhoto.depthData` is non-nil only when `isDepthDataDeliveryEnabled` was set; `AVCaptureDepthDataOutput` for streaming |
| ARKit face-tracking experiences (`ARFaceTrackingConfiguration`, blendshapes, the dense front-camera mesh) | live `ARSession` frames | **NOT FAKEABLE / NOT REPLAYABLE.** `ARFrame.capturedDepthData` and `capturedImage` are read-only and "available only in face-based experiences using the device's front TrueDepth camera"; `ARSession` has no public API to play back a recording. This stage is a real-device gate, period. | `ARFrame.capturedDepthData`, `ARFrame.capturedImage` (get-only); `ARSession` (no replay ingress) |
| The sensor itself | the TrueDepth / LiDAR hardware | **NOT FAKEABLE.** Synchronization, perspective-correction, IR illumination, real-time depth at the user's actual distance — only the hardware. | `AVCaptureDevice.DeviceType.builtInTrueDepthCamera` ("two cameras, one Infrared and one YUV … synchronized and perspective corrected") |

**The one-sentence rule:** a flat photo drives everything that is a function of
RGB pixels; a recorded RGBD asset additionally drives the depth math; **nothing
off-device drives ARKit face tracking or the live sensor's timing/illumination.**
If the agent claims a depth result from a flat fixture, that is a lie the table
forbids.

### A synthetic-depth fixture is allowed only if it is LABELLED

You may hand the depth stage a synthetic `AVDepthData` (e.g. a constant plane, or
a coarse depth ramp) to exercise the *plumbing* — that the pipeline reads depth,
branches on its absence, doesn't crash. But a synthetic plane is **not** a face,
so any *numeric* depth result from it is meaningless. Mark it
`sourceKind = .flatRGBFixture` (or a dedicated `.syntheticDepth`) so the
fixture-test asserts plumbing only, never a clinical number. Honesty rule: a
synthetic-depth pass proves "the code runs", not "the measurement is right".

---

## The two fixture implementations

### Still RGB fixture (drives the vision path)

Loads a bundled `.jpg`/`.heic`, vends one `CapturedFrame` with `depth = nil`.

```swift
#if DEBUG
import ImageIO
import VideoToolbox

struct FixtureCaptureSource: CaptureSource {
    let assetNamed: String
    func frames() -> AsyncStream<CapturedFrame> {
        AsyncStream { cont in
            guard let url = Bundle.main.url(forResource: assetNamed, withExtension: nil),
                  let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg  = CGImageSourceCreateImageAtIndex(src, 0, nil),
                  let pb  = cg.toPixelBuffer() else { cont.finish(); return }

            // Try to recover a REAL depth aux channel if the asset carries one
            // (a Portrait/TrueDepth HEIC). A flat photo returns nil here — honest.
            let depth = AVDepthData.fromDisparityAux(in: src)   // see helper below

            cont.yield(CapturedFrame(
                color: pb, depth: depth, calibration: depth?.cameraCalibrationData,
                sourceKind: depth == nil ? .flatRGBFixture : .recordedRGBD))
            cont.finish()
        }
    }
}

extension AVDepthData {
    /// Reconstruct AVDepthData from a file's disparity aux channel, if present.
    /// Verified: AVDepthData.init(fromDictionaryRepresentation:) +
    /// CGImageSourceCopyAuxiliaryDataInfoAtIndex (apple-docs 2026-06-22).
    static func fromDisparityAux(in src: CGImageSource) -> AVDepthData? {
        guard let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(
            src, 0, kCGImageAuxiliaryDataTypeDisparity) as? [AnyHashable: Any] else { return nil }
        return try? AVDepthData(fromDictionaryRepresentation: info)
    }
}
#endif
```

`cg.toPixelBuffer()` is a small `CVPixelBuffer`-from-`CGImage` helper
(`VTCreateCGImageFromCVPixelBuffer`'s inverse via `CVPixelBufferCreate` +
`CGContext`); keep it in the same `#if DEBUG` file.

### Recorded RGBD clip fixture (drives the depth path honestly)

If you recorded a TrueDepth selfie HEIC (or a depth-carrying `.mov`) on a real
device once, replay it the same way — `fromDisparityAux` returns real
`AVDepthData`, `sourceKind` becomes `.recordedRGBD`, and the depth stage runs on
real numbers without a camera. **This is the only way to fixture-prove the depth
math.** Record it once, commit it as a test asset, and the depth inner loop is
agent-runnable forever after.

---

## The fixture test harness (the agent's actual inner loop)

A plain XCTest that runs the *whole* scan→analysis→result path against a fixture
and asserts on the structured output. This is what replaces "go stand in front of
your phone".

```swift
import XCTest
@testable import Verdict

final class ScanFixtureTests: XCTestCase {
    /// FAKEABLE path: a known face photo drives detection + RGB analysis to a
    /// deterministic result. No camera. Runs on the Simulator in CI.
    func test_knownFace_producesRednessScore() async throws {
        let source = FixtureCaptureSource(assetNamed: "face_fixture_neutral.jpg")
        let result = try await ScanPipeline(source: source).run()

        XCTAssertEqual(result.sourceKind, .flatRGBFixture)
        XCTAssertNotNil(result.faceObservation, "face must be detected in the fixture")
        XCTAssertGreaterThan(result.captureQuality, 0.5)
        // Deterministic on a fixed asset -> a golden value, tolerance for float drift.
        XCTAssertEqual(result.redness, 0.42, accuracy: 0.01)
    }

    /// Honesty guard: a flat fixture has NO depth, so the depth stage must degrade
    /// gracefully, not crash and not invent a number.
    func test_flatFixture_depthStageDegradesNotCrashes() async throws {
        let source = FixtureCaptureSource(assetNamed: "face_fixture_neutral.jpg")
        let result = try await ScanPipeline(source: source).run()
        XCTAssertNil(result.depthDerivedRelief, "no depth in a flat photo -> no relief number")
    }

    /// REPLAYABLE path (only if you committed a real RGBD asset):
    func test_recordedRGBD_producesReliefScore() async throws {
        let source = FixtureCaptureSource(assetNamed: "face_fixture_truedepth.heic")
        let result = try await ScanPipeline(source: source).run()
        XCTAssertEqual(result.sourceKind, .recordedRGBD)
        XCTAssertNotNil(result.depthDerivedRelief)
    }
}
```

Run it headless — no camera, deterministic, CI-able:

```bash
xcodebuild test -scheme Verdict \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:VerdictTests/ScanFixtureTests
```

A green run here is a **real proof** under AGENTS.md §0 — a test that exercised
the pipeline and asserted output — for everything in the FAKEABLE / REPLAYABLE
rows. It is **not** proof for the NOT-FAKEABLE rows (ARKit face mesh, live sensor
timing/illumination); those still need the device acceptance pass.

---

## Where the corpus already does this

The seam is the capture analogue of two patterns the kit already documents:

- **FoundationModels availability as product state** (`PATTERNS.md`): branch the
  whole view on a runtime capability rather than assume it. Here, branch the whole
  pipeline on `sourceKind` / `depth == nil` rather than assume depth exists.
- **Freezable Metal uniform** (`AGENTS.md §4`, `SheenView.swift`): a value you can
  substitute deterministically (a frozen `time`, here a fixture frame) so the
  thing is testable without the live driver.

The dishonest version of this seam — synthesizing a depth map from a flat photo
and reporting a relief score from it — is exactly the failure `AGENTS.md §0` bans:
claiming a result you did not measure.
