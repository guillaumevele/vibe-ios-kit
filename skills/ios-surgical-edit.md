# Skill: surgical Swift edits with bounded FIM

When changing a Swift file that **already compiles**, do not rewrite the file or
the whole function — that risks silently altering code outside your intent (a
reordered import, a dropped attribute, a reflowed comment). Rewrite only the
region between two anchors with a **bounded fill-in-the-middle** patch, so the
rest of the file is provably byte-identical.

The `vibe --agent ios` profile wires this in as a tool the agent invokes itself,
backed by [`vibe-fim`](https://github.com/guillaumevele/vibe-fim) (Codestral FIM).

## The agent invokes it — `vibe-fim_surgical_patch`

When you (the agent) need to change a working Swift file, **compute two unique
anchors** that bracket the region and call the MCP tool:

```
vibe-fim_surgical_patch(
  file = "Sources/ScanView.swift",
  before_anchor = "    var body: some View {",   # frozen prefix ends right after this
  after_anchor  = "    private func makeOverlay", # frozen suffix starts right at this
  instruction   = "gate the shader on scenePhase so CPU returns to idle when inactive",
  dry_run = true,
)
```

The tool returns the unified diff **and** a scope report, so you see the proof,
not just a success flag:

```
[BOUNDED] edit confined between anchors; Swift parse not checked.
  frozen prefix: 812 chars (unchanged)
  frozen suffix: 1043 chars (unchanged)
  region: 240 chars -> 287 chars
```

Because the prefix and suffix are sent verbatim and never regenerated, the edit
cannot leak into the rest of the file. For Swift, `vibe-fim` currently proves
byte-bounded scope but does not perform syntax or type validation
(`parses: null`). Review the dry-run diff and scope report. If the proposal is
acceptable, apply it with `dry_run = false`, then immediately run
`swiftc -frontend -parse` and the target's real `xcodebuild` build/test command.
Accept the patch only when those checks pass; otherwise reverse the returned
bounded diff rather than restoring the whole file.

```bash
xcrun swiftc -frontend -parse Sources/ScanView.swift
xcodebuild -scheme YourApp -destination 'generic/platform=iOS Simulator' build
# Then run the repository's real test command on an installed destination.
```

Setup (`install.sh` prints this command but does not run it):

```bash
pip install "vibe-fim[mcp]"   # provides vibe-fim-mcp, wired in agents/ios.toml
export MISTRAL_API_KEY=...
```

## Rule

Anchors must be **unique**. If an anchor is not unique, `vibe-fim` refuses rather
than guessing — choose a longer anchor; never apply a surgical edit to an
ambiguous location.

## Manual fallback

Without the agent, the same edit from a shell:

```bash
vibe-fim patch --file Sources/ScanView.swift \
  --before "    var body: some View {" \
  --after  "    private func makeOverlay" \
  --hint   "gate the shader on scenePhase so CPU returns to idle when inactive" \
  --dry-run
```
