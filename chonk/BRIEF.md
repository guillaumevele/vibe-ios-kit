# App brief: what "create an app" leaves out

You are writing a complete iOS app in one pass. A one-line request never says
the things below, and a first draft never includes them. Each rule here was paid
for with a real bug in a shipped SwiftUI app. Treat them as requirements, not
suggestions. Target: iOS 26, Swift 6 language mode, SwiftUI only.

## 1. It must compile in Swift 6 mode

- Strict concurrency is on. Mark every type that touches UI state `@MainActor`.
  Model values that cross an `await` are `Sendable` structs or enums.
- State lives in `@Observable` classes held with `@State`, passed down as plain
  properties or `@Bindable`. Do not use `ObservableObject`, `@Published`,
  `@StateObject`, `@ObservedObject` or `@EnvironmentObject`.
- `async`/`await` only. No `DispatchQueue`, no completion handlers, no Combine.
- Never silence the compiler with `@unchecked Sendable` or `nonisolated(unsafe)`.
- Use only API you are certain exists with that exact spelling. If you are not
  sure a modifier exists, use the plainer one you are sure of.

## 2. Every screen has four states, not one

A screen that shows data has: loading, empty, failed, and content. Write all
four, as one `enum` the view switches over, not as scattered booleans.

- Loading: a `ProgressView` with a label.
- Empty: `ContentUnavailableView` with a sentence that says what to do next and
  a button that does it.
- Failed: the error is caught, stored in state, shown in words a person can
  act on, with a Retry button. Never `try!`, never an empty `catch`, never a
  `print` as the only handling.
- A failed load must never overwrite saved data. If reading the store failed,
  refuse to write to it until a read succeeds, and say so on screen.

## 3. Accessibility is part of the first draft

- A button whose label is only an icon gets `.accessibilityLabel`. Prefer
  `Button("Title", systemImage: "name")` or `Label`, which carry the title.
- Text uses text styles (`.font(.headline)`, `.font(.body)`). Never
  `.font(.system(size:))`: a fixed size ignores Dynamic Type. A layout that
  must change at large sizes branches on `@Environment(\.dynamicTypeSize)`.
- A row made of several texts is one element:
  `.accessibilityElement(children: .combine)`.
- Progress rings, gauges and other drawn values expose
  `.accessibilityValue` in words.
- Tap targets are at least 44 by 44 points.
- Color is never the only signal. Pair it with a symbol or a word.

## 4. Motion is bounded and optional

- Read `@Environment(\.accessibilityReduceMotion)` in every view that
  animates, and give the reduced branch a real result (no animation, or a
  crossfade), not the same motion made shorter.
- No `.repeatForever` and no `TimelineView(.animation)` unless the view also
  stops it: pause on `scenePhase != .active`, on `.onDisappear`, and when
  Reduce Motion is on. An unguarded continuous animation pins a CPU core.
  For a countdown, prefer `Text(timerInterval:)`, which the system advances
  for free.
- A selection change is a content change, not a movement: make it instant
  and confirm it with `.sensoryFeedback(.selection, trigger:)`.
- Do not change a view's `.id()` inside an animated transaction. The view is
  destroyed and recreated, and the animation slides the replacement in.

## 5. Presentation carries its data

- A sheet that needs a value uses `.sheet(item:)` with an `Identifiable`
  value. `.sheet(isPresented:)` plus a separate optional can build its
  content before the value is set, and the sheet opens empty.
- A destructive action is confirmed with `.alert` holding a
  `Button(role: .destructive)` and a `Button(role: .cancel)`.
- Navigation is `NavigationStack` with value-based `navigationDestination`.

## 6. Current API only

- `NavigationStack`, not `NavigationView`.
- `.foregroundStyle`, not `.foregroundColor`.
- `.clipShape(.rect(cornerRadius:))`, not `.cornerRadius`.
- `.onChange(of:) { oldValue, newValue in }`, not the one-parameter form.
- `.task { }` for async work tied to a view, not `.onAppear { Task { } }`.
- `#Preview`, not `PreviewProvider`.
- Dates and numbers through `.formatted(...)`, never a `DateFormatter()`
  built inside `body`.

## 7. `body` stays pure

- No side effects in `body` or in a getter that `body` reads. A getter that
  writes to `UserDefaults` is an infinite render loop.
- No allocation of formatters, gradients or sorted copies on each evaluation.
  Compute once in the model.

## 8. Symbols and tone

- SF Symbols only, and only names you are certain exist. A misspelled symbol
  name compiles, and renders an empty view with no error. When unsure, use a
  common one (`plus`, `trash`, `checkmark`, `xmark`, `gearshape`, `clock`,
  `book`, `star`, `arrow.clockwise`, `exclamationmark.triangle`).
- No emoji anywhere: not in UI strings, not in comments.
- One accent color, system materials, a spacing scale held in one `enum`.
  No raw `Color(red:green:blue:)` outside that one place.

## 9. Structure

- One `@main` App, one root view, small views with one job each.
- Logic lives in the `@Observable` model, behind a small protocol for
  anything that does I/O, so it can be replaced in previews and tests.
- User-facing strings are literals passed to `Text` (so they are
  localizable keys), never built by concatenation.

## 10. Say what you did not verify

End with a short section named `Not verified`. You did not run this app. List
what still needs a build, a simulator run, a VoiceOver pass and a device.
Do not claim the app works.
