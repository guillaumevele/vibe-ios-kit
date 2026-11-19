# Chonk your app

Ask Mistral Large 4 ("Le Chonk", API id `mistral-large-4`) for an iOS app the
way people actually ask: one line, "create an app that...". Then measure what
changes when the request carries the kit's brief, and what changes again when
a compiler gate sends its findings back.

This directory holds the brief, the gate, the rubric, and the full record of a
comparison that was actually run on 2026-11-19 and 2026-11-20: every reply,
every extracted Swift file, every grade.

## Result

Four one-line requests (`prompts/`), three samples each, three arms. Scores
are the number of generated apps, out of 12, that pass each check of
`RUBRIC.md`.

| check | bare | kit | loop |
|---|---|---|---|
| `compiles_swift5` | 6/12 | 2/12 | 9/12 |
| `compiles_swift6` | 5/12 | 3/12 | 9/12 |
| `no_deprecation_warnings` | 6/12 | 2/12 | 9/12 |
| `no_legacy_api` | 11/12 | 12/12 | 12/12 |
| `icon_buttons_labelled` | 8/12 | 12/12 | 12/12 |
| `dynamic_type` | 6/12 | 12/12 | 12/12 |
| `reduce_motion` | 4/12 | 12/12 | 12/12 |
| `loading_state` | 6/12 | 12/12 | 12/12 |
| `empty_state` | 12/12 | 12/12 | 12/12 |
| `error_state` | 4/12 | 12/12 | 12/12 |
| `bounded_animation` | 12/12 | 12/12 | 12/12 |
| `sf_symbols_exist` | 11/12 | 12/12 | 12/12 |
| `no_emoji` | 12/12 | 12/12 | 12/12 |
| all 13 checks | 0/12 | 2/12 | 9/12 |

- **bare**: the request and a neutral output contract (`CONTRACT.txt`), no
  system prompt.
- **kit**: the same, with `BRIEF.md` as the system prompt.
- **loop**: the kit reply of the same prompt and seed, then up to two rounds
  in which the gate's findings are sent back and the model resubmits.

Reproduce the table from the committed outputs. This needs Xcode, and no API
key:

```bash
python3 chonk/grade.py chonk/results
```

It rewrites `results/SCORES.md`, `results/scores.json` and each run's
`grade.json`. Run on the toolchain recorded in `scores.json` (Xcode 27.2,
iOS Simulator SDK 27.2, Swift 6.4.2), `git diff` stays empty.

## What the numbers say

1. **The brief alone made compilation worse.** With the brief, the model
   wrote every state, label and motion guard the rubric looks for (12/12 on
   seven checks where the bare arm scored 4 to 8), and compiled less often:
   2/12 against 6/12 in Swift 5 mode. The brief asks for more API surface, and
   the model misspells more of it. Eight of the nine kit apps that fail the
   Swift 6 type-check fail on a single error.
2. **A brief without a compiler is not enough.** The claim "give the model
   our lessons and the app is better" is false as stated. What held up is the
   pair: brief plus gate. After at most two repair rounds, 9/12 apps
   type-check in Swift 6 mode and pass all 13 checks. No bare app passes all
   13.
3. **Three loop runs still do not compile** after two rounds
   (`01-reading-tracker/loop/s1`, `02-feed-reader/loop/s1`,
   `03-focus-timer/loop/s3`). Their remaining errors are in `grade.json`.
4. **Things the bare model already gets right**: no emoji, no unguarded
   `repeatForever`, an empty state, existing SF Symbol names (11/12). The
   brief buys nothing there.

## What ran

- Model `mistral-large-4`, `temperature` 0.7, `reasoning_effort` high (the
  documented default), `random_seed` 1 to 3, `max_tokens` 64000.
- 24 generations for bare and kit, 15 further calls for the loop arm.
  Cost computed from the API's token counts at the listed price (0.70 USD
  in, 2.10 USD out per million tokens, read on 2026-11-19): 0.53 USD bare,
  0.77 USD kit, 1.18 USD for the loop rounds.
- Every app was type-checked twice with
  `xcrun swiftc -typecheck -parse-as-library -sdk <iPhoneSimulator SDK>
  -target arm64-apple-ios26.0-simulator -swift-version 5|6`.
- The rubric and the grader were committed before the first generation
  (commit `3ba98b6`). The checks have not changed since. Three reporting rows
  (all 13 checks, truncated replies, replies without source) were added to
  the table later.
- `agents/chonk.toml` was exercised once: `vibe --agent chonk -p` answered on
  `mistral-large-4` in an isolated `VIBE_HOME` (vibe 2.19.0).
- `pytest tests/` passes (35 tests): a reference fixture that passes all 13
  checks, a negative witness that fails all 13, and a fixture for a
  deprecated call that still compiles.

## What did not run, and what went wrong

- **Nothing was built, launched, rendered or run on a device.** A type-check
  proves the code is well-typed against the SDK. It says nothing about
  whether the app works or looks right. No VoiceOver pass was made.
- **Run 1 is invalid and kept** in `runs/run1-truncated-at-24000/`. Reasoning
  tokens count against `max_tokens`. At 24000 the model ran out before
  answering in 15 of 24 runs (`finish_reason: length`, empty reply), mostly in
  the kit arm. That was a harness mistake, not a model result. It cost
  1.25 USD. Its numbers are not used anywhere above.
- **Run 2 was interrupted once** by an HTTP 520 from the API, which the client
  did not retry and which stopped the other calls. The client now retries
  every 5xx, and the nine missing generations were resumed with the same
  seeds. `random_seed` was not checked to give identical replies across
  calls, so regenerating will give different apps and different counts.
  Regrading the committed outputs is the reproducible part.
- One loop round still hit the 64000-token limit
  (`01-reading-tracker/loop/s1`, first repair round).
- **No "bare plus loop" arm was run.** The table cannot separate what the
  brief adds to the loop from what the gate would do alone.
- **The loop arm is told which rubric checks failed**, so its score on those
  checks is a statement about the gate, not about the model. Its compile
  results are the informative part.
- **n = 3 per prompt.** These are counts, not rates with error bars.
- **The rubric and the brief share an author and a list of lessons.** A high
  kit score on the heuristic checks shows the model followed the brief. It
  is not independent evidence of a better app. See the last section of
  `RUBRIC.md`.
- **No fine-tuning.** `GET /v1/models` reports `fine_tuning: false` for
  `mistral-large-4` on the account used. The "training" here is the loop:
  generate, gate, send the findings back.

## Use it

```bash
bin/chonk-your-app "Create an iOS app to track the books I am reading." -o MyApp
```

Reads `MISTRAL_API_KEY` from the environment or from `~/.vibe/.env`. Writes
`MyApp/Sources/*.swift`, the replies, and `grade.json`, and exits 0 only if
all 13 checks pass. Expect several minutes per round at the default
reasoning effort: 21000 output tokens per bare reply on average in run 2,
30000 with the brief, most of them reasoning.

Inside Mistral Vibe, `./install.sh` links `agents/chonk.toml`, and
`vibe --agent chonk` runs the kit's iOS agent on `mistral-large-4`.

Rerun the whole comparison (new generations, about 2.50 USD):

```bash
python3 chonk/chonk.py eval --results chonk/results-new
```

## Files

| path | what it is |
|---|---|
| `BRIEF.md` | the system prompt: ten things a one-line request leaves out |
| `CONTRACT.txt` | the output format, sent in every arm |
| `RUBRIC.md` | the 13 checks, and what they cannot tell you |
| `prompts/` | the four requests |
| `chonk.py` | generation, the loop, and the `eval` runner |
| `grade.py` | the gate: type-check, `vibe-ios-doctor`, heuristics |
| `results/` | run 2: replies, sources, `meta.json`, `grade.json`, `SCORES.md` |
| `runs/` | the invalid first run, and the logs of run 2 |
| `tests/fixtures/` | the grader's passing and failing witnesses |
