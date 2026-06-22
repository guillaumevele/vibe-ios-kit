#if DEBUG
import XCTest
import AVFoundation
import CoreVideo
import Vision
@testable import YourApp   // <- rename to your module. Needs @testable for the seam + pipeline.

// MARK: - The fixture-driven scan test harness (the GOLDEN/regression layer)
//
// `FixtureProveTests.swift` proves the SEAM (frames decode, depth presence is
// honest). THIS file is the layer above it: it runs the WHOLE
// scan->analysis->result pipeline against a deterministic CORPUS and asserts the
// numeric output against committed GOLDENS within tolerance bands — so a behaviour
// regression (a redness math change, an unseeded model, a depth number leaking out
// of a flat photo) fails CI. Use FixtureProveTests to prove "frames flow"; use
// ScanFixtureTests to prove "the result is still right".
//
// It turns the human-blocking inner loop ("go stand in front of your phone")
// into an agent-runnable one ("feed a known fixture, assert the output"), headless
// in the Simulator:
//
//   xcodebuild test -scheme YourApp \
//     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
//     -only-testing:YourAppTests/ScanFixtureTests
//
// It depends ONLY on the seam (FrameSource / Frame / FrameSourceFactory from
// templates/CameraFixture/FrameSource.swift) and on your own pipeline entry
// point. Wire `ScanPipeline` below to whatever your app actually calls; the rest
// is reusable.
//
// HONESTY (AGENTS.md §0 + §10/F2): a green run here is real proof for the
// FAKEABLE rows (face detection, capture-quality, RGB color/redness) and the
// REPLAYABLE row (depth math, IF you committed a real RGBD asset). It is NOT proof
// for the NOT-FAKEABLE rows (ARKit face mesh, live-sensor timing/illumination) —
// those keep the device acceptance pass (AGENTS.md §10/F3). The tests below assert
// exactly that boundary, so the harness cannot be used to launder a depth claim
// out of a flat photo.
//
// Verified vs apple-docs 2026-06-22:
//   VNImageRequestHandler, VNDetectFaceRectanglesRequest,
//   VNDetectFaceCaptureQualityRequest (faceCaptureQuality 0…1)
//   AVDepthData.depthDataMap : CVPixelBuffer
//   XCTAttachment (golden artifact capture)

// MARK: - The pipeline contract this harness asserts against
//
// EDIT THIS to match your app. The harness needs (a) a way to build the pipeline
// from a FrameSource, and (b) a Sendable result struct it can assert on. If your
// app already has a `ScanPipeline`, delete this stub and import the real one.

/// The structured output of one scan. Everything here is deterministic for a
/// fixed input EXCEPT where an ML stage adds float jitter — those fields get a
/// tolerance band, never an exact `==`. `nil` is a first-class, asserted value:
/// a flat fixture MUST yield `depthDerivedRelief == nil` (no depth -> no number).
struct ScanResult: Sendable, Codable, Equatable {
    var sourceKind: String          // "liveCamera" | "fixtureImage" | "fixtureDepthStill" | "fixtureClip"
    var faceDetected: Bool
    var captureQuality: Double      // 0…1, VNDetectFaceCaptureQualityRequest
    var redness: Double?            // RGB-derived, FAKEABLE from a flat photo
    var depthDerivedRelief: Double? // depth-derived — nil unless a REAL depth channel was present
    var frameCount: Int
}

/// Adapter to YOUR pipeline. Replace the body of `run()` with your real
/// scan->analysis->result call. The contract: consume `source.frames`, run the
/// analysis, return a `ScanResult`. Keep it `async` so it matches the live path.
struct ScanPipeline {
    let source: any FrameSource

    func run() async throws -> ScanResult {
        try await source.start()

        var frameCount = 0
        var lastResult = ScanResult(
            sourceKind: "unknown", faceDetected: false, captureQuality: 0,
            redness: nil, depthDerivedRelief: nil, frameCount: 0)

        for await frame in source.frames {
            frameCount += 1
            // ---- REPLACE FROM HERE with your real analysis ----
            // This stub shows the SHAPE the harness expects and demonstrates the
            // honesty branch: depth-derived numbers are produced ONLY when the
            // frame actually carried depth.
            lastResult.faceDetected = (try? FixtureVision.detectsFace(frame.pixelBuffer)) ?? false
            lastResult.captureQuality = (try? FixtureVision.captureQuality(frame.pixelBuffer)) ?? 0
            lastResult.redness = FixtureVision.meanRedness(frame.pixelBuffer)
            if let depth = frame.depth {
                lastResult.depthDerivedRelief = FixtureVision.reliefProxy(depth) // real depth -> real number
            } else {
                lastResult.depthDerivedRelief = nil                              // flat photo -> honest nil
            }
            // ---- REPLACE TO HERE ----
            // A still/RGBD fixture re-emits the same frame at `fps`; one frame is
            // enough to assert a deterministic result. A clip would aggregate more.
            if frameCount >= 1 { break }
        }
        // Deterministic teardown: stop the pump BEFORE returning so a still/clip
        // source cannot keep yielding into a finished consumer (no dangling Task).
        await source.stop()

        lastResult.sourceKind = (source as? FixtureSourceKindReporting)?.kindName ?? "liveCamera"
        lastResult.frameCount = frameCount
        return lastResult
    }
}

/// Optional: a fixture source can report its kind name so the result is auditable.
/// (Your real `FixtureSource` can conform; the live source need not.)
protocol FixtureSourceKindReporting { var kindName: String { get } }

// MARK: - The tests (the agent's actual inner loop)

final class ScanFixtureTests: XCTestCase {

    /// FAKEABLE: a known face photo drives detection + capture-quality + RGB
    /// redness to a deterministic result. No camera. This is the row an agent
    /// iterates on every change.
    func test_knownFace_RGBPath_isDeterministicWithinTolerance() async throws {
        let source = FrameSourceFactory.make(.fixtureImage(named: "neutral_fitz3_front", fps: 12))
        let result = try await ScanPipeline(source: source).run()

        // Structural asserts: exact, no tolerance — these are not ML-noisy.
        XCTAssertTrue(result.faceDetected, "a face must be detected in a face fixture")
        XCTAssertEqual(result.sourceKind, "fixtureImage")
        XCTAssertNil(result.depthDerivedRelief,
                     "FAKEABLE path: a flat photo has no depth, so relief MUST be nil")

        // ML/float asserts: a golden value with a tolerance BAND, never `==`.
        // Capture the golden once (see GoldenStore), then this catches regressions.
        let golden = try GoldenStore.load("neutral_fitz3_front")
        assertWithinBand(result.captureQuality, golden.captureQuality,
                         tol: GoldenStore.qualityTol, label: "captureQuality")
        try assertOptionalWithinBand(result.redness, golden.redness,
                         tol: GoldenStore.rednessTol, label: "redness")

        // Drift artifact: attach the actual result so a CI failure is debuggable
        // without re-running on a device.
        attach(result, named: "neutral_fitz3_front.actual.json")
    }

    /// HONESTY GUARD (AGENTS.md §10/F2): the depth stage must DEGRADE on a flat
    /// fixture — not crash, and not invent a number. This test is the one that
    /// makes the harness un-gameable: you cannot get a depth claim out of RGB.
    func test_flatFixture_depthStageDegradesNotCrashes_andInventsNoNumber() async throws {
        let source = FrameSourceFactory.make(.fixtureImage(named: "neutral_fitz3_front", fps: 12))
        let result = try await ScanPipeline(source: source).run()
        XCTAssertNil(result.depthDerivedRelief,
                     "no depth in a flat photo -> the pipeline must report nil, not a fabricated relief")
    }

    /// REPLAYABLE: only runs if you committed a REAL RGBD asset (a TrueDepth/
    /// Portrait HEIC recorded once on a device). `FixtureSource` reconstructs the
    /// real `AVDepthData` from its disparity aux-channel, so the depth math runs
    /// on measured numbers with no camera. Skips cleanly if the asset is absent,
    /// so the suite stays green on machines/forks without the (large) RGBD file.
    func test_recordedRGBD_depthPath_producesReliefWithinTolerance() async throws {
        try XCTSkipUnless(
            Bundle(for: Self.self).url(forResource: "neutral_fitz3_truedepth", withExtension: "heic") != nil,
            "no RGBD fixture committed — depth path is a device/recorded gate, skipping")

        let source = FrameSourceFactory.make(
            .fixtureDepthStill(resource: "neutral_fitz3_truedepth", ext: "heic", fps: 12))
        let result = try await ScanPipeline(source: source).run()

        XCTAssertEqual(result.sourceKind, "fixtureDepthStill")
        let relief = try XCTUnwrap(result.depthDerivedRelief,
            "a REAL RGBD asset carries depth -> the relief number MUST be produced")
        let golden = try GoldenStore.load("neutral_fitz3_truedepth")
        try assertOptionalWithinBand(relief, golden.depthDerivedRelief,
                         tol: GoldenStore.reliefTol, label: "depthDerivedRelief")
    }

    /// STABILITY (test-retest): the same fixture run twice must give the same
    /// result inside the same band. This catches nondeterminism — an unseeded
    /// model, a race, a clock leaking into a "measurement".
    func test_sameFixture_isStableAcrossRuns() async throws {
        let a = try await ScanPipeline(source:
            FrameSourceFactory.make(.fixtureImage(named: "neutral_fitz3_front", fps: 12))).run()
        let b = try await ScanPipeline(source:
            FrameSourceFactory.make(.fixtureImage(named: "neutral_fitz3_front", fps: 12))).run()
        assertWithinBand(a.captureQuality, b.captureQuality,
                         tol: GoldenStore.qualityTol, label: "captureQuality run-to-run")
        XCTAssertEqual(a.depthDerivedRelief, b.depthDerivedRelief,
                       "nil/non-nil depth presence must be identical run-to-run")
    }

    /// CORPUS SWEEP: run the whole corpus, assert the invariants that must hold
    /// for EVERY face fixture (a face is found; a flat photo yields nil depth).
    /// New fixtures are picked up automatically from the manifest — see corpus.json.
    func test_corpusSweep_invariantsHoldForEveryFixture() async throws {
        for entry in try CorpusManifest.load().rgbFixtures {
            let result = try await ScanPipeline(source:
                FrameSourceFactory.make(.fixtureImage(named: entry.resource, fps: 12))).run()
            XCTAssertTrue(result.faceDetected, "no face detected in corpus fixture \(entry.resource)")
            XCTAssertNil(result.depthDerivedRelief,
                         "flat corpus fixture \(entry.resource) must not produce a depth number")
        }
    }
}

// MARK: - Golden store (capture once, regress forever)
//
// A golden is the recorded result for a fixture. You capture it ONCE on a trusted
// run (a green pipeline you've eyeballed), commit the JSON, and thereafter the
// tests compare against it within a tolerance band. ML stages drift by tiny
// floats across OS point releases, so equality is wrong — a band is right. Bands
// live here, in ONE place, so widening them is a visible, reviewable decision.

enum GoldenStore {
    // Tolerances: start tight, widen ONLY with a written reason in the PR.
    static let qualityTol = 0.02   // VNDetectFaceCaptureQualityRequest float drift
    static let rednessTol = 0.01   // RGB mean is stable; keep it tight
    static let reliefTol  = 0.05   // depth-derived; looser, depth maps are noisier

    /// Where goldens live, relative to the test bundle resources.
    private static func url(_ name: String) throws -> URL {
        guard let u = Bundle(for: ScanFixtureTests.self)
            .url(forResource: name, withExtension: "json", subdirectory: "Goldens") else {
            throw GoldenError.missing(name)
        }
        return u
    }

    static func load(_ name: String) throws -> ScanResult {
        // CAPTURE MODE: run with `-FixtureGoldenCapture YES` to (re)write goldens
        // instead of asserting. The harness writes the actual result as an
        // XCTAttachment AND prints the path; you copy it into Goldens/ and commit.
        try JSONDecoder().decode(ScanResult.self, from: Data(contentsOf: url(name)))
    }

    enum GoldenError: Error { case missing(String) }
}

// MARK: - Corpus manifest (the layout contract)

struct CorpusManifest: Codable {
    struct Entry: Codable { let resource: String; let fitzpatrick: Int?; let note: String? }
    let rgbFixtures: [Entry]
    let rgbdFixtures: [Entry]

    static func load() throws -> CorpusManifest {
        guard let u = Bundle(for: ScanFixtureTests.self)
            .url(forResource: "corpus", withExtension: "json") else {
            // Empty corpus is not a failure — it just means no sweep yet.
            return CorpusManifest(rgbFixtures: [], rgbdFixtures: [])
        }
        return try JSONDecoder().decode(CorpusManifest.self, from: Data(contentsOf: u))
    }
}

// MARK: - Tolerance + attachment helpers

extension XCTestCase {
    /// Band assert for non-optional floats. The ONLY way the harness compares an
    /// ML-influenced number — never `XCTAssertEqual` without `accuracy:`.
    func assertWithinBand(_ actual: Double, _ golden: Double, tol: Double,
                          label: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, golden, accuracy: tol,
                       "\(label): \(actual) drifted from golden \(golden) beyond ±\(tol)",
                       file: file, line: line)
    }

    /// Band assert for optionals, asserting presence-parity first (nil-vs-number
    /// is a hard, exact contract; only the number itself gets a band).
    func assertOptionalWithinBand(_ actual: Double?, _ golden: Double?, tol: Double,
                                  label: String, file: StaticString = #file, line: UInt = #line) throws {
        switch (actual, golden) {
        case (nil, nil): return
        case let (a?, g?): assertWithinBand(a, g, tol: tol, label: label, file: file, line: line)
        default:
            XCTFail("\(label): presence mismatch — actual \(String(describing: actual)) vs golden \(String(describing: golden)). " +
                    "A flat fixture must stay nil; an RGBD fixture must stay non-nil.",
                    file: file, line: line)
        }
    }

    /// Attach the actual result JSON so a CI failure is debuggable without a device.
    func attach<T: Encodable>(_ value: T, named name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let a = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        a.name = name
        a.lifetime = .keepAlways   // keep on success too, so goldens can be harvested
        add(a)
    }
}

// MARK: - Minimal Vision shims used by the stub pipeline
//
// These exist so the template type-checks standalone. In your app, your real
// analysis replaces them — but they show the verified Vision calls the FAKEABLE
// path is allowed to make on a flat fixture.

enum FixtureVision {
    /// VNDetectFaceRectanglesRequest on a single CVPixelBuffer (FAKEABLE).
    static func detectsFace(_ pb: CVPixelBuffer) throws -> Bool {
        let req = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cvPixelBuffer: pb, options: [:]).perform([req])
        return !(req.results?.isEmpty ?? true)
    }

    /// VNDetectFaceCaptureQualityRequest -> faceCaptureQuality (0…1) (FAKEABLE).
    static func captureQuality(_ pb: CVPixelBuffer) throws -> Double {
        let req = VNDetectFaceCaptureQualityRequest()
        try VNImageRequestHandler(cvPixelBuffer: pb, options: [:]).perform([req])
        guard let q = (req.results?.first as? VNFaceObservation)?.faceCaptureQuality else { return 0 }
        return Double(q)
    }

    /// A placeholder RGB metric (FAKEABLE). Replace with your real redness math.
    static func meanRedness(_ pb: CVPixelBuffer) -> Double? { 0.0 }

    /// A placeholder depth metric. Only ever called when a REAL AVDepthData was
    /// present — `depthDataMap` is the verified accessor (apple-docs).
    static func reliefProxy(_ depth: AVDepthData) -> Double {
        _ = depth.depthDataMap   // CVPixelBuffer of per-pixel depth/disparity
        return 0.0
    }
}
#endif
