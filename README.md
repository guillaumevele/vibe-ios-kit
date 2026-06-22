# vibe-ios-kit

Make [Mistral `vibe`](https://github.com/mistralai) a genuinely good **iOS**
builder — for **iOS 26/27, Swift 6, SwiftUI, and real (gated) Metal**.

[![posture](https://github.com/guillaumevele/vibe-ios-kit/actions/workflows/posture.yml/badge.svg)](https://github.com/guillaumevele/vibe-ios-kit/actions/workflows/posture.yml)
![license](https://img.shields.io/badge/license-MIT-green)

A capable model already knows SwiftUI syntax. What it reliably gets *wrong* is the
one bug that ships: **an ungated `TimelineView(.animation)` that pins a CPU core
and drains the battery** — the most common SwiftUI production fault (see
[RECEIPTS.md](RECEIPTS.md) for the real `bug_type 202` incident this is distilled
from). `vibe-ios-kit` makes the rule that bans it a *standing instruction*, and
ships a **runnable lint that proves it** — not a scaffolder you have to trust.

---

## What's inside

| File | What it is | Status |
|---|---|---|
| `bin/vibe-ios-doctor` | A runnable gate that enforces the posture: emoji in code, `@unchecked Sendable` without a stated invariant, formatter allocs in a body (FAIL), ungated continuous animations (WARN/`--strict`). | **executable; CI-gated; tested** |
| `AGENTS.md` | The build posture: CPU budget, Swift 6 concurrency, gated Metal, premium aesthetic, proof-not-vibes. `vibe` auto-loads it at a project root. | validated (loads, layers on vibe's prompt) |
| `agents/ios.toml` | A custom `vibe` agent (`vibe --agent ios`) that raises the bash timeout to 1200s for slow `xcodebuild`s. | validated (loads & runs) |
| `skills/ios-surgical-edit.md` | The agent edits Swift via [`vibe-fim`](https://pypi.org/project/vibe-fim/)'s MCP tool, so changes are bounded — the rest of a working file stays byte-identical. | validated (vibe-fim published & tested) |
| `templates/Sheen.metal` | A real `[[stitchable]]` color effect; `time` is a Swift-owned uniform you can freeze. | **compiles to metallib** (`xcrun -sdk iphoneos`) |
| `templates/SheenView.swift` | Applies the effect with the clock gated on visibility + scene + Reduce Motion; idle GPU at rest. | **type-checks clean** vs the iOS SDK |
| `templates/PremiumCard.swift` | An institutional card: material, one accent, SF Symbol, no emoji. | **type-checks clean** vs the iOS SDK |

> Honesty (per `AGENTS.md §0`): `Sheen.metal` compiles to a metallib and both
> `.swift` files type-check clean against the iOS 26/27 SDK
> (`swiftc -sdk iphoneos -target arm64-apple-ios17.0 -typecheck`). A full app
> build + a device idle-CPU soak remain *your* gate — the doctor is a static
> check and says so.

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

**What it cannot catch** (and does not pretend to): runtime CPU, off-screen
`Canvas` redraws, and the 3-minute idle-CPU soak (AGENTS.md §1). Those are not
statically decidable and remain a manual/device gate.

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
Codestral fill-in-the-middle: the prefix and suffix are byte-identical, the
result is rejected if it no longer parses, and the tool returns the diff + a
scope proof. No silent collateral changes to a working type — something a
block-rewrite agent (Claude Code, Cursor) structurally cannot guarantee. See
`skills/ios-surgical-edit.md`.

## Reusable shape

The shape is not iOS-specific: **an `AGENTS.md` posture + a named `vibe` agent +
bounded edits via a Codestral-FIM tool + an executable proof gate** would port to
any platform with a strong correctness culture. This kit is the iOS instance.

## License

MIT © Guillaume Vele
