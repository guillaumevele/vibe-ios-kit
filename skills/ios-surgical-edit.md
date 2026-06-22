# Skill: surgical Swift edits with bounded FIM

When changing a Swift file that **already compiles**, do not regenerate the whole
file or a whole function — that risks silently altering code outside your intent
(a reordered import, a dropped attribute, a reflowed comment). Use a **bounded
fill-in-the-middle** patch so the rest of the file is provably byte-identical.

This pairs `vibe` with [`vibe-fim`](https://pypi.org/project/vibe-fim/), which
wraps Codestral FIM and *verifies* that the prefix and suffix never change.

## Install

```bash
pip install vibe-fim
export MISTRAL_API_KEY=...
```

## When to use it

- Changing the body of one method while leaving the rest of the type alone.
- Inserting a guard, a modifier, or a property between two stable anchors.
- Any edit where you can name a unique line **before** and a unique line
  **after** the region to change.

## How to use it from the agent

Pick two unique anchors that bracket the region, then:

```bash
vibe-fim patch --file Sources/ScanView.swift \
  --before "    var body: some View {" \
  --after  "    private func makeOverlay" \
  --hint   "gate the shader on scenePhase so CPU returns to idle when inactive" \
  --dry-run
```

`--dry-run` prints a unified diff and a scope report:

```
[BOUNDED] edit confined between anchors.
  frozen prefix: 812 chars (unchanged)
  frozen suffix: 1043 chars (unchanged)
  region: 240 chars -> 287 chars
```

Review the diff, then drop `--dry-run` to write. Because the prefix and suffix
are sent verbatim and never regenerated, the edit cannot leak into the rest of
the file — exactly the property you want when touching a working Swift type.

## Rule

If an anchor is not unique, `vibe-fim` refuses rather than guessing. Choose a
longer anchor; never apply a surgical edit to an ambiguous location.
