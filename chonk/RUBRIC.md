# Rubric

Written and committed before any generation was run (see `git log` on this
file). Every check is mechanical: `chonk/grade.py` computes it from the Swift
sources alone, so two people grading the same output get the same score.

Each check is pass or fail per generated app. There is no weighting and no
overall mark: the table reports, per check, how many apps passed in each arm.

## Compile

Command, with every extracted `.swift` file passed together:

```
xcrun swiftc -typecheck -parse-as-library \
  -sdk <iPhoneSimulator SDK> -target arm64-apple-ios26.0-simulator \
  -swift-version <5|6> <files>
```

| id | check | pass when |
|---|---|---|
| `compiles_swift5` | type-checks in Swift 5 mode | the compiler reports 0 errors |
| `compiles_swift6` | type-checks in Swift 6 mode (strict concurrency) | the compiler reports 0 errors |

A type-check is not a build and not a run. It proves the code is well-typed
against the SDK. It proves nothing about behaviour or looks.

## Current API

| id | check | pass when |
|---|---|---|
| `no_deprecation_warnings` | compiler deprecation warnings | the Swift 5 type-check succeeds and prints 0 warnings containing `deprecated` |
| `no_legacy_api` | legacy spellings the compiler does not warn about | none of these appear in code: `NavigationView`, `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, `.foregroundColor(`, `.cornerRadius(`, `PreviewProvider`, `DispatchQueue.` |

An app that does not compile fails `no_deprecation_warnings` too: the compiler
may stop before it reports every deprecation, so broken code is never credited
with being current.

## Accessibility

| id | check | pass when |
|---|---|---|
| `icon_buttons_labelled` | icon-only buttons | every `Button` whose label closure holds an `Image(systemName:)` and no `Text` or `Label` has an `.accessibilityLabel` in the closure or in the modifiers chained right after it |
| `dynamic_type` | fixed font sizes | `.system(size:` appears 0 times |
| `reduce_motion` | Reduce Motion | the app has no animation at all, or it reads `accessibilityReduceMotion` |

## States

| id | check | pass when |
|---|---|---|
| `loading_state` | a loading state | `ProgressView` appears |
| `empty_state` | an empty state | `ContentUnavailableView` appears, or an `if`/`else if` condition tests `.isEmpty`, or a `case .empty` branch exists |
| `error_state` | errors reach the screen | there is no `try!`, and at least one `catch` block assigns to something (the error is stored, not dropped) |

## Motion

| id | check | pass when |
|---|---|---|
| `bounded_animation` | no unguarded continuous animation | `bin/vibe-ios-doctor --strict` prints no `ungated` finding |

## Symbols and tone

| id | check | pass when |
|---|---|---|
| `sf_symbols_exist` | phantom symbol names | every string literal passed to `systemName:` or `systemImage:` is a key of the system's `name_availability.plist` |
| `no_emoji` | emoji in source | `bin/vibe-ios-doctor` prints no `emoji` finding |

## What this rubric cannot tell you

- Whether the app works. Nothing is built, launched or tapped.
- Whether it looks good. Nothing is rendered.
- Whether VoiceOver reads it well. Labels are counted, not listened to.
- The checks under Accessibility, States and Symbols are text heuristics. A
  determined program can satisfy them and still be wrong, and correct code
  written in an unusual shape can fail them. Each heuristic is covered by a
  passing and a failing fixture in `chonk/tests/`.
- The rubric and the brief come from the same list of lessons. A high score
  for the kit arm shows that the model followed the brief. It is not
  independent evidence that the app is better.
