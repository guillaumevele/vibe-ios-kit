# vibe-ios-kit

Make [Mistral `vibe`](https://github.com/mistralai/mistral-vibe) a genuinely good **iOS**
builder — for **iOS 26/27, Swift 6, SwiftUI, and real (gated) Metal**.

[![posture](https://github.com/guillaumevele/vibe-ios-kit/actions/workflows/posture.yml/badge.svg)](https://github.com/guillaumevele/vibe-ios-kit/actions/workflows/posture.yml)
![license](https://img.shields.io/badge/license-MIT-green)

A capable model already knows SwiftUI syntax. One recurring failure mode is
**an ungated `TimelineView(.animation)` that pins a CPU core and drains the
battery** (see [RECEIPTS.md](RECEIPTS.md) for the private incident report this
rule is distilled from). `vibe-ios-kit` makes the rule that bans it a *standing instruction*, and
ships a **runnable lint that gates the naive form** — not a scaffolder you have to
trust.

---

## What's inside

| File | What it is | Status |
|---|---|---|
| `bin/vibe-ios-doctor` | A runnable gate that enforces the posture: emoji in code, `@unchecked Sendable` without a stated invariant, formatter allocs in a body (FAIL), ungated continuous animations (WARN/`--strict`). | **executable; CI-gated; tested** |
| `AGENTS.md` | The build posture: CPU budget, Swift 6 concurrency, gated Metal, premium aesthetic, proof-not-vibes, iOS 26/AI non-negotiables, and **§10 the fixture-prove rules for camera/scan/sensor features** (drive the inner loop off a fixture, not the human). `vibe` auto-loads it at a project root. | instruction file; Vibe loading is not exercised by this repository's CI |
| `PATTERNS.md` | Curated iOS 26/27 techniques (FoundationModels, real Metal, Liquid Glass, navigation, motion, StoreKit) — API, gotcha, example and attribution where available. The internal review corpus is not published. | techniques, not copied code |
| `patterns/FIXTURE-CAPTURE.md` | The debug capture seam — a `CaptureSource` protocol + `FixtureCaptureSource` so a camera/scan feature's inner loop runs against a bundled fixture (no camera, no human). Includes the honest fakeable / replayable / not-fakeable table (flat RGB vs recorded RGBD vs live ARKit/TrueDepth) and an XCTest harness. | APIs verified vs `apple-docs` |
| `patterns/VISUAL-VERIFY.md` | The **visual** analogue: how the agent SEES rendered SwiftUI without a human eyeballing it. The render→capture→**read-the-PNG-back-with-the-vision-tool**→golden-diff loop, the pass/fail checklist (no-emoji, token style, spacing), the `ImageRenderer` vs running-app-screenshot table, and honest limits. Wired into `AGENTS.md §11`. | APIs verified vs `apple-docs` / SDK |
| `templates/VisualSnapshot.swift` | `ImageRenderer`-based snapshotter: render a view to a deterministic PNG (`proposedSize`/`scale` pinned) + `GoldenDiff` AA-tolerant pixel compare against a committed reference. | locally type-checked against the iOS 27 SDK; not compiled in CI |
| `templates/SnapshotHarness.swift` | An XCTest starter that hosts each component, writes `<name>.png`, attaches it to the `.xcresult`, prints the path for the agent to open, and asserts the golden diff. | requires integration into a real app test target, fixtures and a reviewed golden |
| `chonk/` | **Chonk your app**: a brief for one-line "create an app" requests, a compiler gate, and a measured comparison on Mistral Large 4 (4 prompts, 3 samples, with and without the kit). The brief alone compiled less often than no brief (2/12 against 6/12); brief plus gate reached 9/12 passing all 13 checks, against 0/12 bare. | **run for real; outputs and grades committed**; see [chonk/README.md](chonk/README.md) for what did not run |
| `agents/chonk.toml` | The iOS agent on `mistral-large-4` (`vibe --agent chonk`), without editing your vibe config. | one local programmatic call; not exercised by this repository's CI |
| `agents/ios.toml` | A custom `vibe` agent (`vibe --agent ios`) that raises the bash timeout to 1200s for slow `xcodebuild`s. | configuration file; load/run is not exercised by this repository's CI |
| `skills/ios-surgical-edit.md` | The agent edits Swift via [`vibe-fim`](https://pypi.org/project/vibe-fim/)'s MCP tool, so changes are bounded — the rest of a working file stays byte-identical. | validated (vibe-fim published & tested) |
| `templates/Sheen.metal` | A real `[[stitchable]]` color effect; `time` is a Swift-owned uniform you can freeze. | **compiles to metallib** (`xcrun -sdk iphoneos`) |
| `templates/SheenView.swift` | Applies the effect with the clock gated on visibility + scene + Reduce Motion; stops scheduling per-frame updates while gated. | source parses locally; integration build and GPU behavior require a real target |
| `templates/PremiumCard.swift` | An institutional card: material, one accent, SF Symbol, no emoji. | locally type-checked against the iOS SDK; not compiled in CI |

> Honesty (per `AGENTS.md §0`): local checks compile `Sheen.metal` to a
> metallib, type-check `VisualSnapshot.swift` and `PremiumCard.swift` against
> the iOS SDK, and parse `SheenView.swift`. `SnapshotHarness.swift` still needs
> a host app test target, fixtures and a reviewed golden. This repository's CI
> runs the doctor and its unit tests; a full app build and device idle-CPU soak
> remain downstream gates.

## The lint (the part that proves it)

```bash
# Point it at YOUR app — this is the distributable gate, not a self-scan:
bin/vibe-ios-doctor Sources/
bin/vibe-ios-doctor --strict Sources/      # treat continuous-animation warnings as failures
```

It runs in CI on every push (`.github/workflows/posture.yml`) and is unit-tested
to catch real violations *and* to stay green on this kit's own templates — the
naive grep version false-positives on correct gated code, so the gating rule uses
a brace-window heuristic, not a bare grep.

**What it cannot catch** (and does not pretend to): the tier-2 rule is a
token-presence heuristic — it flags an animation with *no* guard token in the
view, so a guard token that gates a different view in the same type can suppress
it (a possible false negative). And runtime CPU, off-screen `Canvas` redraws, and
the 3-minute idle-CPU soak (AGENTS.md §1) are not statically decidable. Those
remain a manual/device gate.

## Install

```bash
./install.sh          # symlinks agents/ios.toml into ~/.vibe/agents/
vibe --agent ios
```

Per project:

```bash
cp AGENTS.md      /path/to/YourApp/AGENTS.md
cp templates/*    /path/to/YourApp/Sources/
pip install "vibe-fim[mcp]"      # surgical, agent-invoked Swift edits
```

## What the posture enforces

A strong model already knows SwiftUI syntax. What it does *not* reliably do, and
what the posture makes standing rules:

- **Stop animations when off-screen.** No ungated `TimelineView(.animation)` /
  `.repeatForever`; cap the frame rate; pause off screen; 3-minute idle-CPU gate.
  (The lint enforces the static half.)
- **Respect Swift 6 strict concurrency** instead of papering over races with
  `@unchecked Sendable`.
- **Gate Metal time** as a Swift-owned uniform you can freeze (and that stays
  precise — see the Float32 note in `SheenView.swift`), with a frozen-frame
  fallback — not a wall clock inside the shader.
- **Look intentional**: materials, one accent, SF Symbols, zero emoji.
- **Prove it.** "It compiles" is not proof; a run, a trace, or a screenshot is.

## The surgical-edit tie-in

When changing a Swift file that already compiles, the agent does **not** rewrite
it. It calls **[vibe-fim](https://github.com/guillaumevele/vibe-fim)**'s
`surgical_patch` MCP tool, which rewrites only the region between two anchors via
Codestral fill-in-the-middle: the prefix and suffix are byte-identical, and the
tool returns the diff plus a scope proof. For Swift, `vibe-fim` currently reports
`parses: null`; every applied patch still requires `swiftc -frontend -parse` and
the target's real `xcodebuild` build/test command. See `skills/ios-surgical-edit.md`.

## Reusable shape

The shape is not iOS-specific: **an `AGENTS.md` posture + a named `vibe` agent +
bounded edits via a Codestral-FIM tool + an executable proof gate** would port to
any platform with a strong correctness culture. This kit is the iOS instance.

## License

MIT © Guillaume Vele
