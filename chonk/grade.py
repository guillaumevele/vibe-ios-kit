#!/usr/bin/env python3
"""grade.py: score generated SwiftUI apps against chonk/RUBRIC.md.

    python3 chonk/grade.py chonk/results            # regrade every run, print the table
    python3 chonk/grade.py --one path/to/Sources    # grade one app, print JSON

Needs Xcode (swiftc and the iOS Simulator SDK). Needs no API key and no
network: it only reads the Swift files already on disk, so the numbers it
prints are reproducible. Standard library only.
"""
from __future__ import annotations

import argparse
import json
import os
import plistlib
import re
import subprocess
import sys
import tempfile
from pathlib import Path

KIT = Path(__file__).resolve().parent.parent
DOCTOR = KIT / "bin" / "vibe-ios-doctor"
TARGET = "arm64-apple-ios26.0-simulator"
SYMBOLS_PLIST = Path("/System/Library/CoreServices/CoreGlyphs.bundle/Contents/"
                     "Resources/name_availability.plist")

CHECKS = [
    "compiles_swift5", "compiles_swift6",
    "no_deprecation_warnings", "no_legacy_api",
    "icon_buttons_labelled", "dynamic_type", "reduce_motion",
    "loading_state", "empty_state", "error_state",
    "bounded_animation", "sf_symbols_exist", "no_emoji",
]

LEGACY = [
    ("NavigationView", re.compile(r"\bNavigationView\b")),
    ("ObservableObject", re.compile(r"\bObservableObject\b")),
    ("@Published", re.compile(r"@Published\b")),
    ("@StateObject", re.compile(r"@StateObject\b")),
    ("@ObservedObject", re.compile(r"@ObservedObject\b")),
    ("@EnvironmentObject", re.compile(r"@EnvironmentObject\b")),
    (".foregroundColor(", re.compile(r"\.foregroundColor\s*\(")),
    (".cornerRadius(", re.compile(r"\.cornerRadius\s*\(")),
    ("PreviewProvider", re.compile(r"\bPreviewProvider\b")),
    ("DispatchQueue.", re.compile(r"\bDispatchQueue\s*\.")),
]
ANIMATION = re.compile(
    r"\bwithAnimation\b|\.animation\s*\(|\.transition\s*\(|\.symbolEffect\s*\("
    r"|\.repeatForever\b|\bTimelineView\s*\(|\.contentTransition\s*\("
    r"|\.matchedGeometryEffect\s*\(|\bPhaseAnimator\b|\bKeyframeAnimator\b")
SYMBOL_LITERAL = re.compile(r"\bsystem(?:Name|Image)\s*:\s*\"([^\"\\]+)\"")


def blank_noncode(text: str) -> str:
    """Blank the contents of comments and string literals, keeping length and
    newlines, so a token inside a comment or a string is never counted."""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        two = text[i:i + 2]
        if two == "//":
            j = text.find("\n", i)
            j = n if j == -1 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        elif two == "/*":
            j = text.find("*/", i + 2)
            j = n if j == -1 else j + 2
            for k in range(i, j):
                if out[k] != "\n":
                    out[k] = " "
            i = j
        elif text[i] == '"':
            if text[i:i + 3] == '"""':
                j = text.find('"""', i + 3)
                j = n if j == -1 else j + 3
                for k in range(i + 3, max(i + 3, j - 3)):
                    if out[k] != "\n":
                        out[k] = " "
                i = j
            else:
                j = i + 1
                while j < n and text[j] != '"' and text[j] != "\n":
                    j += 2 if text[j] == "\\" else 1
                for k in range(i + 1, min(j, n)):
                    out[k] = " "
                i = min(j, n - 1) + 1
        else:
            i += 1
    return "".join(out)


def _match(code: str, start: int, open_ch: str, close_ch: str) -> int:
    """Index just past the bracket that closes the one at `start`, or -1."""
    depth = 0
    for i in range(start, len(code)):
        if code[i] == open_ch:
            depth += 1
        elif code[i] == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
    return -1


def _modifier_tail(code: str, pos: int) -> str:
    """The chain of `.modifier(...)` / `.modifier { ... }` that follows `pos`."""
    start, i, n = pos, pos, len(code)
    while True:
        j = i
        while j < n and code[j].isspace():
            j += 1
        if j >= n or code[j] != ".":
            return code[start:i]
        j += 1
        while j < n and (code[j].isalnum() or code[j] == "_"):
            j += 1
        while j < n and code[j] in "({":
            end = _match(code, j, code[j], ")" if code[j] == "(" else "}")
            if end == -1:
                return code[start:j]
            j = end
            k = j
            while k < n and code[k] in " \t":
                k += 1
            if k < n and code[k] == "{":
                j = k
        i = j


def unlabelled_icon_buttons(code: str) -> list[int]:
    """Line numbers of icon-only button labels with no accessibilityLabel."""
    closures = [m.end() - 1 for m in re.finditer(r"\blabel\s*:\s*\{", code)]
    for m in re.finditer(r"\bButton\s*\(\s*(?:role\s*:[^,()]*,\s*)?action\s*:", code):
        paren = code.find("(", m.start())
        end = _match(code, paren, "(", ")")
        if end == -1:
            continue
        k = end
        while k < len(code) and code[k].isspace():
            k += 1
        if k < len(code) and code[k] == "{":
            closures.append(k)
    bad = []
    for brace in closures:
        end = _match(code, brace, "{", "}")
        if end == -1:
            continue
        body = code[brace:end]
        if "Image(" not in body or re.search(r"\b(Text|Label)\s*\(", body):
            continue
        if ".accessibilityLabel" in body or ".accessibilityLabel" in _modifier_tail(code, end):
            continue
        bad.append(code.count("\n", 0, brace) + 1)
    return sorted(set(bad))


def catch_stores_error(code: str) -> bool:
    for m in re.finditer(r"\bcatch\b[^{\n]*\{", code):
        end = _match(code, m.end() - 1, "{", "}")
        if end == -1:
            continue
        for line in code[m.end():end - 1].splitlines():
            s = line.strip()
            if s.startswith(("let ", "var ")):
                continue
            if re.search(r"(?<![=!<>])=(?!=)", s):
                return True
    return False


def compile_swift(files: list[Path], version: str, cache: Path) -> dict:
    sdk = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"],
                         capture_output=True, text=True, check=True).stdout.strip()
    cmd = ["xcrun", "swiftc", "-typecheck", "-parse-as-library", "-sdk", sdk,
           "-target", TARGET, "-swift-version", version,
           "-module-cache-path", str(cache)] + [str(f) for f in files]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        out = p.stderr + p.stdout
    except subprocess.TimeoutExpired:
        return {"errors": ["type-check timed out after 600 s"], "deprecations": []}
    root = str(files[0].parent) + os.sep if files else ""
    diags, seen = [], set()
    for line in out.splitlines():
        if ": error:" in line or ": warning:" in line:
            line = line.replace(root, "")
            if line not in seen:
                seen.add(line)
                diags.append(line)
    return {
        "errors": [d for d in diags if ": error:" in d],
        "deprecations": [d for d in diags if ": warning:" in d and "deprecated" in d],
    }


def grade_sources(src: Path) -> dict:
    files = sorted(src.glob("*.swift")) if src.is_dir() else []
    if not files:
        return {"no_source": True, "checks": {c: False for c in CHECKS}, "details": {}}
    raw = "\n".join(f.read_text(encoding="utf-8", errors="replace") for f in files)
    code = blank_noncode(raw)
    cache = Path(tempfile.gettempdir()) / "chonk-module-cache"
    cache.mkdir(exist_ok=True)
    c5 = compile_swift(files, "5", cache)
    c6 = compile_swift(files, "6", cache)

    legacy = [name for name, rx in LEGACY if rx.search(code)]
    icon = unlabelled_icon_buttons(code)
    fixed_fonts = len(re.findall(r"\.system\s*\(\s*size\s*:", code))
    animates = bool(ANIMATION.search(code))
    reads_rm = "accessibilityReduceMotion" in code
    empty = ("ContentUnavailableView" in code
             or bool(re.search(r"\b(?:if|else if)\b[^\n{]*\.isEmpty\b", code))
             or bool(re.search(r"\bcase\s+\.empty\b", code)))
    force_try = len(re.findall(r"\btry!", code))
    stores = catch_stores_error(code)

    symbols = sorted(set(SYMBOL_LITERAL.findall(raw)))
    known = plistlib.loads(SYMBOLS_PLIST.read_bytes())["symbols"]
    phantom = [s for s in symbols if s not in known]

    doc = subprocess.run([sys.executable, str(DOCTOR), "--strict", str(src)],
                         capture_output=True, text=True)
    doc_lines = [l.replace(str(src) + os.sep, "") for l in doc.stdout.splitlines()]
    ungated = [l for l in doc_lines if "ungated" in l]
    emoji = [l for l in doc_lines if "emoji" in l]

    checks = {
        "compiles_swift5": not c5["errors"],
        "compiles_swift6": not c6["errors"],
        "no_deprecation_warnings": not c5["errors"] and not c5["deprecations"],
        "no_legacy_api": not legacy,
        "icon_buttons_labelled": not icon,
        "dynamic_type": fixed_fonts == 0,
        "reduce_motion": (not animates) or reads_rm,
        "loading_state": "ProgressView" in code,
        "empty_state": empty,
        "error_state": force_try == 0 and stores,
        "bounded_animation": not ungated,
        "sf_symbols_exist": not phantom,
        "no_emoji": not emoji,
    }
    details = {
        "files": [f.name for f in files],
        "lines": raw.count("\n") + 1,
        "swift5_errors": c5["errors"][:40],
        "swift6_errors": c6["errors"][:40],
        "swift5_error_count": len(c5["errors"]),
        "swift6_error_count": len(c6["errors"]),
        "deprecations": c5["deprecations"][:40],
        "legacy_api": legacy,
        "unlabelled_icon_button_lines": icon,
        "fixed_font_sizes": fixed_fonts,
        "animates": animates,
        "reads_reduce_motion": reads_rm,
        "force_try": force_try,
        "catch_stores_error": stores,
        "phantom_symbols": phantom,
        "symbols_used": len(symbols),
        "ungated_animation": ungated,
        "emoji": emoji,
    }
    return {"no_source": False, "checks": checks, "details": details}


def toolchain() -> dict:
    def run(*a):
        return subprocess.run(a, capture_output=True, text=True).stdout.strip()
    return {
        "xcode": run("xcodebuild", "-version").replace("\n", ", "),
        "sdk": run("xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"),
        "swift": run("xcrun", "swiftc", "--version").splitlines()[0],
        "target": TARGET,
    }


def regrade(results: Path) -> dict:
    runs = []
    for meta_path in sorted(results.glob("*/*/*/meta.json")):
        run_dir = meta_path.parent
        prompt, arm, sample = run_dir.parts[-3:]
        g = grade_sources(run_dir / "Sources")
        (run_dir / "grade.json").write_text(json.dumps(g, indent=1) + "\n")
        meta = json.loads(meta_path.read_text())
        runs.append({"prompt": prompt, "arm": arm, "sample": sample,
                     "truncated": bool(meta.get("truncated")) or (meta.get("finish_reasons") or [None])[-1] == "length",
                     "api_calls": meta.get("api_calls"), "cost_usd": meta.get("cost_usd"), **g})
        print(f"graded {prompt}/{arm}/{sample}: "
              f"{sum(g['checks'].values())}/{len(CHECKS)}", file=sys.stderr)
    return {"toolchain": toolchain(), "checks": CHECKS, "runs": runs}


def table(scores: dict) -> str:
    runs = scores["runs"]
    arms = [a for a in ("bare", "kit", "loop") if any(r["arm"] == a for r in runs)]
    n = {a: sum(1 for r in runs if r["arm"] == a) for a in arms}
    lines = ["| check | " + " | ".join(f"{a} (n={n[a]})" for a in arms) + " |",
             "|---|" + "---|" * len(arms)]
    for c in scores["checks"]:
        cells = [f"{sum(1 for r in runs if r['arm'] == a and r['checks'][c])}/{n[a]}" for a in arms]
        lines.append(f"| `{c}` | " + " | ".join(cells) + " |")
    for label, key in (("replies cut at the token limit", "truncated"), ("no Swift source in the reply", "no_source")):
        cells = [f"{sum(1 for r in runs if r['arm'] == a and r.get(key))}/{n[a]}" for a in arms]
        lines.append(f"| {label} | " + " | ".join(cells) + " |")
    lines.append("")
    prompts = sorted({r["prompt"] for r in runs})
    lines.append("| prompt | " + " | ".join(f"{a}: checks passed, mean of {len(scores['checks'])}" for a in arms) + " |")
    lines.append("|---|" + "---|" * len(arms))
    for p in prompts:
        cells = []
        for a in arms:
            rs = [sum(r["checks"].values()) for r in runs if r["arm"] == a and r["prompt"] == p]
            cells.append(f"{sum(rs) / len(rs):.1f}" if rs else "none")
        lines.append(f"| {p} | " + " | ".join(cells) + " |")
    return "\n".join(lines) + "\n"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("path", type=Path)
    ap.add_argument("--one", action="store_true", help="grade a single Sources directory")
    args = ap.parse_args(argv)
    if args.one:
        print(json.dumps(grade_sources(args.path), indent=1))
        return 0
    scores = regrade(args.path)
    (args.path / "scores.json").write_text(json.dumps(scores, indent=1) + "\n")
    md = table(scores)
    (args.path / "SCORES.md").write_text(md)
    print(md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
