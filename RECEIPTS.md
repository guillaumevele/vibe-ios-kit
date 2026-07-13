# One bug this posture would have caught: VeraOrbV4, `bug_type 202`

The kit's rules are not abstract. This is the private production incident they
are distilled from. The original `.ips` contains private device and application
metadata and is not published here, so this document is an incident report, not
an independently verifiable public receipt.

## What shipped, and what it did

A decorative "orb" view, `VeraOrbV4`, drove **8 unbounded
`TimelineView(.animation)`** (re-rendering ~120 fps each) **+ 3 `.repeatForever`**
animations, continuously, the whole time the orb was on screen.

On a real device with **Auto-Lock = Never**, sitting on that tab for ~3 minutes:
sustained **100% on one core → the OS watchdog killed the app**. The crash report
was not a segfault — it was a CPU resource exception:

```
"bug_type" : "202"        // CPU resource exception (watchdog), not SIGSEGV
sustained main-thread stack:  UpdateCycle → SwiftUICore → AttributeGraph
```

The private `.ips` was the machine-generated evidence used during diagnosis; its
`UpdateCycle → SwiftUICore → AttributeGraph` stack identified the hot path. The
raw report is not included, and the timeline below should therefore be read as
the author's incident account rather than a public reproduction artifact. The
same class of bug appeared three times in one night — `MeshGradient`
re-rasterizing (01:18), then a blur header re-rasterizing over a scroll (01:32),
then a re-soak with no observed `bug_type 202` report (01:41).

## The fix, mapped to the posture

```diff
- // 8 of these, ungated, 120fps, always running while visible:
- TimelineView(.animation) { timeline in …orb layer… }
- .repeatForever(autoreverses: true)                       // x3, ungated
+ // capped to 30fps (≈4x less CPU, behavior-preserving) and gated:
+ TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in …orb layer… }
+ .repeatForever(autoreverses: true)                       // gated on
+     // accessibilityReduceMotion, paused when off screen
```

Maps directly to **AGENTS.md §1**: no ungated `TimelineView(.animation)` / no
ungated `.repeatForever`; cap the frame rate (120 fps buys nothing for a halo);
pause off screen; and gate the whole thing behind a 3-minute idle-CPU soak.

`vibe-ios-doctor` flags the **naive ungated form** of this statically — an
`TimelineView(.animation)` / `.repeatForever` with no guard token and no
Bool/Binding gate in the enclosing view. It is a token-presence heuristic, not a
proof of the gating relationship (a guard token that gates a *different* view in
the same type can suppress it), so it is a gate, not a guarantee — the 3-minute
device soak above was the internal acceptance evidence.

## The numbers, qualified honestly

- **Before:** sustained 100% on one core, **watchdog-killed** at the ~90-second
  mark under Auto-Lock = Never. That is the reported before-state — a kill, not
  a traced percentage.
- **After (target):** for an animated screen at rest, `xctrace` sustained CPU
  **below ~30–40%**. This is the acceptance band, not a fresh measurement; treat
  it as the bar to clear, not a claimed result.

No before/after Instruments trace with paired percentages is published here,
because none was captured — inventing one would be the exact dishonesty §0 bans.

## Reproduce the class of bug

```bash
# 3-minute foreground soak, SCROLLING continuously, Auto-Lock = Never
# (a navigation-only soak misses the scroll cost), then pull the crash logs:
idevicecrashreport -u <your-device-udid> -k ./crashlogs
grep -l '"bug_type" : "202"' ./crashlogs/*.ips
```

The window to fire is ~90 s of sustained one-core load, so soak ≥ 100 s. That
turns the receipt from "trust me" into "here is how to reproduce the class" —
which is the reusable asset.
