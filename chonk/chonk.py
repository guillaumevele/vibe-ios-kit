#!/usr/bin/env python3
"""chonk.py: ask Mistral Large 4 ("Le Chonk") for an iOS app, with or without the kit.

    python3 chonk/chonk.py new "Create an iOS app to ..." -o MyApp
    python3 chonk/chonk.py eval                 # run the with/without comparison

Three arms:
  bare  the request and the output contract, no system prompt
  kit   the same, with chonk/BRIEF.md as the system prompt
  loop  kit, then up to N rounds where the gate's findings (compiler errors,
        failed rubric checks) are sent back and the model resubmits

The API key is read from $MISTRAL_API_KEY, else from ~/.vibe/.env. It is never
printed and never written to an output file. Standard library only.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import grade  # noqa: E402

MODEL = "mistral-large-4"
API = "https://api.mistral.ai/v1/chat/completions"
TEMPERATURE = 0.7
MAX_TOKENS = 24000
# USD per million tokens, read on docs.mistral.ai/models/mistral-large-4-0 on 2026-11-19.
PRICE_IN, PRICE_OUT = 0.7, 2.1

BLOCK = re.compile(r"```swift[^\n]*\n(.*?)```", re.DOTALL)
FILE_LINE = re.compile(r"^\s*//\s*FILE:\s*([\w./+-]+\.swift)\s*$", re.MULTILINE)


def api_key() -> str:
    key = os.environ.get("MISTRAL_API_KEY", "").strip()
    env = Path.home() / ".vibe" / ".env"
    if not key and env.exists():
        for line in env.read_text().splitlines():
            if line.startswith("MISTRAL_API_KEY="):
                key = line.split("=", 1)[1].strip().strip("'\"")
    if not key:
        sys.exit("chonk: no MISTRAL_API_KEY in the environment or in ~/.vibe/.env")
    return key


def chat(messages: list[dict], seed: int) -> tuple[str, dict]:
    body = json.dumps({"model": MODEL, "messages": messages, "temperature": TEMPERATURE,
                       "random_seed": seed, "max_tokens": MAX_TOKENS}).encode()
    req = urllib.request.Request(API, data=body, headers={
        "Authorization": f"Bearer {api_key()}", "Content-Type": "application/json"})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=900) as r:
                data = json.load(r)
            break
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < 5:
                time.sleep(15 * (attempt + 1))
                continue
            raise SystemExit(f"chonk: Mistral API returned HTTP {e.code}: {e.read()[:300]!r}")
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt < 5:
                time.sleep(15 * (attempt + 1))
                continue
            raise SystemExit(f"chonk: network error: {e}")
    content = data["choices"][0]["message"]["content"]
    if isinstance(content, list):  # chunked content: keep the text chunks only
        content = "".join(c.get("text", "") for c in content if c.get("type") == "text")
    usage = data.get("usage", {})
    usage["finish_reason"] = data["choices"][0].get("finish_reason")
    usage["model"] = data.get("model")
    return content, usage


def extract(response: str, sources: Path) -> list[str]:
    """Write each ```swift block to Sources/. Later blocks of the same name win."""
    sources.mkdir(parents=True, exist_ok=True)
    for old in sources.glob("*.swift"):
        old.unlink()
    names = []
    for i, block in enumerate(BLOCK.findall(response), 1):
        m = FILE_LINE.search(block)
        name = Path(m.group(1)).name if m else f"File{i}.swift"
        (sources / name).write_text(block)
        if name not in names:
            names.append(name)
    return names


def feedback(g: dict) -> str:
    d, failed = g["details"], [c for c, ok in g["checks"].items() if not ok]
    out = ["The gate ran on your files. Fix every item below and reply with the complete "
           "set of files again, in the same format.", ""]
    if g.get("no_source"):
        out.append("- No ```swift block was found in your reply.")
    errs = d.get("swift6_errors") or d.get("swift5_errors") or []
    if errs:
        out.append("Swift 6 compiler errors:")
        out += [f"  {e}" for e in errs[:25]]
    notes = {
        "no_deprecation_warnings": "deprecated API: " + "; ".join(d.get("deprecations", [])[:8]),
        "no_legacy_api": "legacy API in use: " + ", ".join(d.get("legacy_api", [])),
        "icon_buttons_labelled": "icon-only buttons without accessibilityLabel near lines "
                                 + str(d.get("unlabelled_icon_button_lines")),
        "dynamic_type": "fixed font sizes: replace .system(size:) with text styles",
        "reduce_motion": "the app animates but never reads accessibilityReduceMotion",
        "loading_state": "no loading state (ProgressView)",
        "empty_state": "no empty state (ContentUnavailableView)",
        "error_state": "errors are not caught and stored for display, or try! is used",
        "bounded_animation": "unguarded continuous animation: " + "; ".join(d.get("ungated_animation", [])),
        "sf_symbols_exist": "SF Symbol names that do not exist: " + ", ".join(d.get("phantom_symbols", [])),
        "no_emoji": "emoji in source: " + "; ".join(d.get("emoji", [])),
    }
    out += [f"- {notes[c]}" for c in failed if c in notes]
    return "\n".join(out)


def generate(request: str, arm: str, seed: int, out: Path, rounds: int = 2) -> dict:
    """Run one arm. Writes response.md, Sources/, meta.json and grade.json to `out`."""
    out.mkdir(parents=True, exist_ok=True)
    contract = (HERE / "CONTRACT.txt").read_text().strip()
    messages = []
    if arm in ("kit", "loop"):
        messages.append({"role": "system", "content": (HERE / "BRIEF.md").read_text()})
    messages.append({"role": "user", "content": f"{request.strip()}\n\n{contract}"})
    usages, g = [], None
    for rnd in range(1 + (rounds if arm == "loop" else 0)):
        response, usage = chat(messages, seed)
        usages.append(usage)
        (out / ("response.md" if rnd == 0 else f"response-round{rnd}.md")).write_text(response)
        files = extract(response, out / "Sources")
        g = grade.grade_sources(out / "Sources")
        if arm != "loop" or all(g["checks"].values()):
            break
        (out / f"gate-round{rnd}.txt").write_text(feedback(g) + "\n")
        messages += [{"role": "assistant", "content": response},
                     {"role": "user", "content": feedback(g)}]
    tin = sum(u.get("prompt_tokens", 0) for u in usages)
    tout = sum(u.get("completion_tokens", 0) for u in usages)
    meta = {"model": MODEL, "served_model": usages[-1].get("model"), "arm": arm, "seed": seed,
            "temperature": TEMPERATURE, "max_tokens": MAX_TOKENS, "request": request.strip(),
            "api_calls": len(usages), "prompt_tokens": tin, "completion_tokens": tout,
            "finish_reasons": [u.get("finish_reason") for u in usages],
            "cost_usd": round(tin / 1e6 * PRICE_IN + tout / 1e6 * PRICE_OUT, 4),
            "files": files}
    (out / "meta.json").write_text(json.dumps(meta, indent=1) + "\n")
    (out / "grade.json").write_text(json.dumps(g, indent=1) + "\n")
    return {"meta": meta, "grade": g}


def cmd_new(args) -> int:
    r = generate(args.request, args.arm, args.seed, args.out, args.rounds)
    g, m = r["grade"], r["meta"]
    passed = sum(g["checks"].values())
    print(f"{args.out}/Sources: {len(m['files'])} file(s), {m['api_calls']} API call(s), "
          f"${m['cost_usd']}")
    print(f"gate: {passed}/{len(grade.CHECKS)} checks passed")
    for c, ok in g["checks"].items():
        print(f"  {'pass' if ok else 'FAIL'}  {c}")
    print("Not verified: nothing was built, launched, rendered or run on a device.")
    return 0 if passed == len(grade.CHECKS) else 1


def cmd_eval(args) -> int:
    prompts = sorted((HERE / "prompts").glob("*.txt"))
    jobs = []
    for p in prompts:
        for arm in args.arms:
            for seed in range(1, args.samples + 1):
                out = args.results / p.stem / arm / f"s{seed}"
                if (out / "meta.json").exists() and not args.force:
                    continue
                jobs.append((p.read_text(), arm, seed, out))
    print(f"{len(jobs)} generation(s) to run", file=sys.stderr)
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(generate, *j, args.rounds): j for j in jobs}
        for f in cf.as_completed(futures):
            j = futures[f]
            r = f.result()
            print(f"done {j[3].relative_to(args.results)}: "
                  f"{sum(r['grade']['checks'].values())}/{len(grade.CHECKS)} "
                  f"${r['meta']['cost_usd']}", file=sys.stderr)
    return grade.main([str(args.results)])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    n = sub.add_parser("new", help="generate one app and gate it")
    n.add_argument("request")
    n.add_argument("-o", "--out", type=Path, required=True)
    n.add_argument("--arm", choices=("bare", "kit", "loop"), default="loop")
    n.add_argument("--seed", type=int, default=1)
    n.add_argument("--rounds", type=int, default=2, help="max repair rounds for the loop arm")
    n.set_defaults(fn=cmd_new)
    e = sub.add_parser("eval", help="run every prompt in every arm, then grade")
    e.add_argument("--results", type=Path, default=HERE / "results")
    e.add_argument("--arms", nargs="+", default=["bare", "kit", "loop"])
    e.add_argument("--samples", type=int, default=3)
    e.add_argument("--rounds", type=int, default=2)
    e.add_argument("--jobs", type=int, default=3)
    e.add_argument("--force", action="store_true", help="regenerate runs that already exist")
    e.set_defaults(fn=cmd_eval)
    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
