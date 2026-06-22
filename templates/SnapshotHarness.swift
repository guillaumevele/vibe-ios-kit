import XCTest
import SwiftUI
@testable import YourApp   // <- rename to your module

#if DEBUG
/// `SnapshotHarness` — the agent's visual inner loop. A plain XCTest that hosts a
/// single SwiftUI component (or whole screen), renders it to a PNG at a fixed size
/// and scale, writes the file to a known directory, AND attaches it to the test
/// result so it survives in the `.xcresult` bundle. The agent then reads that PNG
/// back with its vision tool and checks it against the token + intent checklist in
/// `patterns/VISUAL-VERIFY.md`.
///
/// This replaces "does this button look right? — go look at your phone" with a
/// deterministic artifact the agent can actually SEE.
///
/// Two complementary mechanisms (use the one that fits — see VISUAL-VERIFY.md):
///   1. `ImageRenderer` (here): static layer tree. Fast, no Simulator boot, runs in
///      `xcodebuild test`. Captures layout / spacing / color tokens / type / emoji.
///      Does NOT run live Metal shaders or iOS 26 `.glassEffect` refraction.
///   2. `XCUIScreen.main.screenshot()` in a UI test, or `simctl io booted
///      screenshot` against the running app: captures the REAL composited frame,
///      including shaders and glass. Slower; needs a booted Simulator.
///
/// Starter template. Adjust the module name and the views under test. The render
/// is a host/Simulator render; the on-device pass remains your final gate.
@available(iOS 16.0, *)
@MainActor
final class SnapshotHarness: XCTestCase {

    /// Where snapshots land. The agent reads PNGs from here after the run.
    /// Override with env `SNAPSHOT_DIR` (an agent / CI can set it without code).
    private var snapshotDir: URL {
        if let p = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            return URL(fileURLWithPath: p, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("snapshots", isDirectory: true)
    }

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
    }

    // MARK: - The reusable snapshot step

    /// Render `view`, write `<name>.png` to `snapshotDir`, attach it to the result,
    /// and (if a golden exists) assert the pixel diff is within tolerance.
    /// Returns the written URL so the test can log the path for the agent to open.
    @discardableResult
    func snapshot<V: View>(
        _ view: V,
        named name: String,
        size: CGSize,
        scale: CGFloat = 1.0,
        colorScheme: ColorScheme = .dark,
        goldenTolerance: Double = 0.02
    ) throws -> URL {
        let url = snapshotDir.appendingPathComponent("\(name).png")
        try VisualSnapshot.writePNG(view, size: size, scale: scale,
                                    colorScheme: colorScheme, name: name, url: url)

        // Attach to the .xcresult so the PNG is recoverable even off the temp dir.
        let attachment = XCTAttachment(contentsOfFile: url)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Tell the agent EXACTLY where to look (it reads stdout, then opens the file).
        print("SNAPSHOT_WRITTEN name=\(name) path=\(url.path)")

        // Optional regression backstop against a committed golden.
        if let golden = goldenURL(for: name) {
            let diff = try GoldenDiff.compare(candidate: url, golden: golden,
                                              tolerance: goldenTolerance)
            print("GOLDEN_DIFF name=\(name) mean=\(diff.meanAbsDiff) " +
                  "max=\(diff.maxChannelDiff) changed=\(diff.changedFraction) pass=\(diff.passed)")
            XCTAssertTrue(diff.passed,
                "\(name) drifted from golden: meanAbsDiff \(diff.meanAbsDiff) > \(goldenTolerance). " +
                "If the change is intended, re-bless the golden; otherwise it is a regression.")
        } else {
            print("GOLDEN_MISSING name=\(name) — first run; bless this PNG as the golden if it looks right.")
        }
        return url
    }

    /// Goldens live in the test bundle under `Goldens/<name>.png`. Commit them so a
    /// diff exists; absent → the snapshot is captured but not asserted (first run).
    private func goldenURL(for name: String) -> URL? {
        Bundle(for: type(of: self)).url(forResource: name, withExtension: "png", subdirectory: "Goldens")
    }

    // MARK: - Concrete cases (rename to YOUR components)

    /// Primary button: must use the token style, one accent, no emoji, correct
    /// corner + padding. The agent reads `primary_button.png` and checks it.
    func test_primaryButton_matchesTokens() throws {
        let view = ZStack {
            Color(white: 0.07)
            PrimaryButton(title: "Start analysis") {}   // <- your tokenized button
                .padding(24)
        }
        try snapshot(view, named: "primary_button",
                     size: CGSize(width: 390, height: 160))
    }

    /// A whole screen: spacing rhythm, hierarchy, one accent, material, no emoji.
    func test_homeScreen_isCoherent() throws {
        let view = HomeView()                            // <- your screen
        try snapshot(view, named: "home_screen",
                     size: CGSize(width: 390, height: 844))  // iPhone 16-class point size
    }

    /// Light + dark in one run, so the agent verifies BOTH token sets, not one.
    func test_card_lightAndDark() throws {
        let card = PremiumCard(title: "Skin analysis",
                               subtitle: "Tap to start a guided, controlled capture.",
                               symbol: "waveform.path.ecg")
            .padding(24)
        try snapshot(ZStack { Color(white: 0.97); card }, named: "card_light",
                     size: CGSize(width: 390, height: 160), colorScheme: .light)
        try snapshot(ZStack { Color(white: 0.07); card }, named: "card_dark",
                     size: CGSize(width: 390, height: 160), colorScheme: .dark)
    }
}
#endif
