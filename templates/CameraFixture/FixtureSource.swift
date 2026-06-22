#if DEBUG
import AVFoundation
import CoreVideo
import CoreMedia
import ImageIO
import UniformTypeIdentifiers

/// The agent-runnable counterpart to `LiveCameraSource`. It emits the SAME
/// `Frame` values the live pipeline would, but from a known, bundled fixture —
/// so the scan -> analysis -> result pipeline runs deterministically in the
/// SIMULATOR with no camera and no human in front of the phone.
///
/// Three honesty tiers (see README "What can be faked"):
///   .image      — a flat still, looped. RGB path only; depth is always nil.
///   .clip       — a recorded .mov/.mp4 replayed at recorded timing. RGB only.
///   .depthStill — a recorded RGBD HEIC/JPEG whose embedded disparity aux-data
///                 is reconstructed into a REAL AVDepthData. The depth was
///                 MEASURED on a real TrueDepth/LiDAR capture and replayed; it
///                 is never synthesized from the flat image.
///
/// Compiled ONLY under `#if DEBUG` — there is no path for this type to reach a
/// Release build.
///
/// Verified APIs (apple-docs, iOS):
///   CVPixelBufferCreate / LockBaseAddress / GetBaseAddress (CoreVideo)
///   AVAssetReader / AVAssetReaderTrackOutput               (iOS 4.1+)
///   CGImageSourceCopyAuxiliaryDataInfoAtIndex              (ImageIO)
///   AVDepthData(fromDictionaryRepresentation:)            (iOS 11.0+)
///
/// Starter template. Type-checks against the iOS SDK; run it in a real build to
/// confirm a given fixture decodes (AGENTS.md §0).
public final class FixtureSource: FrameSource, @unchecked Sendable {  // invariant: mutable state (continuation, pumpTask) is created in init and mutated only from the single pump Task; `frames` is consumed by one consumer per the AsyncStream single-consumer contract.
    public enum Mode: Sendable {
        case image(named: String, fps: Double)
        case clip(resource: String, ext: String, loop: Bool)
        case depthStill(resource: String, ext: String, fps: Double)
    }

    public var providesDepth: Bool {
        if case .depthStill = mode { return true }
        return false
    }

    public private(set) lazy var frames: AsyncStream<Frame> = {
        AsyncStream { continuation in self.continuation = continuation }
    }()
    private var continuation: AsyncStream<Frame>.Continuation?

    private let mode: Mode
    private let bundle: Bundle
    private var pumpTask: Task<Void, Never>?

    public init(_ mode: Mode, bundle: Bundle = .main) {
        self.mode = mode
        self.bundle = bundle
    }

    public func start() async throws {
        switch mode {
        case let .image(named, fps):
            let pb = try Self.pixelBuffer(fromImageNamed: named, bundle: bundle)
            pumpStill(pixelBuffer: pb, depth: nil, fps: fps)
        case let .depthStill(resource, ext, fps):
            let (pb, depth) = try Self.rgbdStill(resource: resource, ext: ext, bundle: bundle)
            pumpStill(pixelBuffer: pb, depth: depth, fps: fps)
        case let .clip(resource, ext, loop):
            try pumpClip(resource: resource, ext: ext, loop: loop)
        }
    }

    public func stop() async {
        pumpTask?.cancel()
        pumpTask = nil
        continuation?.finish()
    }

    // MARK: - Still / RGBD: re-emit one frame at a fixed cadence

    private func pumpStill(pixelBuffer: CVPixelBuffer, depth: AVDepthData?, fps: Double) {
        let interval = UInt64((1.0 / max(fps, 1)) * 1_000_000_000)
        pumpTask = Task { [weak self] in
            var n: Int64 = 0
            while !Task.isCancelled {
                let pts = CMTime(value: n, timescale: CMTimeScale(max(fps, 1)))
                self?.continuation?.yield(Frame(
                    pixelBuffer: pixelBuffer,
                    depth: depth,
                    presentationTime: pts,
                    isFixture: true
                ))
                n += 1
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    // MARK: - Clip: replay a recorded video at its recorded timing

    private func pumpClip(resource: String, ext: String, loop: Bool) throws {
        guard let url = bundle.url(forResource: resource, withExtension: ext) else {
            throw FrameSourceError.fixtureNotFound("\(resource).\(ext)")
        }
        pumpTask = Task { [weak self] in
            repeat {
                await self?.replayOnce(url: url)
            } while loop && !Task.isCancelled
            self?.continuation?.finish()
        }
    }

    private func replayOnce(url: URL) async {
        let asset = AVURLAsset(url: url)
        guard
            let track = try? await asset.loadTracks(withMediaType: .video).first,
            let reader = try? AVAssetReader(asset: asset)
        else { return }

        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return }
        reader.add(output)
        guard reader.startReading() else { return }

        var lastPTS = CMTime.zero
        while !Task.isCancelled, let sample = output.copyNextSampleBuffer() {
            guard let pb = CMSampleBufferGetImageBuffer(sample) else { continue }
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)

            // Honour recorded inter-frame timing so motion/scan progress matches
            // what the device produced.
            let delta = CMTimeSubtract(pts, lastPTS)
            let seconds = max(0, CMTimeGetSeconds(delta))
            if seconds > 0, seconds < 1 {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
            lastPTS = pts

            continuation?.yield(Frame(
                pixelBuffer: pb,
                depth: nil,
                presentationTime: pts,
                isFixture: true
            ))
        }
        reader.cancelReading()
    }

    // MARK: - Decoding helpers

    /// Decode a bundled still (PNG/JPEG/HEIC) into a BGRA `CVPixelBuffer`.
    static func pixelBuffer(fromImageNamed named: String, bundle: Bundle) throws -> CVPixelBuffer {
        let candidates = ["", "png", "jpg", "jpeg", "heic"]
        var url: URL?
        for ext in candidates {
            if ext.isEmpty {
                if let u = bundle.url(forResource: named, withExtension: nil) { url = u; break }
            } else if let u = bundle.url(forResource: named, withExtension: ext) {
                url = u; break
            }
        }
        guard let url else { throw FrameSourceError.fixtureNotFound(named) }
        guard
            let src = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cg = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { throw FrameSourceError.fixtureDecodeFailed(named) }
        return try pixelBuffer(from: cg)
    }

    /// Reconstruct a REAL `AVDepthData` from a recorded RGBD container plus the
    /// decoded color image. The depth aux-data was written by a real capture
    /// (e.g. an iPhone front-camera portrait HEIC, or your own
    /// `dictionaryRepresentation(forAuxiliaryDataType:)` export) and is replayed
    /// verbatim — this is the only honest way to drive the depth path off-device.
    static func rgbdStill(
        resource: String, ext: String, bundle: Bundle
    ) throws -> (CVPixelBuffer, AVDepthData) {
        guard let url = bundle.url(forResource: resource, withExtension: ext) else {
            throw FrameSourceError.fixtureNotFound("\(resource).\(ext)")
        }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw FrameSourceError.fixtureDecodeFailed("\(resource).\(ext)")
        }
        guard let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw FrameSourceError.fixtureDecodeFailed("\(resource).\(ext)")
        }
        let pb = try pixelBuffer(from: cg)

        // Prefer disparity, fall back to depth — both are valid aux-data types.
        let auxTypes = [
            kCGImageAuxiliaryDataTypeDisparity,
            kCGImageAuxiliaryDataTypeDepth
        ]
        for type in auxTypes {
            if let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(src, 0, type) as? [AnyHashable: Any],
               let depth = try? AVDepthData(fromDictionaryRepresentation: info) {
                return (pb, depth)
            }
        }
        throw FrameSourceError.depthAuxDataMissing("\(resource).\(ext)")
    }

    /// Draw a CGImage into a fresh BGRA `CVPixelBuffer`.
    private static func pixelBuffer(from cg: CGImage) throws -> CVPixelBuffer {
        let width = cg.width, height = cg.height
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var out: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, attrs as CFDictionary, &out
        )
        guard status == kCVReturnSuccess, let pb = out else {
            throw FrameSourceError.fixtureDecodeFailed("CVPixelBufferCreate \(status)")
        }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard
            let base = CVPixelBufferGetBaseAddress(pb),
            let ctx = CGContext(
                data: base, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            )
        else { throw FrameSourceError.fixtureDecodeFailed("CGContext") }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pb
    }
}
#endif
