import SwiftUI

#if DEBUG
import UIKit
import CoreGraphics

/// `VisualSnapshot` — render a single SwiftUI view to a deterministic PNG on disk,
/// so an agent that cannot SEE the running app can capture a component and read the
/// image back with its vision tool. This is the visual analogue of the camera
/// `FixtureCaptureSource` (see `patterns/VISUAL-VERIFY.md`).
///
/// It uses SwiftUI's `ImageRenderer` (iOS 16+, verified vs apple-docs 2026-06-22):
///   - `proposedSize` pins the layout size so the PNG is reproducible run-to-run,
///   - `scale` pins the point→pixel ratio (use 1.0 for byte-stable goldens; a
///     device runs @2x/@3x, so a golden committed at scale 1 will NOT pixel-match a
///     device shot — that gap is the point of the "honest limits" section).
///   - `uiImage` returns the rasterized `UIImage`.
///
/// `ImageRenderer` rasterizes the SwiftUI layer tree directly. It does NOT run a
/// live Metal `colorEffect`/`distortionEffect` shader (those bind on the GPU at
/// draw time) and it does NOT sample a real backdrop, so iOS 26 `.glassEffect`
/// renders without its live refraction. For those, snapshot the *running app* in
/// the Simulator instead (see `SnapshotHarness` + `simctl io … screenshot`).
/// `VisualSnapshot` is for static composition: layout, spacing, color tokens,
/// typography, SF Symbols, the absence of emoji — the things that drift.
///
/// Starter template. Renders on the Simulator/host; not a substitute for a real
/// on-device visual pass (see `patterns/VISUAL-VERIFY.md` §"Honest limits").
@available(iOS 16.0, *)
@MainActor
enum VisualSnapshot {

    /// Render `view` at a fixed size + scale and write a PNG. Returns the file URL.
    ///
    /// - Parameters:
    ///   - view: the component or screen to capture. Wrap it yourself in the
    ///     intended background/colorScheme so the PNG matches design intent.
    ///   - size: the proposed layout size in points. Fixed → reproducible.
    ///   - scale: points→pixels. 1.0 = stable goldens; 2.0/3.0 = closer to device.
    ///   - colorScheme: force light/dark so the token check is unambiguous.
    ///   - url: where to write. Defaults to a temp file named after `name`.
    @discardableResult
    static func writePNG<V: View>(
        _ view: V,
        size: CGSize,
        scale: CGFloat = 1.0,
        colorScheme: ColorScheme = .dark,
        name: String = "snapshot",
        url: URL? = nil
    ) throws -> URL {
        let renderer = ImageRenderer(
            content: view
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.proposedSize = ProposedViewSize(size)   // pin layout — reproducible
        renderer.scale = scale                            // pin pixel ratio
        renderer.isOpaque = true                          // no alpha noise in the golden

        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            throw VisualSnapshotError.renderProducedNoImage
        }
        let out = url ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).png")
        try data.write(to: out)
        return out
    }

    enum VisualSnapshotError: Error { case renderProducedNoImage, goldenMissing, sizeMismatch }
}

/// `GoldenDiff` — an OPTIONAL pixel comparison against a committed reference image,
/// for regression detection. A model reading a screenshot is a judgment, not a
/// proof; this is the cheap deterministic backstop that catches "this used to look
/// right and silently changed". It is a per-channel mean-absolute-difference with a
/// tolerance, because anti-aliasing and subpixel rounding make exact equality
/// brittle across SDK point releases.
///
/// Same-scale only: compare a scale-1 candidate to a scale-1 golden. A device shot
/// (@2x/@3x) will never byte-match a scale-1 golden — diff candidates rendered by
/// the SAME mechanism, and use the vision-read loop for cross-renderer checks.
@available(iOS 16.0, *)
enum GoldenDiff {

    struct Result {
        let meanAbsDiff: Double        // 0…1 over all RGBA channels
        let maxChannelDiff: Double     // worst single channel, 0…1
        let changedFraction: Double    // fraction of pixels past per-pixel epsilon
        let passed: Bool
    }

    /// Compare two same-size PNGs. `tolerance` is the allowed mean-abs-diff (a good
    /// default for AA noise is ~0.02 ≈ 5/255). `perPixelEpsilon` decides when a
    /// pixel "changed" for `changedFraction`.
    static func compare(
        candidate: URL,
        golden: URL,
        tolerance: Double = 0.02,
        perPixelEpsilon: Double = 0.10
    ) throws -> Result {
        let a = try rgbaBytes(candidate)
        let b = try rgbaBytes(golden)
        guard a.width == b.width, a.height == b.height else {
            throw VisualSnapshot.VisualSnapshotError.sizeMismatch
        }
        var total = 0.0, worst = 0.0, changed = 0
        let n = a.pixels.count
        var i = 0
        while i < n {
            var pixelMax = 0.0
            for c in 0..<4 {
                let d = abs(Double(a.pixels[i + c]) - Double(b.pixels[i + c])) / 255.0
                total += d
                pixelMax = max(pixelMax, d)
            }
            worst = max(worst, pixelMax)
            if pixelMax > perPixelEpsilon { changed += 1 }
            i += 4
        }
        let mean = total / Double(n)
        let changedFraction = Double(changed) / Double(n / 4)
        return Result(
            meanAbsDiff: mean,
            maxChannelDiff: worst,
            changedFraction: changedFraction,
            passed: mean <= tolerance
        )
    }

    private struct Raw { let width: Int; let height: Int; let pixels: [UInt8] }

    private static func rgbaBytes(_ url: URL) throws -> Raw {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data),
              let cg = image.cgImage else {
            throw VisualSnapshot.VisualSnapshotError.goldenMissing
        }
        let w = cg.width, h = cg.height
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &buffer, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Raw(width: w, height: h, pixels: buffer)
    }
}
#endif
