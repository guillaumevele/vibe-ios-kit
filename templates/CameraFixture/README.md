# Camera-fixture seam — turn "stand in front of the phone" into "feed a fixture"

A scan/vision pipeline that reads the live camera can't be verified by an agent:
the simulator has no camera, so every iteration ends in *"go stand in front of
your phone"* and the thread is lost. This template puts a **DEBUG-only seam** in
front of the camera so the same pipeline can consume a **bundled image, a
recorded clip, or a recorded depth still** instead — deterministic,
agent-runnable, no human.

The real camera is then needed only for a **final acceptance pass**, not every
change.

## The shape

```
                 ┌────────────────────────────┐
your scan code → │  any FrameSource            │ → AsyncStream<Frame>
(unchanged)      │   .frames                   │     Frame = (CVPixelBuffer,
                 └────────────┬───────────────┘              AVDepthData?, pts,
                              │                              isFixture)
              ┌───────────────┴───────────────┐
   Release ──▶│ LiveCameraSource              │  AVCaptureSession +
              │  (the ONLY source in Release) │  AVCaptureVideoDataOutput +
              └───────────────────────────────┘  AVCaptureDepthDataOutput,
                                                  time-matched by
   #if DEBUG  ┌───────────────────────────────┐  AVCaptureDataOutputSynchronizer
        ─────▶│ FixtureSource                 │
              │  .image / .clip / .depthStill │
              └───────────────────────────────┘
```

The pipeline depends on `any FrameSource`, never on `AVCaptureSession`. Swapping
the source changes nothing downstream.

## Files

| File | What it is |
|---|---|
| `FrameSource.swift` | The `Frame` struct, the `FrameSource` protocol, and the `#if DEBUG`-gated `FrameSourceKind` + factory. The seam, and the one place the switch lives. |
| `LiveCameraSource.swift` | The real camera. RGB via `AVCaptureVideoDataOutput`; depth via `AVCaptureDepthDataOutput` synced with `AVCaptureDataOutputSynchronizer`. The only source compiled into Release. |
| `FixtureSource.swift` | `#if DEBUG` only. Replays a still / clip / recorded-depth still as the same `Frame` values. |
| `FixtureProveTests.swift` | The agent-runnable "fixture-prove" loop: feed a known face, run the pipeline, assert the output. |

## How the seam stays out of Release

`FrameSourceKind`'s fixture cases and the whole `FixtureSource` are inside
`#if DEBUG`. `FrameSourceFactory.resolved(from:)` returns `.liveCamera` in
Release **regardless of launch arguments**. There is no compile path for a
fixture to reach a shipping build — not a runtime flag you can forget to flip, a
build-configuration boundary.

## Driving a fixture run with no human (deep-link)

`resolved(from:)` reads `UserDefaults`, which Xcode populates from launch
arguments. An agent can deep-link a fixture run with zero code edits:

```bash
# RGB path, in the simulator:
xcrun simctl launch booted com.you.app \
  -FrameSourceFixtureImage face_neutral

# Depth path, from a recorded RGBD HEIC:
xcrun simctl launch booted com.you.app \
  -FrameSourceFixtureDepthStill face_neutral_rgbd.heic
```

Or run `FixtureProveTests` directly via `test_sim` — fully headless.

## What CAN be faked (and is honest)

| Fixture | Drives | Honesty |
|---|---|---|
| **Flat RGB still** (PNG/JPEG/HEIC) | the entire RGB/vision path — colour, redness/`a*`, texture, segmentation, the LLM hand-off | A real image of a real face. `depth == nil`, so the consumer takes the RGB-only branch. |
| **Recorded clip** (.mov/.mp4) | anything time-dependent — motion, blur-over-time, scan-progress, the capture loop's frame cadence | Replayed at the **recorded** PTS, so timing matches the device. RGB only. |
| **Recorded RGBD still** (HEIC/JPEG with embedded disparity/depth) | the **depth path** — TrueDepth/LiDAR-driven geometry, relief, depth-gated segmentation | The depth is reconstructed with `AVDepthData(fromDictionaryRepresentation:)` from aux-data **measured on a real capture**. It is a real `AVDepthData` of the real type, replayed — not invented. |

To make an RGBD fixture: capture a front-camera portrait on a real device (the
HEIC already embeds disparity), or export your own with
`AVDepthData.dictionaryRepresentation(forAuxiliaryDataType:)` +
`CGImageDestinationAddAuxiliaryDataInfo`. Drop it in the test bundle's resources.

## What CANNOT be faked — be honest

- **Depth from a flat photo.** A 2D still has no depth. The seam refuses to
  invent it: a flat-image fixture carries `depth == nil`, full stop. The only
  way to exercise the depth path off-device is a **recorded** RGBD capture. Do
  not generate a depth map from the RGB image and pass it off as sensor depth —
  that would make the depth pipeline pass on data it will never see in
  production.
- **Live AVCaptureSession behaviour.** Auto-exposure, white-balance convergence,
  focus hunting, the TrueDepth IR projector, low-light noise, thermal
  throttling — none of these exist for a fixture. A clip *records* their effect
  at capture time but can't reproduce the live control loop. Capture-quality
  gates (sharpness, exposure, face-distance) must still get a **device pass**.
- **Real-time LiDAR / ARKit scene depth.** `ARFrame.sceneDepth` comes from the
  live sensor; ARKit has no public "replay this recording" input. You can replay
  a serialized `AVDepthData` (above), but a full ARKit world-tracking session is
  device-only.
- **The simulator has no camera at all.** `LiveCameraSource` cannot run there;
  `AVCaptureDevice.default(...)` returns `nil`. Fixtures are the *only* way to
  exercise this pipeline in the simulator.

## The inner loop this buys you

1. Agent edits the scan/analysis code.
2. Agent runs `FixtureProveTests` (or a deep-linked fixture launch) in the
   simulator — **no camera, no human**.
3. Asserts the result is finite / in-range / unchanged vs a golden.
4. Iterate. Only when green does a **human do one real-camera acceptance pass**.

> Honesty (per `AGENTS.md §0`): these are starter templates. They type-check
> against the iOS SDK. That a *specific* fixture decodes, that your pipeline
> accepts `any FrameSource`, and the final real-camera acceptance pass remain
> **your** gate.

## Verified APIs (apple-docs)

All confirmed real and available on iOS via the apple-docs MCP:

- `AVCaptureVideoDataOutputSampleBufferDelegate` — iOS 4.0+
- `AVCaptureDepthDataOutput` — iOS 11.0+
- `AVCaptureDataOutputSynchronizer` / `AVCaptureSynchronizedDepthData` — iOS 11.0+
- `AVDepthData` + `init(fromDictionaryRepresentation:)` /
  `dictionaryRepresentation(forAuxiliaryDataType:)` — iOS 11.0+
- `AVAssetReader` / `AVAssetReaderTrackOutput` — iOS 4.1+
- `CVPixelBufferCreate` / `CVPixelBufferLockBaseAddress` /
  `CVPixelBufferGetBaseAddress` — CoreVideo
- `AVCaptureDevice.authorizationStatus(for:)` — iOS 7.0+
- `ARFrame.sceneDepth` (`ARDepthData`) — iOS 14.0+ (live-only; named to mark the
  boundary, not used by the fixture path)
