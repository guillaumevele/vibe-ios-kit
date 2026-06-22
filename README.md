# vibe-ios-kit

Make [Mistral `vibe`](https://github.com/mistralai) a genuinely good **iOS**
builder: a custom agent, a hard-won build posture, and a surgical-edit workflow —
for **iOS 26/27, Swift 6, SwiftUI, and real (gated) Metal**.

This is not a scaffolder that emits a thousand lines you have to trust. It is the
*posture* that stops a capable model from generating CPU-melting animations,
data races, and emoji-strewn default-blue UI — distilled from a real production
build.

---

## What's inside

| File | What it is | Status |
|---|---|---|
| `AGENTS.md` | The build posture: CPU budget, Swift 6 concurrency, gated Metal, premium aesthetic, proof-not-vibes. `vibe` auto-loads it at a project root. | validated (loads, layers on vibe's prompt) |
| `agents/ios.toml` | A custom `vibe` agent — `vibe --agent ios`. | validated (loads & runs) |
| `skills/ios-surgical-edit.md` | Wire [`vibe-fim`](https://pypi.org/project/vibe-fim/) so Swift edits are bounded — the rest of a working file stays byte-identical. | validated (vibe-fim is published & tested) |
| `templates/Sheen.metal` | A real `[[stitchable]]` color effect; `time` is a Swift-owned uniform you can freeze. | **compiles** (`xcrun -sdk iphoneos metal`, AIR clean) |
| `templates/SheenView.swift` | Applies the effect with the animation clock **gated** (idle GPU at rest, Reduce-Motion fallback). | starter — build in Xcode before shipping |
| `templates/PremiumCard.swift` | An institutional card: material, one accent, SF Symbol, no emoji. | starter — build in Xcode before shipping |

> Honesty (per `AGENTS.md §0`): `Sheen.metal` is verified to compile with the
> iOS SDK. The `.swift` files are **starter templates** written against iOS 17+
> APIs but not yet compiled in an Xcode project or device-run — that build is
> your gate. The kit does not pretend otherwise.

## Install

```bash
./install.sh          # symlinks agents/ios.toml into ~/.vibe/agents/
vibe --agent ios
```

Per project:

```bash
cp AGENTS.md      /path/to/YourApp/AGENTS.md
cp templates/*    /path/to/YourApp/Sources/
pip install vibe-fim          # surgical Swift edits
```

## Why a posture beats a scaffolder

A strong model already knows SwiftUI syntax. What it does *not* reliably do is:

- **Stop animations when off-screen.** The single most common production bug is
  an ungated `TimelineView(.animation)` or `.repeatForever` pinning a core. The
  posture bans it and defines a 3-minute idle-CPU acceptance gate.
- **Respect Swift 6 strict concurrency** instead of papering over races with
  `@unchecked Sendable`.
- **Gate Metal time** as a Swift-owned uniform you can freeze, with a non-Metal
  fallback — not a wall clock inside the shader.
- **Look intentional**: materials, one accent, SF Symbols, zero emoji.
- **Prove it.** "It compiles" is not proof; a run, a trace, or a screenshot is.

`vibe-ios-kit` encodes those as standing rules so every edit inherits them.

## The surgical-edit tie-in

The kit pairs with **[vibe-fim](https://github.com/guillaumevele/vibe-fim)**:
when changing a Swift file that already compiles, patch only the region between
two anchors via Codestral fill-in-the-middle. The prefix and suffix are sent
verbatim and never regenerated, so the edit is provably bounded — no silent
collateral changes to a working type. See `skills/ios-surgical-edit.md`.

## License

MIT © Guillaume Vele
