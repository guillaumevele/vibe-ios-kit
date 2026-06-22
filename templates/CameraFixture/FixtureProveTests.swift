#if DEBUG
import XCTest
import AVFoundation
import CoreVideo
@testable import YourApp  // <-- replace with your module (same name across all test files)

/// "Fixture-prove": the deterministic, agent-runnable replacement for the
/// human-blocking "stand in front of the phone" loop.
///
/// These run in the SIMULATOR with no camera. They feed a known face fixture
/// through the SAME `FrameSource` seam the live camera uses, run the real
/// scan -> analysis pipeline, and assert on the output. The agent can run this
/// on every iteration; the real camera is needed only for a final acceptance
/// pass, not every change.
///
/// Replace `runScanPipeline(frames:)` with your app's actual entry point — the
/// function that today consumes camera frames. The whole design goal is that it
/// already depends on `any FrameSource`, so this test passes a `FixtureSource`
/// and nothing else changes.
final class FixtureProveTests: XCTestCase {

    /// RGB path: a flat face still drives the vision pipeline end to end.
    func test_rgbFixture_producesResult() async throws {
        let source = FrameSourceFactory.make(.fixtureImage(named: "face_neutral", fps: 12))
        XCTAssertFalse(source.providesDepth, "a flat image must not claim depth")

        // Collect a bounded number of frames so the test terminates.
        var seen = 0
        try await source.start()
        var first: Frame?
        for await frame in source.frames {
            if first == nil { first = frame }
            XCTAssertTrue(frame.isFixture)
            XCTAssertNil(frame.depth, "flat image fixture must carry nil depth")
            seen += 1
            if seen >= 5 { break }
        }
        await source.stop()

        let pb = try XCTUnwrap(first?.pixelBuffer)
        XCTAssertGreaterThan(CVPixelBufferGetWidth(pb), 0)
        // EXAMPLE assertion — swap for your real pipeline + result invariant:
        // let result = try await runScanPipeline(frames: source.frames)
        // XCTAssertEqual(result.redness.isFinite, true)
    }

    /// Depth path: a recorded RGBD still yields a REAL AVDepthData, so the
    /// depth-driven branch of the scan runs off-device. Add a
    /// `face_neutral_rgbd.heic` (a real front-camera portrait HEIC, or your own
    /// `dictionaryRepresentation(forAuxiliaryDataType:)` export) to the TEST
    /// bundle's resources.
    func test_depthFixture_carriesRealDepth() async throws {
        let source = FrameSourceFactory.make(
            .fixtureDepthStill(resource: "face_neutral_rgbd", ext: "heic", fps: 12)
        )
        XCTAssertTrue(source.providesDepth)

        try await source.start()
        var depthFrame: Frame?
        var seen = 0
        for await frame in source.frames {
            if frame.depth != nil { depthFrame = frame; break }
            seen += 1
            if seen >= 5 { break }
        }
        await source.stop()

        let depth = try XCTUnwrap(depthFrame?.depth, "RGBD fixture must reconstruct AVDepthData")
        // It is a real map with a real type — not invented from the flat image.
        XCTAssertTrue(
            depth.depthDataType == kCVPixelFormatType_DisparityFloat16 ||
            depth.depthDataType == kCVPixelFormatType_DisparityFloat32 ||
            depth.depthDataType == kCVPixelFormatType_DepthFloat16 ||
            depth.depthDataType == kCVPixelFormatType_DepthFloat32
        )
        let map = depth.depthDataMap
        XCTAssertGreaterThan(CVPixelBufferGetWidth(map), 0)
    }
}
#endif
