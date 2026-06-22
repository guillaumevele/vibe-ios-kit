import AVFoundation
import CoreVideo
import CoreMedia

/// A `Frame` is the unit a skin-scan / vision pipeline consumes per tick: an RGB
/// image buffer plus the OPTIONAL depth that came from the same instant.
///
/// Keeping these together (instead of two callbacks) is what makes a fixture
/// honest: a recorded RGBD capture replays the SAME pairing the live TrueDepth
/// pipeline produced via `AVCaptureDataOutputSynchronizer`. A flat photo carries
/// `depth == nil`, so the consumer can branch correctly instead of being handed
/// invented depth.
///
/// NOT `Sendable`: it wraps `CVPixelBuffer` and `AVDepthData`, which Apple does
/// not mark `Sendable` (their backing memory is mutable). Declaring `Frame:
/// Sendable` would be a false promise the Swift-6 checker rejects — and exactly
/// the cross-actor-aliasing hazard this kit polices. The single-consumer
/// `AsyncStream<Frame>` contract is how we move frames safely without that lie:
/// one task pulls each `Frame` and is its sole owner for that tick.
public struct Frame {
    /// The color image, kCVPixelFormatType_32BGRA or the camera's native
    /// biplanar YUV — whatever your pipeline already expects.
    public let pixelBuffer: CVPixelBuffer

    /// Per-pixel depth/disparity for THIS frame, or `nil` when the source has no
    /// real depth (a flat RGB photo, or a device without a TrueDepth/LiDAR
    /// sensor). Never synthesize a non-nil value from a flat image — see the
    /// README "What cannot be faked".
    public let depth: AVDepthData?

    /// Presentation timestamp. For live capture this is the sample's PTS; for a
    /// replayed clip it is the recorded PTS, so timing-dependent logic
    /// (motion, blur-over-time, scan progress) behaves as it did on device.
    public let presentationTime: CMTime

    /// `true` when this frame did NOT come from a live camera. The pipeline must
    /// never gate release behaviour on this; it exists so a debug HUD can show
    /// "FIXTURE" and so analytics can drop fixture runs. See README.
    public let isFixture: Bool

    public init(
        pixelBuffer: CVPixelBuffer,
        depth: AVDepthData? = nil,
        presentationTime: CMTime,
        isFixture: Bool
    ) {
        self.pixelBuffer = pixelBuffer
        self.depth = depth
        self.presentationTime = presentationTime
        self.isFixture = isFixture
    }
}

/// The seam. The capture/scan pipeline depends on THIS, never on
/// `AVCaptureSession` directly. A `LiveCameraSource` and a `FixtureSource`
/// implement it identically from the consumer's point of view, so the
/// human-blocking "stand in front of the phone" inner loop becomes a
/// deterministic, agent-runnable "feed a known fixture, assert the output".
///
/// Concurrency: frames are delivered on `frames`, an `AsyncStream` you iterate
/// from a single consuming task. This keeps the contract Swift-6-clean — no
/// shared mutable delegate state across actors. The live implementation hops the
/// capture-queue callback into the stream's continuation.
public protocol FrameSource: AnyObject, Sendable {
    /// Whether this source can ever produce real depth. A consumer can read this
    /// up front to decide whether to show the depth-driven scan or fall back to
    /// the RGB-only path, WITHOUT waiting for the first frame.
    var providesDepth: Bool { get }

    /// Begin producing frames. Idempotent: calling twice is a no-op.
    func start() async throws

    /// Stop producing and release resources. After this the `frames` stream
    /// finishes.
    func stop() async

    /// The ordered stream of frames. Finishes when `stop()` is called or, for a
    /// non-looping fixture, when the source is exhausted.
    var frames: AsyncStream<Frame> { get }
}

/// Selects which source the app builds. The whole point of the seam: the switch
/// lives in ONE place, is `#if DEBUG`-gated, and never changes release wiring.
public enum FrameSourceKind: Sendable, Equatable {
    /// The real camera. The ONLY kind compiled into a Release build.
    case liveCamera

    #if DEBUG
    /// A single bundled still image, looped at `fps`. Drives the RGB/vision path
    /// only — `depth` is always `nil`.
    case fixtureImage(named: String, fps: Double)

    /// A recorded video clip replayed frame-by-frame at its recorded timing.
    /// RGB only unless the clip is a recorded-depth container (see below).
    case fixtureClip(resource: String, ext: String, loop: Bool)

    /// A recorded RGBD still: a HEIC/JPEG whose embedded disparity/depth
    /// aux-data is reconstructed into a REAL `AVDepthData`. This is the only
    /// honest way to exercise the depth path with no device — the depth was
    /// measured on a real TrueDepth/LiDAR capture and is replayed, not invented.
    case fixtureDepthStill(resource: String, ext: String, fps: Double)
    #endif
}

/// The single factory the app calls. In Release it can ONLY return a live
/// camera — the fixture cases don't exist outside `#if DEBUG`, so there is no
/// path for a fixture to reach a shipping build.
public enum FrameSourceFactory {
    public static func make(_ kind: FrameSourceKind) -> any FrameSource {
        switch kind {
        case .liveCamera:
            return LiveCameraSource()
        #if DEBUG
        case let .fixtureImage(named, fps):
            return FixtureSource(.image(named: named, fps: fps))
        case let .fixtureClip(resource, ext, loop):
            return FixtureSource(.clip(resource: resource, ext: ext, loop: loop))
        case let .fixtureDepthStill(resource, ext, fps):
            return FixtureSource(.depthStill(resource: resource, ext: ext, fps: fps))
        #endif
        }
    }

    /// Resolve the active kind once, from a launch argument / env var, so an
    /// agent can deep-link a fixture run with no human and no code edit:
    ///
    ///   xcodebuild ... -resultBundlePath ... \
    ///     OTHER_LAUNCH=-FrameSourceFixture face_neutral_rgbd.heic
    ///
    /// Release always returns `.liveCamera` regardless of arguments.
    public static func resolved(from defaults: UserDefaults = .standard) -> FrameSourceKind {
        #if DEBUG
        if let name = defaults.string(forKey: "FrameSourceFixtureImage") {
            return .fixtureImage(named: name, fps: 12)
        }
        if let res = defaults.string(forKey: "FrameSourceFixtureDepthStill") {
            let (base, ext) = splitExt(res, fallback: "heic")
            return .fixtureDepthStill(resource: base, ext: ext, fps: 12)
        }
        if let res = defaults.string(forKey: "FrameSourceFixtureClip") {
            let (base, ext) = splitExt(res, fallback: "mov")
            return .fixtureClip(resource: base, ext: ext, loop: true)
        }
        #endif
        return .liveCamera
    }

    #if DEBUG
    private static func splitExt(_ s: String, fallback: String) -> (String, String) {
        guard let dot = s.lastIndex(of: ".") else { return (s, fallback) }
        return (String(s[..<dot]), String(s[s.index(after: dot)...]))
    }
    #endif
}
