# PATTERNS.md — distilled iOS 26/27 techniques

A license-clean reference for `vibe --agent ios`: real, current techniques
distilled from **67 production-quality sample projects** (SwiftUI / Metal /
FoundationModels). Each entry is the *technique* — the APIs, how they compose,
and the gotcha — with an original minimal example and attribution to where it was
seen. No third-party code is reproduced verbatim.

> Provenance & validation: mined from the corpus on 2026-06-22. `vibe-ios-doctor`
> was run across all **996 Swift files** of that corpus — surfacing **35 ungated**
> continuous animations (and exactly **1** `scenePhase` guard across 36
> `TimelineView` shader files). That ratio is the empirical backbone of the CPU
> budget rule in `AGENTS.md` §1.

Every animation/shader entry states its **CPU-budget posture** explicitly.

## On-device AI — Apple FoundationModels (iOS 26/27, privacy-first)

Apple's FoundationModels framework runs a ~3B on-device LLM on Apple-Intelligence-capable hardware (M1-class+). It is the privacy-aligned default: inference stays on the device, nothing leaves unless you explicitly escalate to Private Cloud Compute. These patterns are the load-bearing primitives. NOTE on API spelling (verified against the sample code, NOT against tutorial prose): the availability check is SystemLanguageModel.default.availability (NOT LanguageModelSession.isAvailable); the guide macro is @Guide(description:) on a PROPERTY (NOT @Guide("…") on a type); the Tool entry point is call(arguments:) (NOT call(with:)). Several bundled SKILL.md files ship the stale spellings — trust the framework, not the tutorial.

### Availability gate as first-class product state

**APIs** — SystemLanguageModel.default.availability .available | .unavailable(reason); reasons .deviceNotEligible / .appleIntelligenceNotEnabled / .modelNotReady; rendered via ContentUnavailableView

Before showing any AI surface, switch on availability and branch the WHOLE view (not just disable a button). Map each .unavailable reason to a distinct, actionable ContentUnavailableView. 'Unavailable' is a normal product state, never an error toast. availability is a cheap synchronous stored-property read — safe in body — but it changes at runtime (model finishes downloading, user toggles Apple Intelligence), so re-read it, never cache once at launch.

**Gotcha** — Always include an @unknown default (Apple adds reasons across point releases). Do NOT silently fall back to a server LLM in a privacy-sensitive app — that leaks data without consent. The gate is also the decision point for graceful degradation vs. an explicit off-device opt-in.

```swift
switch SystemLanguageModel.default.availability {
case .available: ChatView()
case .unavailable(.appleIntelligenceNotEnabled):
 ContentUnavailableView("Enable Apple Intelligence", systemImage: "brain",
  description: Text("Turn it on in Settings to use on-device analysis."))
case .unavailable(.modelNotReady):
 ContentUnavailableView("Model downloading…", systemImage: "arrow.down.circle")
case .unavailable(.deviceNotEligible):
 ContentUnavailableView("Not supported", systemImage: "iphone.slash")
@unknown default: ContentUnavailableView("Unavailable", systemImage: "questionmark")
}
```

*Seen in:* Foundation Chat; FoundationModels-Lab (foundation-models-app-builder skill)

### Streaming as cumulative snapshots (assign, never append) with a cancellable Task

**APIs** — session.streamResponse(to:) async sequence of snapshots; snapshot.content is the FULL text so far; Task { for try await … }; Task.isCancelled; task.cancel(); @Observable

Each streamed snapshot's .content is the ENTIRE response so far, not a delta — so you ASSIGN output = snap.content each iteration. Drive it from a stored Task you can .cancel() (Stop button), keep partial text on cancel, and guard !Task.isCancelled before committing the final message to history.

**Gotcha** — The #1 bug is treating snapshots as deltas (output += …) which duplicates text exponentially. #2 is committing the finished message without guarding Task.isCancelled — appends a stale message after the user hit Stop. #3: streaming fires UI updates dozens of times/sec, so keep the per-snapshot body cheap — NO .animation(value: streamingText), NO .drawingGroup() on the live Text. Animate only the final commit.

```swift
@Observable final class Gen {
 var output = ""; private var task: Task<Void,Never>?
 func run(_ p: String, _ s: LanguageModelSession) {
  task?.cancel(); output = ""
  task = Task {
   do { for try await snap in s.streamResponse(to: Prompt(p)) {
       if Task.isCancelled { return }
       output = snap.content    // FULL text — assign, never append
      } } catch { if !Task.isCancelled { output = " \(error.localizedDescription)" } }
  }
 }
 func stop() { task?.cancel() }
}
```

*Seen in:* Foundation Chat; FoundationModels-Lab (StreamingTextViewModel, ChatViewModel)

### @Generable + @Guide for type-safe structured output

**APIs** — @Generable on struct/enum; @Guide(description:) on properties + constraint guides .count(1...3)/range; session.respond(to:generating: T.self) Response<T> with typed .content; nested @Generable; types Sendable across actors

Annotate a Swift struct/enum with @Generable and each field with @Guide(description:) plus optional constraints like .count(1...3). respond(to:generating:) returns a decoded, type-safe value — no JSON, no regex. Enums become closed vocabularies (the model can only pick a case) = robust classification. Constraints are honored by guided decoding, so .count bounds array length for real; lean on it instead of post-validation.

**Gotcha** — Spelling: @Guide(description: "…") on a PROPERTY — not @Guide("…") on the type (stale tutorial form, won't compile). Generated types must be Sendable when crossing actors. Use concrete field names (rating, not value). For a medical app this is the safe path: closed enums stop the model inventing categories.

```swift
@Generable struct Triage: Sendable {
 @Guide(description: "One-line reason for the classification") let rationale: String
 let severity: Severity
 @Guide(description: "Up to three observed signs", .count(0...3)) let signs: [String]
 @Generable enum Severity: Sendable { case low, medium, high }
}
let t = try await LanguageModelSession()
 .respond(to: Prompt(noteText), generating: Triage.self).content
```

*Seen in:* FoundationModels-Lab (ProductReview, BookRecommendation, structured-generation.md)

### Typed error taxonomy with decodingFailure stricter retry

**APIs** — LanguageModelSession.GenerationError: .decodingFailure, .guardrailViolation, .exceededContextWindowSize, .assetsUnavailable, .rateLimited, .concurrentRequests, .unsupportedLanguageOrLocale, .unsupportedGuide, .refusal(_,_); LanguageModelSession.ToolCallError; @unknown default

Catch specific cases and route each through one shared handler. For @Generable extraction, catch .decodingFailure and retry ONCE with a stricter prompt + temperature 0.0 — not a blind loop. .refusal is async-throwing and carries context: handle it as a normal outcome, not a crash.

**Gotcha** — Do NOT retry .guardrailViolation or .exceededContextWindowSize with the same input — they need a different action (rephrase / summarize), not a re-try. Always include @unknown default. A single shared handler keeps every call site consistent.

```swift
do { return try await session.respond(to: Prompt(p), generating: T.self).content }
catch LanguageModelSession.GenerationError.decodingFailure {
 return try await session.respond(to: Prompt(p + "\nReturn only valid values; no extra fields."),
  generating: T.self, options: GenerationOptions(temperature: 0)).content
}
catch LanguageModelSession.GenerationError.guardrailViolation { throw AppError.blockedBySafety }
catch LanguageModelSession.GenerationError.refusal { throw AppError.modelDeclined }
```

*Seen in:* FoundationModels-Lab (FoundationModelsError.swift, common-errors.md)

### GenerationOptions: task-matched sampling (greedy for logic, seed for reproducibility)

**APIs** — GenerationOptions(sampling: .greedy | .random(top:seed:) | .random(probabilityThreshold:seed:), temperature:, maximumResponseTokens:); SDK spelling drifts: samplingMode (Xcode 26) vs sampling (Xcode 27)

Match sampling to the task. Extraction/classification/app-logic: .greedy (or temperature ~0.1) for stable, repeatable, auditable output. Creative copy: .random(probabilityThreshold: 0.9) + temperature ~0.8. Pass a fixed seed in .random for reproducible creative calls (tests/golden snapshots). Cap latency with maximumResponseTokens.

**Gotcha** — Temperature is IGNORED under .greedy — don't set both and expect temperature to matter. The keyword drifted across SDKs (samplingMode vs sampling); guard with #if compiler(>=6.4) if you support both Xcode 26 and 27. Seeded reproducibility only holds for the same model build. For any output your code parses or that must be auditable (medical), use greedy + low temp.

```swift
let deterministic = GenerationOptions(sampling: .greedy, temperature: 0.1, maximumResponseTokens: 160)
let creative   = GenerationOptions(sampling: .random(probabilityThreshold: 0.9), temperature: 0.8)
let reproducible = GenerationOptions(sampling: .random(top: 30, seed: 12345), temperature: 0.8)
let r = try await session.respond(to: Prompt(noteText), generating: Triage.self, options: deterministic)
```

*Seen in:* FoundationModels-Lab (SamplingStrategies.swift, ChatViewModel)

### Tool protocol: typed Arguments, draft-then-confirm for writes, narrow data slices

**APIs** — protocol Tool { name; description; @Generable struct Arguments; func call(arguments:) async throws -> some PromptRepresentable }; LanguageModelSession(tools:[…])

Conform to Tool with a short action name, a description that tells the model WHEN to use it, and a strongly-typed @Generable Arguments struct. call(arguments:) validates input before touching app data and returns a BOUNDED result. For tools that WRITE (Reminders, Calendar, HealthKit), split planning from committing: the model produces a @Generable draft, you show it to the user, you commit only after explicit confirmation.

**Gotcha** — Spelling is call(arguments:), not call(with:). Return a structured {success, message} when the model can recover; THROW only when the app must stop. Tools can run concurrently — make call() reentrant-safe. NEVER pass a full private dataset (whole address book, full health history) into the model — expose only the slice the task needs (privacy backbone). Permission denial is a normal return path. Attaching tools DISABLES the sliding-window trim, so budget context manually for tool sessions.

```swift
struct LookupTool: Tool {
 let name = "lookupAllergy"
 let description = "Look up one allergen the user already consented to share."
 @Generable struct Arguments: Sendable { @Guide(description: "Allergen name") var name: String }
 func call(arguments: Arguments) async throws -> some PromptRepresentable {
  guard let row = consentedAllergens[arguments.name] else { return "Not found / not shared." }
  return "Status: \(row.status)"  // bounded — no PII dump
 }
}
```

*Seen in:* FoundationModels-Lab (BasicTool, WeatherTool, tool-calling.md)

### Sliding-window context management with summarization backstop

**APIs** — session.transcript; Transcript(entries:); LanguageModelSession(model:transcript:); await transcript.tokenCount(using:); model.contextSize; catch .exceededContextWindowSize

For persistent multi-turn chats, proactively check if the transcript approaches a token threshold and rebuild the session keeping only recent entries within a budget. As a hard backstop, catch .exceededContextWindowSize, spin up a SEPARATE throwaway session to produce a @Generable summary, then start a fresh session whose instructions embed that summary so continuity survives.

**Gotcha** — Disable the sliding window when tools are attached (truncating mid-tool-call corrupts state) and only run it on-device. Token counting is async; for PCC it falls back to an estimate. Don't hard-code a magic 4096 cap — read model.contextSize. The summary path costs an extra generation, so do it lazily on overflow only. Overkill for one-shot extraction — use a fresh session per call there.

```swift
if await transcript.isApproachingLimit(threshold: 0.8, maxTokens: model.contextSize, using: model) {
 let kept = await transcript.entriesWithinTokenBudget(targetSize, using: model)
 session = LanguageModelSession(model: model, transcript: Transcript(entries: kept))
}
catch LanguageModelSession.GenerationError.exceededContextWindowSize {
 let summary = try await throwaway.respond(to: Prompt(allText), generating: Summary.self).content
 session = LanguageModelSession(model: model, instructions: Instructions("Context so far: \(summary)"))
}
```

*Seen in:* FoundationModels-Lab (FoundationLabConversationEngine.swift)

### Intent-gated prewarming with a stable prompt prefix

**APIs** — session.prewarm(); session.prewarm(promptPrefix: Prompt("…"))

Call prewarm() to load model weights before the first respond, cutting first-token latency. Pass a stable promptPrefix when many requests share an opening (system instructions / fixed lead-in) so that prefix is cached. Trigger ONLY on a concrete intent signal — user focuses the input field, taps the mic, opens the chat tab. It's fire-and-forget; no await needed.

**Gotcha** — prewarm() is a real memory/energy cost (it loads the model). Do NOT prewarm on every route or at app launch — that drains users who never touch AI. Gate on intent only. The prefix must actually match later prompts or the cache benefit is lost. This is the one FoundationModels pattern with a real CPU/energy posture: it is needs-gating, not free.

```swift
TextField("Ask…", text: $input)
 .onTapGesture { session.prewarm(promptPrefix: Prompt(systemLeadIn)) } // intent signal only
// later, the real call reuses the warmed prefix:
let r = try await session.respond(to: Prompt(systemLeadIn + input))
```

*Seen in:* FoundationModels-Lab (BasicPrewarming, PrewarmingWithPromptPrefix, ChatViewModel.startVoiceMode)

### #Playground for zero-ceremony API exploration

**APIs** — import Playgrounds; #Playground { … async throws body … } — runs inline in Xcode 26+ with live result panes

Wrap an async/throws body in #Playground {} to execute FoundationModels calls inline in Xcode — no app target, no UI, no run button. Ideal for validating a prompt, a @Generable schema, or a sampling setting before wiring it into a ViewModel. Captures techniques as runnable, reproducible snippets in the repo.

**Gotcha** — Dev-time only — strip from release targets. Still needs a real Apple-Intelligence-capable device/sim to actually run the model. The body runs on whatever actor Xcode gives it — don't assume @MainActor.

```swift
import FoundationModels
import Playgrounds
#Playground {
 let s = LanguageModelSession(instructions: "Be terse.")
 for try await snap in s.streamResponse(to: Prompt("Name 3 uses for on-device AI")) {
  print(snap.content)  // live pane updates per snapshot
 }
}
```

*Seen in:* FoundationModels-Lab (entire BookPlaygrounds/ tree)

### Private Cloud Compute as an EXPLICIT, labeled escalation (never silent)

**APIs** — PrivateCloudComputeLanguageModel() (iOS/macOS 27+, Xcode 27): .isAvailable, .quotaUsage.isLimitReached, .contextSize, ContextOptions(reasoningLevel:); entitlement com.apple.developer.private-cloud-compute; guard #if compiler(>=6.4) + @available(iOS 27, *)

On Xcode 27 / OS 27 you may offer PCC as an opt-in tier for harder reasoning while defaulting to on-device. Gate the whole path behind #if compiler(>=6.4) and #available; check isAvailable AND !quotaUsage.isLimitReached before offering it; read the larger contextSize dynamically; surface distinct status strings.

**Gotcha** — PCC sends data off-device (to Apple's attested servers) — for a privacy-sensitive app this MUST be an explicit, labeled user choice, NEVER a silent fallback, regardless of attestation. The API only exists on Xcode 27/OS 27 so it must be compiler- AND availability-gated. A missing entitlement surfaces as an opaque 'LanguageModel-Error -1' — detect and explain it. Quota is real and per-day — check isLimitReached before enabling the UI.

```swift
#if compiler(>=6.4)
if #available(iOS 27, macOS 27, *) {
 let pcc = PrivateCloudComputeLanguageModel()
 if pcc.isAvailable && !pcc.quotaUsage.isLimitReached {
  showOffDeviceOptIn = true  // EXPLICIT toggle — never silent
 }
}
#endif
```

*Seen in:* FoundationModels-Lab (ChatViewModel, FoundationModelsError.handlePrivateCloudComputeError)

## Real Metal effects & shaders — with a mandatory CPU-budget posture

SwiftUI exposes Metal via three stitchable-shader entry points (.colorEffect / .distortionEffect / .layerEffect), plus MTKView for heavy particle work. EMPIRICAL FINDING from the corpus you must internalize: across 36 TimelineView shader files there was exactly 1 scenePhase usage (and it was in an unrelated doc scanner), ZERO isLowPowerModeEnabled, ZERO accessibilityReduceMotion. The shaders are correct; the lifecycle discipline is missing almost everywhere. Every continuous effect below is needs-gating: drive it only while scenePhase == .active && !reduceMotion && on-screen, otherwise render one static frame.

### TimelineView(.animation(paused:)) + elapsed-time + .colorEffect (the canonical full-screen shader)

**APIs** — TimelineView(.animation(paused:)), @State start = Date.now, start.distance(to: tl.date), Rectangle().fill(.black).colorEffect(ShaderLibrary.fn(.float2(size), .float(time))); MSL: [[stitchable]] half4 fn(float2 pos, half4 color, float2 size, float time)

A full-bleed shader: TimelineView re-evaluates each frame, you compute elapsed = start.distance(to: timeline.date) (monotonic seconds) and feed it plus the explicit view size into a stitchable MSL function via .colorEffect. The shader owns every pixel; Rectangle().fill(.black) is just a canvas. Size must be passed explicitly because .colorEffect gives the shader pixel position but NOT the layer bounds.

**Gotcha** — MANDATORY GATING: TimelineView(.animation) drives the GPU at 60–120 Hz for as long as the view is mounted — it keeps burning GPU when occluded by a sheet, scrolled off-screen, or in Low Power Mode. The fix is trivial and missing across the corpus: bind .animation(paused:) to phase != .active, and additionally gate the whole effect on reduceMotion and on-screen visibility. Otherwise render a single static frame.

```swift
@State private var start = Date.now
@Environment(\.scenePhase) private var phase
@Environment(\.accessibilityReduceMotion) private var reduceMotion
var body: some View {
 TimelineView(.animation(paused: phase != .active || reduceMotion)) { tl in
  let t = Float(start.distance(to: tl.date))
  Rectangle().fill(.black)
   .colorEffect(ShaderLibrary.aurora(.float2(Float(w), Float(h)), .float(t)))
 }.ignoresSafeArea()
}
```

*Seen in:* webAnimation; DotsAnimation; Onboarding&Metal; Inferno-main

### Three shader entry points: colorEffect vs distortionEffect vs layerEffect (+ visualEffect for size)

**APIs** — .colorEffect(_:); .distortionEffect(_:, maxSampleOffset:); .layerEffect(_:, maxSampleOffset:); .visualEffect { content, proxy in content.colorEffect(... proxy.size ...) }

colorEffect: returns the output color per pixel, cannot read neighbours — generative fills, tints, recolor. distortionEffect: returns a new SAMPLING POSITION (warps geometry); maxSampleOffset bounds the pull — ripple/wave/jitter over real content. layerEffect: gets a SwiftUI::Layer it can sample arbitrarily (read neighbours) — the ONLY one that can blur/convolve/displace (variableBlur, emboss). Wrap any in .visualEffect when the shader needs the laid-out size from the GeometryProxy.

**Gotcha** — layerEffect cannot sample UIKit/AppKit-backed views — it logs a warning and shows a placeholder. distortionEffect with too-small maxSampleOffset clips the warp; too-large wastes a bigger offscreen sample. Reading size from a stale @State (set in onAppear) gives a one-frame-wrong / rotation-wrong shader — prefer .visualEffect proxy.size or .onGeometryChange. Same CPU-budget posture as above when driven by a TimelineView.

```swift
// distortion: warp text with a sine ripple, bounded sampling
content.visualEffect { c, p in
 c.distortionEffect(ShaderLibrary.ripple(.float2(p.size), .float(t)),
           maxSampleOffset: CGSize(width: 12, height: 12))
}
// blur needs neighbour reads -> layerEffect, NOT colorEffect
```

*Seen in:* Inferno-main; DotsAnimation; webAnimation

### Bundle-scoped stitchable shader catalog via @dynamicMemberLookup

**APIs** — ShaderLibrary.fn(.float2(...), .float(...)); ShaderLibrary.bundle(.module)[dynamicMember:]; @dynamicMemberLookup wrapper; [[stitchable]]; #include <SwiftUI/SwiftUI_Metal.h>

SwiftUI resolves Metal functions at runtime by name: ShaderLibrary.foo(args) binds to the [[stitchable]] MSL function foo. For a reusable Swift package, wrap this in a tiny @dynamicMemberLookup enum that pins resolution to the package bundle (ShaderLibrary.bundle(.module)[dynamicMember: name]) so the package resolves its OWN .metal symbols, not the host app's default library. Arguments are positional after the implicit (position, color) prefix — order and type must exactly match the MSL signature.

**Gotcha** — Name resolution is stringly-typed and fails at RUNTIME, not compile time: a typo or arg-count/type mismatch yields a blank/garbage layer with no error and no log. .metal files only auto-compile into the default library if Xcode sees them (target membership / PBXFileSystemSynchronizedRootGroup); MTL_FAST_MATH affects results. For a package you MUST scope to the package bundle or the symbol won't be found from the host.

```swift
@dynamicMemberLookup
enum FX {
 static subscript(dynamicMember n: String) -> ShaderFunction {
  ShaderLibrary.bundle(.module)[dynamicMember: n]  // resolve in THIS package
 }
}
// usage: content.colorEffect(FX.sinebow(.float2(size), .float(t)))
// MSL: [[stitchable]] half4 sinebow(float2 pos, half4 col, float2 size, float t)
```

*Seen in:* Inferno-main; webAnimation; Onboarding&Metal; DotsAnimation

### Freezable / Low-Power tiered ambient effect (the ONE project that gates correctly)

**APIs** — Timer.publish(every:).autoconnect().sink; onAppear/onDisappear/onChange(of: freeze) start/stop; .drawingGroup(); .compositingGroup(); a reduced-layer LowPower variant; bind to ProcessInfo.isLowPowerModeEnabled + accessibilityReduceMotion

This is the template every ambient/glow/'AI thinking' effect should follow. A single shared Timer drives the animation, STARTED in onAppear and STOPPED on onDisappear AND on a freeze:Bool flag. Ship an explicit LowPower variant that halves blur layers and slows the timer. drawingGroup() flattens the multi-layer glow into one offscreen pass; compositingGroup() scopes the blur.

**Gotcha** — Even this reference sample has two flaws to fix when you copy it: (1) it reads UIScreen.main.bounds (deprecated, wrong under Stage Manager / multi-window) — use a GeometryReader/visualEffect size instead; (2) the LowPower tier is selected MANUALLY — wire it to ProcessInfo.isLowPowerModeEnabled + accessibilityReduceMotion so it degrades automatically. Timer.publish is fine for a ~2 Hz reshuffle but use TimelineView for per-frame shaders.

```swift
@Environment(\.scenePhase) private var phase
@State private var t: AnyCancellable?
func start(){ stop(); t = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
 .sink { _ in withAnimation(.easeInOut(duration: 1)) { stops = Self.random() } } }
func stop(){ t?.cancel(); t = nil }
// .onAppear{ start() }.onChange(of: phase){ _, p in p == .active ? start() : stop() }
// .onDisappear{ stop() }.drawingGroup()
```

*Seen in:* AppleIntelligenceGlowEffect-main

### TextRenderer (Text.Layout) for per-glyph shimmer — GPU-free, accessibility-friendly text effects

**APIs** — TextRenderer + Animatable; animatableData; draw(layout: Text.Layout, in: inout GraphicsContext); run.typographicBounds; ctx.draw(run, options: .disablesSubpixelQuantization); .textRenderer(_:)

Animate text without a Metal shader: conform a struct to TextRenderer + Animatable. SwiftUI hands you the laid-out runs (Text.Layout); draw each with a per-run opacity/scale derived from its distance to a moving 'shimmer center'. Because progress is Animatable, withAnimation interpolates it for free. Precise and glyph-accurate — prefer over a colorEffect shimmer for headings/CTAs.

**Gotcha** — NEEDS-GATING: it is driven by withAnimation(.repeatForever(autoreverses:false)) which NEVER stops — it keeps re-laying-out and redrawing even when scrolled off-screen (these live in List rows). repeatForever has no visibility gate: pause it via an isOn flag flipped on scenePhase/onDisappear, and gate the whole effect on accessibilityReduceMotion. Draw at .disablesSubpixelQuantization to avoid shimmer jitter.

```swift
struct Shimmer: TextRenderer, Animatable {
 var progress: CGFloat
 var animatableData: CGFloat { get { progress } set { progress = newValue } }
 func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
  for run in layout.flatMap({$0}).flatMap({$0}) {
   let d = abs(run.typographicBounds.rect.midX - center(progress))
   ctx.opacity = 0.3 + max(0, 1 - d/35) * 0.7
   ctx.draw(run, options: .disablesSubpixelQuantization)
  }
 }
} // PAUSE off-screen / on reduceMotion
```

*Seen in:* ShimmerWave

### Render-at-fraction-resolution quality tier for heavy fragment shaders

**APIs** — .colorEffect on .frame(width: w*scale, height: h*scale) then .scaleEffect(1/scale, anchor: .topLeading); renderScale constant tied to thermalState / isLowPowerModeEnabled

Draw an expensive per-pixel shader (raymarch, multi-octave fbm, nested neighbour sums) into a SMALLER Rectangle (size * renderScale) and scaleEffect it back up so SwiftUI bilinear-upscales. Rendering at 0.6x cuts fragment work ~3x at the price of softness. The shader reads its own scaled size so the math stays correct.

**Gotcha** — At scale < 1 you get visible softening/aliasing on high-frequency content (thin dots, text). In the shipped sample renderScale is left at 1.0 (present but disabled) with NO tie to thermal/Low-Power state — wire it: drop to 0.6–0.75x under ProcessInfo.thermalState >= .serious or isLowPowerModeEnabled, full-res otherwise. This is the graceful-degradation lever for older devices/throttling.

```swift
let s: CGFloat = (lowPower || thermal >= .serious) ? 0.6 : 1.0
Rectangle().fill(.black)
 .colorEffect(ShaderLibrary.heavyFBM(.float2(Float(w*s), Float(h*s)), .float(t)))
 .frame(width: w*s, height: h*s)
 .scaleEffect(1/s, anchor: .topLeading)
 .frame(width: w, height: h, alignment: .topLeading)
```

*Seen in:* DotsAnimation

### MTKView render loop with setVertexBytes uniforms (CPU-driven Metal for particles)

**APIs** — MTKView + MTKViewDelegate.draw(in:); MTLRenderPipelineDescriptor; setVertexBytes(&u, length: stride, index:); drawPrimitives(type:.point, vertexCount:); UIViewRepresentable + Coordinator; CACurrentMediaTime()

For point-cloud / particle work (tens of thousands of GPU points) .colorEffect is the wrong tool — drop to an MTKView wrapped in UIViewRepresentable. Upload a small (<4KB) uniforms struct each frame with setVertexBytes (matched field-for-field to the MSL struct), avoiding a persistent buffer. The Coordinator holds the renderer; updateUIView pushes new params. Additive blending (.one/.one) accumulates particles into glow.

**Gotcha** — NEEDS-GATING and the worst offender in the corpus: isPaused=false + enableSetNeedsDisplay=false + preferredFramesPerSecond=60 is a FREE-RUNNING 60fps loop that never stops and is not gated on scenePhase — full CPU+GPU drain in the background. Fixes: set isPaused=true on scenePhase change; ring-buffer the touch array (don't insert(at:0)/removeLast per gesture — allocation churn); CACHE the pipeline across param changes (don't rebuild the MTKView via .id(effect)).

```swift
func draw(in view: MTKView) {
 guard let rpd = view.currentRenderPassDescriptor, let dr = view.currentDrawable,
    let cmd = queue.makeCommandBuffer(),
    let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }
 var u = Uniforms(time: Float(CACurrentMediaTime() - start), aspect: aspect)
 enc.setRenderPipelineState(pipe)         // pipeline cached, not rebuilt
 enc.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
 enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 150_000)
 enc.endEncoding(); cmd.present(dr); cmd.commit()
} // set view.isPaused = true on scenePhase != .active
```

*Seen in:* 01Metal

## Liquid Glass & iOS 26 system UI

iOS 26's native .glassEffect samples the live backdrop on the GPU — it is cheap and does NOT snapshot the view hierarchy. That single fact retires the entire pre-26 'fake glass' approach (UIGraphicsImageRenderer snapshot + MPSImageGaussianBlur per frame over scrolling content), which was the canonical CPU/GPU trap. Default to native glassEffect on iOS 26; treat the hand-rolled SDF shader and snapshot route as conceptual reference / pre-26 fallback only, and always provide a non-26 RoundedRectangle/.ultraThinMaterial fallback.

### GlassEffectContainer for fluid merge of multiple glass shapes

**APIs** — GlassEffectContainer(spacing:); .glassEffect(.regular.interactive(), in: .capsule); .glassEffect(_:in:) with explicit shape

Wrap two or more glass elements in one GlassEffectContainer so the system renders a single shared glass layer: when shapes approach within `spacing`, their highlights/refraction blend instead of compositing independently. Each child gets .glassEffect(.regular.interactive(), in: <shape>); .interactive() adds touch-tracking specular response. This is what makes a custom tab bar read as native Liquid Glass rather than N separate frosted pills.

**Gotcha** — The native glassEffect samples the real backdrop on the GPU — cheap, no hierarchy snapshot. Keep any .animation(value:) on the container keyed to a SCALAR/enum (activeTab), never a per-frame continuous binding, or the glass relights every frame. Don't wrap the bar in a GeometryReader just to read size (invalidates layout on every parent change) — use onGeometryChange. Don't lay glass as a material over moving scroll content — keep it on the bar.

```swift
GlassEffectContainer(spacing: 10) {
 HStack(spacing: 10) {
  tabPills.glassEffect(.regular.interactive(), in: .capsule)
  actionButton.frame(width: 55, height: 55)
   .glassEffect(.regular.interactive(), in: .capsule)
 }
}
.animation(.smooth(duration: 0.55), value: activeTab) // scalar trigger only
```

*Seen in:* Custom Glass Tab Bar; Morphing Tab Bar Effect; FXTabbar; CXTabBar

### Morph-from-a-pill (Dynamic-Island-style expand) via Animatable + GlassEffectContainer

**APIs** — struct: View, Animatable; animatableData progress; GlassEffectContainer; .glassEffect(in: .rect(cornerRadius:)); compositingGroup(); anisotropic scaleEffect(x:y:anchor:); onGeometryChange

Drive ONE progress: CGFloat (01) through animatableData so SwiftUI interpolates it frame-accurately with whatever spring you pass to withAnimation. Inside a GlassEffectContainer, cross-fade the collapsed label and expanded content (each compositingGroup'd, blurred/faded on a staggered curve) while growing the clip frame from label size toward measured content size. An anisotropic scaleEffect (x slightly <1, y slightly >1 near mid-progress) gives the 'liquid stretch' that reads as the glass extruding from the pill.

**Gotcha** — This is the honest, CPU-friendly island morph: time is NOT free-running — it is bound to a finite spring driven by a state change, so it settles and stops (no repeatForever, nothing to gate on scenePhase). The blurProgress is a 00.50 hump so blur applies only mid-transition, never at rest (a resting blur over scrolling content is the expensive case). onGeometryChange measures content size, so content must render once off-screen — keep it cheap.

```swift
struct Morph: View, Animatable {
 var progress: CGFloat
 var animatableData: CGFloat { get { progress } set { progress = newValue } }
 var blur: CGFloat { progress > 0.5 ? (1-progress)/0.5 : progress/0.5 } // 010 hump
 var body: some View {
  GlassEffectContainer {
   content.opacity(progress).blur(radius: 14*blur)
    .frame(width: w(progress), height: h(progress))
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 30))
  }
  .scaleEffect(x: 1-blur*0.35, y: 1+blur*0.45, anchor: .bottomTrailing)
 }
}
```

*Seen in:* Glass Menu Effect; Morphing Tab Bar Effect

### Superellipse SDF + gradient refraction (the math behind Apple glass) — reference / pre-26 only

**APIs** — box/superellipse signed-distance field; refraction offset via dfdx/dfdy SDF gradient; rim highlight; tint + specular veil; knobs blur/spacing/bezelWidth/tint/specularOpacity/cornerSmoothing≈0.6

Compute a box SDF (Apple uses a superellipse / smooth-corner exponent, not a plain circle radius). Sample the backdrop inside, push the sample UV along the SDF gradient near the edge to fake refraction, and use the same gradient for a directional rim highlight; finish with a tint + faint cool veil so the glass has body. Useful as the conceptual model of what native glass does.

**Gotcha** — GPU-only and per-fragment — do NOT reimplement on the CPU. On iOS 26 you almost never need this: native .glassEffect already does superellipse SDF + refraction and samples the live backdrop for free. Hand-rolling it means you ALSO own the backdrop-capture problem, which is where the real cost lives. Treat as conceptual reference / pre-26 fallback only; on iOS 26 use the native modifier and skip the shader.

```swift
float boxSDF(float2 p, float2 size, float r){
 float2 q = abs(p) - size*0.5 + r;
 return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r;
}
float2 refract(float sdf){
 float2 g = float2(dfdx(sdf), dfdy(sdf));
 return (g / max(length(g),1e-4)) * (pow(abs(sdf),10.0) * -0.16);
}
```

*Seen in:* glass-27-from-island; LiquidGlass-main

### Snapshot-update-mode knob for backdrop-sampling glass (pre-26 fallback only)

**APIs** — enum SnapshotUpdateMode { case continuous(interval:) / once / manual }; UIGraphicsImageRenderer snapshot + MPSImageGaussianBlur; MTKView.enableSetNeedsDisplay = true

If you MUST fake glass by snapshotting the view behind it (pre-26, no native backdrop access), the only thing that decides shippability is how often you re-snapshot. Default to .once (snapshot once, reuse — static cards) or .manual (re-snapshot on invalidate()); fall to .continuous ONLY for genuinely moving backdrops, with the lowest interval tolerable. Use MTKView.enableSetNeedsDisplay so it draws on demand, not every vsync.

**Gotcha** — The default .continuous() re-renders the ENTIRE ancestor hierarchy into a UIGraphicsImageRenderer AND runs an MPS Gaussian blur EVERY tick — the textbook 'material over scrolling content' cost. Hoist the MPSImageGaussianBlur out of the draw path (create once, reuse — don't alloc per frame). On iOS 26 DELETE this whole mechanism and use native .glassEffect. (One corpus sample even mislabels a 1/120s interval as '20 FPS' — a hidden 6x cost; never trust the comment, read the number.)

```swift
enum SnapshotUpdateMode { case continuous(interval: TimeInterval = 1/20), once, manual }
// Prefer .once for static cards. .continuous re-snapshots + re-blurs the whole
// ancestor hierarchy every tick — the material-over-scroll trap.
view.enableSetNeedsDisplay = true      // draw on demand
// hoist the blur — create ONCE, never per frame
let blur = MPSImageGaussianBlur(device: dev, sigma: r)
```

*Seen in:* LiquidGlass-main

### Visibility-gated single-frame render loop (dirty-flag, never free-running) — the mental template

**APIs** — render trigger guarded by visibility + a `frame` dirty flag; only real events (pointer/resize/visibility) request a frame

Keep a single in-flight frame token and a requestRender() that early-returns if disposed, off-screen, or a frame is already queued. Render ONLY on real events (input, resize, content load, visibility regained). This is the web analogue of the iOS CPU-budget rule and the correct shape to copy: drive glass/loader animation off discrete state + finite springs (like the menu morph), and gate any genuinely continuous TimelineView on scenePhase == .active and on-screen visibility.

**Gotcha** — This is exactly what an ungated TimelineView(.animation) or .repeatForever VIOLATES. Redraw on change + visibility, not on a clock. Apply it as the review lens for any animated glass/loader on iOS.

```swift
// iOS translation of the discipline:
TimelineView(.animation(paused: phase != .active || !isVisible || reduceMotion)) { tl in … }
// or better: drive the morph off a finite withAnimation spring on a state change,
// so it settles and stops — nothing to gate.
```

*Seen in:* glass-27-from-island (web reference); Glass Menu Effect (iOS done right)

## Navigation — tab bars & side bars (iOS 18/26)

The strongest navigation lesson in the corpus: keep the real native TabView for state/deep-links/accessibility and overlay custom chrome, rather than hand-rolling a bar. Reach into private UIKit view hierarchy ONLY behind an availability guard with a functional fallback — it is pervasive in these samples (it already carries if #available(iOS 26) special-cases) and will silently no-op or crash on a future OS.

### Native TabView retained, custom chrome overlaid

**APIs** — TabView(selection:); Tab(value:role:); .toolbarVisibility(.hidden, for: .tabBar); .overlay(alignment: .bottom); .tabViewBottomAccessory; .tabBarMinimizeBehavior(.onScrollDown)

Keep the real TabView for state, deep links and accessibility; hide the system bar per-tab with .toolbarVisibility(.hidden, for: .tabBar) applied INSIDE each tab's content; draw your custom bar in .overlay(alignment: .bottom) bound to the same selection. iOS 26 adds first-class APIs: a .search-role Tab as a FAB, .tabViewBottomAccessory for a now-playing strip, .tabBarMinimizeBehavior(.onScrollDown) for auto-hide on scroll.

**Gotcha** — Hiding must be applied INSIDE each tab's content, not on the TabView, or it won't take. The .search-role-as-FAB trick needs UITabBar.setAnimationsEnabled(false) around the selection bounce-back or you get a flicker — but that is a PROCESS-WIDE flag, so scope it tightly and guarantee the re-enable runs. This preserves VoiceOver/Dynamic-Type — far safer than a fully hand-rolled bar for a shipping privacy/medical app.

```swift
TabView(selection: $tab) {
 Tab(value: .home) { Home().toolbarVisibility(.hidden, for: .tabBar) }
}
.tabBarMinimizeBehavior(.onScrollDown)
.overlay(alignment: .bottom) { CustomBar(selection: $tab) }
```

*Seen in:* FXTabbar; CXTabBar

### AnyLayout container swap for tab-bar / search-field morphing

**APIs** — AnyLayout, HStackLayout/ZStackLayout, .animation(_:value:), .geometryGroup()

Hold ONE child set and swap only the layout container: let layout = morphed ? AnyLayout(HStackLayout()) : AnyLayout(ZStackLayout()). Because identity is preserved across the swap, SwiftUI animates each child's frame between arrangements automatically. Used to morph a pill tab bar into a FAB row, and a search field into a compose box.

**Gotcha** — Children that change size during the swap jitter unless you wrap the morphing region in .geometryGroup() so frame changes resolve as one unit. Drive it with a SINGLE .animation(_:value:) keyed on the morph Bool, never scattered withAnimation per mutation, or sub-elements desync. Premium feel and CPU is spent only during the transition.

```swift
let layout = expanded ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(ZStackLayout())
layout {
 SearchField()
 ActionButtons().opacity(expanded ? 1 : 0)
}
.geometryGroup()
.animation(.smooth, value: expanded)
```

*Seen in:* FXTabbar; Custom Bottom Bar; sideList

### onGeometryChange / onScrollGeometryChange instead of GeometryReader + PreferenceKey

**APIs** — .onGeometryChange(for:of:action:); .onScrollGeometryChange(for:of:action:); visualEffect(_:)

Read a view's size or a scroll offset with the iOS 18+ closures: .onGeometryChange(for: CGFloat.self){ $0.size.width } action:{ width = $0 } writes state only when the value actually changes; .onScrollGeometryChange feeds a parallax/offset without re-laying-out the tree each frame. You avoid wrapping content in an extra flexible container (GeometryReader changes sizing semantics) and avoid the per-frame preference reduce.

**Gotcha** — These still write @State, so the action closure runs on the layout pass — keep it to a PLAIN assignment (no allocation, no formatting). Even better for crossing-detection: return a Bool from onGeometryChange so the action fires only on the crossing, not every frame (used for 'reveal nav title after hero scrolls past').

```swift
tabBar
 .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewWidth = $0 }
 .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in headerOffset = -y }
```

*Seen in:* Morphing Tab Bar Effect; MTabBar; sideList; SHeaderView; ScrollToolBarEffect Updated

### Scroll-coexisting side menu via UIGestureRecognizerRepresentable + delegate failure

**APIs** — UIGestureRecognizerRepresentable; UIPanGestureRecognizer; UIGestureRecognizerDelegate.gestureRecognizerShouldBegin / shouldBeRequiredToFailBy; .sensoryFeedback

A pure SwiftUI DragGesture on a drawer steals the pan from inner ScrollViews. Bridge a UIKit pan via UIGestureRecognizerRepresentable (iOS 18+): in gestureRecognizerShouldBegin claim only horizontal swipes (abs(velocity.x) > abs(velocity.y)); in shouldBeRequiredToFailBy yield to an inner UIScrollView only when its contentOffset.x <= 0. Progress (0...1) drives offset, opacity, scale, corner radius together.

**Gotcha** — Velocity-based fling completion must run inside withAnimation; the live-drag phase must NOT animate or you get rubber-banding lag. Haptics fire once on a state crossing via a toggled Bool + .sensoryFeedback, not per delta. This is the correct way to do interruptible drawer drag in SwiftUI today — and it also fixes the bug where a SwiftUI DragGesture silently fails to deliver .onEnded after losing the gesture race to a ScrollView.

```swift
func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
 guard let p = g as? UIPanGestureRecognizer else { return false }
 let v = p.velocity(in: p.view)
 return abs(v.x) > abs(v.y) && (v.x > 0 || isExpanded)
}
func gestureRecognizer(_ g: UIGestureRecognizer, shouldBeRequiredToFailBy o: UIGestureRecognizer) -> Bool {
 (o.view as? UIScrollView).map { $0.contentOffset.x <= 0 } ?? false
}
```

*Seen in:* XStyle Side Bar; sideList; AP Transition; Kavsoft Interaction

### Index-staggered reveal via per-row modifier with delayed spring

**APIs** — ViewModifier; .animation(.spring(...).delay(base + i*step), value: isOpen); opacity/offset/blur ramp

A Staggered(index:isOpen:) modifier applies opacity+offset+blur and a spring whose delay is base + index*step, but ONLY when opening (delay 0 on close so it snaps shut). Rows cascade in with no timer or manual sequencing — the delay is encoded per-modifier keyed on isOpen.

**Gotcha** — The delay MUST be asymmetric (0 on collapse) or closing feels sluggish. Blur during the cascade is the costly bit — keep it bounded (≤4pt) and animating to 0 so it's not a sustained cost. Don't apply to a huge ForEach (each row gets its own delayed spring); fine for a menu of ~10 rows. Fully state-driven, cheap at rest — no scheduler.

```swift
func body(content: Content) -> some View {
 content
  .opacity(isOpen ? 1 : 0)
  .offset(y: isOpen ? 0 : 14)
  .blur(radius: isOpen ? 0 : 4)
  .animation(.spring(response: 0.5, dampingFraction: 0.85)
         .delay(isOpen ? 0.12 + Double(index) * 0.045 : 0), value: isOpen)
}
```

*Seen in:* sideList

## Motion, transitions, Dynamic Island & Live Activities (iOS 18/26)

Two non-negotiable rules dominate this theme. (1) For interactive dismiss / drag-coupled-to-scroll, use UIGestureRecognizerRepresentable + a UIGestureRecognizerDelegate — a SwiftUI DragGesture silently fails to fire .onEnded when it loses the race to a ScrollView. (2) For any Live Activity, let the OS advance time natively (Text(timerInterval:)/ProgressView(timerInterval:)) and push Activity.update ONLY on human actions — a per-second update loop burns the ActivityKit budget, drains battery, and dies the instant the app suspends.

### App-Store-style zoom/hero transition via fullScreenCover + visualEffect

**APIs** — .fullScreenCover; onGeometryChange(for: CGRect); visualEffect { content, proxy in }; .mask(RoundedRectangle); withAnimation(_:completionCriteria:.removed); presentationBackground

Capture the source card's global frame with onGeometryChange, present a fullScreenCover, then drive one @State Bool that interpolates the hero's frame/offset/cornerRadius from the captured rect to full-screen. A visualEffect reads scroll-relative minY each frame to pin the hero. Dismiss uses withAnimation(completionCriteria: .removed) so the cover tears down only after the reverse animation completes.

**Gotcha** — Present the cover INSIDE a withoutAnimation transaction (Transaction.disablesAnimations) — presenting animated AND running the hero animation double-animates and stutters. Hide the source view once presented (if !showCover) or you get a ghost duplicate. One-shot, so no scenePhase gating needed. For a plain push-to-detail zoom, prefer the built-in .navigationTransition(.zoom)/.matchedTransitionSource — cheaper and automatically reduce-motion-aware.

```swift
@State private var open = false; @State private var src: CGRect = .zero
MyCard().onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { src = $0 }
 .onTapGesture { var t = Transaction(); t.disablesAnimations = true; withTransaction(t) { open = true } }
 .fullScreenCover(isPresented: $open) {
  Hero().frame(width: expanded ? nil : src.width, height: expanded ? 460 : src.height)
   .task { withAnimation(.smooth(duration: 0.3)) { expanded = true } }
 }
```

*Seen in:* AP Transition

### UIGestureRecognizerRepresentable that coexists with ScrollView (interactive dismiss / bottom sheet)

**APIs** — UIGestureRecognizerRepresentable; UIGestureRecognizerDelegate.gestureRecognizer(_:shouldBeRequiredToFailBy:) / shouldRecognizeSimultaneouslyWith / gestureRecognizerShouldBegin; scrollView.contentOffset

Wrap a raw UIPanGestureRecognizer (iOS 18+) and use the delegate to negotiate with the ScrollView's own pan: shouldBeRequiredToFailBy returns true only when contentOffset.y.rounded() <= 1, so the dismiss pan wins exactly at the top of scroll; gestureRecognizerShouldBegin gates on vertical-dominant velocity or an edge location. The closure forwards translation/velocity/state to @State.

**Gotcha** — This is the robust replacement for SwiftUI's DragGesture, which silently fails to fire .onEnded when it loses to a ScrollView, stranding drag state mid-animation. Cost is a UIKit gesture object, not per-frame work. Use contentOffset.rounded() <= 1 (not == 0) because momentum leaves sub-pixel offsets. Get shouldBeRequiredToFailBy wrong and the sheet either can't scroll or can't dismiss.

```swift
final class C: NSObject, UIGestureRecognizerDelegate {
 func gestureRecognizer(_ g: UIGestureRecognizer, shouldBeRequiredToFailBy o: UIGestureRecognizer) -> Bool {
  (o.view as? UIScrollView).map { $0.contentOffset.y.rounded() <= 1 } ?? false
 }
}
```

*Seen in:* AP Transition; Kavsoft Interaction; Sortable Grid from Kavsoft; Threads Dismiss

### ActivityKit Live Activity where time advances natively (timerInterval)

**APIs** — Text(timerInterval:countsDown:pauseTime:); ProgressView(timerInterval:countsDown:); Activity.update only on human actions; App Group; NSSupportsLiveActivities; interactive Buttons (iOS 17+)

Render the clock with Text(timerInterval:) and the bar with ProgressView(timerInterval:) over the SAME date range so iOS animates both in lock-step on the Lock Screen and Dynamic Island. Push Activity.update ONLY for human actions (pause/resume/stop) — never to move time forward. Pause freezes the clock via Text's pauseTime; on resume, shift the effective start (start = now − elapsed) so both continue seamlessly across backgrounding.

**Gotcha** — THE Live Activity correctness/CPU pattern: time is freezable and frozen by the OS, so it keeps ticking while the app is suspended/killed at ZERO CPU. A per-second Activity.update loop burns the update budget, drains battery, and stops dead on suspension. End leftover activities on launch (getInstances/activities end(.immediate)) or a killed app leaves a zombie banner. The expanded-DI bottom region is height-capped — use compact control sizes or buttons clip.

```swift
Text(timerInterval: start...goal, countsDown: false, pauseTime: isPaused ? pausedAt : nil)
 .monospacedDigit()
ProgressView(timerInterval: start...goal, countsDown: false) // same range lock-step
// On pause/resume only:
activity.update(using: .init(startAt: now - elapsed, isPaused: isPaused))
// On launch: for a in Activity<Attr>.activities { await a.end(dismissalPolicy: .immediate) }
```

*Seen in:* study-timer-live-activities-master

### Gated TimelineView(.animation(paused:)) for an auto-advancing progress indicator

**APIs** — TimelineView(.animation(paused:)); startDate.distance(to: ctx.date) progress; onChange to advance; interpolatingSpring

A story/onboarding paging indicator computes progress = startDate.distance(to: context.date)/duration inside a TimelineView and grows the active capsule. The schedule is .animation(paused:) with the paused flag bound to state, so when paused the timeline stops requesting frames entirely. Reset startDate on selection/pause change to avoid a progress jump.

**Gotcha** — NEEDS-GATING and the right way versus an always-running .animation. The pause binding makes time freezable — but the corpus only binds it to the USER pause; it is NOT gated on scenePhase/visibility, so a mounted-but-offscreen instance keeps ticking. Always fold scenePhase != .active (and ideally on-screen visibility) INTO the paused: flag.

```swift
TimelineView(.animation(paused: isPaused || scenePhase != .active)) { ctx in
 let p = max(min(startDate.distance(to: ctx.date) / duration, 1), 0)
 Rectangle().fill(active).scaleEffect(x: p, anchor: .leading)
  .onChange(of: Int(p)) { _, v in if v == 1 { advance() } }
}
.onChange(of: selection) { _, _ in startDate = .now }
```

*Seen in:* TPIndicators

### Liquid Glass toast queue: @Entry-injected presenter + completionCriteria sequencing

**APIs** — GlassEffectContainer; glassEffect(.regular, in: .capsule); @Entry EnvironmentValues; withAnimation(_:completionCriteria:.logicallyComplete); cancellable DispatchWorkItem; .transition(.offset)

A ToastRootView wraps app content and injects show/dismiss closures through @Entry environment values, so any descendant fires a toast without binding plumbing. Swapping an active toast for a new one uses withAnimation(completionCriteria: .logicallyComplete) to fully retract the old toast before inserting the new one; a cancellable DispatchWorkItem drives auto-dismiss.

**Gotcha** — .logicallyComplete is the key to clean sequential swaps — without it a rapid second toast collides mid-animation. The DispatchWorkItem MUST be cancelled on manual dismiss or a stale timer kills the next toast early. glassEffect/GlassEffectContainer is iOS 26-only — gate with an availability fallback (glassEffect on 26+, stroked material below). Keep the toast a small capsule, not a full-width glass bar over scroll.

```swift
extension EnvironmentValues { @Entry var showToast: (Toast) -> Void = { _ in } }
withAnimation(anim.logicallyComplete(after: 0.17), completionCriteria: .logicallyComplete) {
 active = nil
} completion: {
 work?.cancel(); withAnimation(anim) { active = toast }
 work = .init { dismiss() }; DispatchQueue.main.asyncAfter(deadline: .now()+toast.duration, execute: work!)
}
```

*Seen in:* Kavsoft LGToasts; Permission Animation

### Drag-to-reorder grid: overlay preview + cached-frame coordinate-space hit testing

**APIs** — UILongPressGestureRecognizer via UIGestureRecognizerRepresentable; coordinateSpace(.named:); onGeometryChange(for: CGRect) to cache cell frames; rect.contains(location) swap; withAnimation(completionCriteria:.logicallyComplete); swapLock

Each cell records its frame in a named coordinate space; a long-press recognizer (translation derived by storing the first touch — no second pan gesture) lifts a floating preview. On drag, find the destination by which cached rect contains the finger, then remove/insert swap under a snappy animation. A swapLock + next-runloop reset prevents thrashing when crossing cells fast.

**Gotcha** — Caching frames via onGeometryChange (not a per-frame GeometryReader behind each cell) is what keeps this cheap. The swapLock is essential — without it a fast drag fires multiple reorders in one frame and the array desyncs from the layout. allowsHitTesting(false) on the preview and (draggingItem == nil) on the grid stop the lifted item intercepting its own hit test. Convert the long-press location to the named space via context.converter or hit detection is offset.

```swift
cell.onGeometryChange(for: CGRect.self) { $0.frame(in: .named("GRID")) } action: { item.position = $0 }
if let dst = items.firstIndex(where: { $0.position.contains(location) }), dst != src, !swapLock {
 swapLock = true
 withAnimation(.snappy(duration: 0.25)) { let m = items.remove(at: src); items.insert(m, at: dst) }
 DispatchQueue.main.async { swapLock = false }
}
```

*Seen in:* Sortable Grid from Kavsoft

## Components & flows — onboarding, StoreKit 2 paywall, scroll-driven effects

The headline reusable wins: let StoreKit 2's SubscriptionStoreView render all commerce (you own only marketing + gating) and ALWAYS verify the VerificationResult before unlocking; build onboarding reveals as one-shot .task cascades (cheap, freezable) not repeating timelines; and replace every per-frame GeometryReader+PreferenceKey scroll pipeline with onScrollGeometryChange. The cautionary counter-example in the corpus (a 2021 sample leaning on SwiftUIX/Introspect and UIScreen.main.bounds) is fully replaceable with native iOS 18/26 APIs — do not adopt it.

### Declarative onboarding via @resultBuilder + staggered one-shot blur-slide reveal

**APIs** — @resultBuilder; @ViewBuilder; .task with Task.sleep(for:) sequencing withAnimation(.smooth); .compositingGroup()+.blur+.offset; .allowsHitTesting(gateFlag); .presentationSizing(.fitted); .interactiveDismissDisabled()

The onboarding card is a generic struct whose feature cards come through a custom @resultBuilder, so call sites read as a DSL. A single .task awaits short Task.sleep gaps and flips per-element @State bools inside withAnimation, producing a staggered cascade. Each element shares one reusable .blurSlide(show:) modifier compositing blur+opacity+offset together.

**Gotcha** — The reveal is a ONE-SHOT driven by .task (guard !animateIcon), NOT a repeating timeline — it costs nothing after first paint (freezable by construction). Two correctness wins to copy: .compositingGroup() BEFORE .blur so the blur hits the flattened layer once instead of per child node; .allowsHitTesting(animateFooter) so taps are dead until the button has animated in. Size animateCards from cards.count or an index mismatch crashes.

```swift
extension View { func blurSlide(_ s: Bool) -> some View {
 compositingGroup().blur(radius: s ? 0 : 10).opacity(s ? 1 : 0).offset(y: s ? 0 : 60) } }
.task { for i in items.indices {
 try? await Task.sleep(for: .seconds(0.1))
 withAnimation(.smooth) { shown[i] = true } } }
.allowsHitTesting(shown.last == true)
```

*Seen in:* Kavsoft Onboarding; iOSStyleOnBoarding Updated

### StoreKit 2 declarative paywall (SubscriptionStoreView) with mandatory verification

**APIs** — SubscriptionStoreView(productIDs:marketingContent:); SubscriptionStoreControlStyle; .subscriptionStoreControlStyle(_:placement:); .storeButton(.visible,for:.restorePurchases); .onInAppPurchaseCompletion; .subscriptionStatusTask(for:)

Let StoreKit render the entire commerce surface — products, prices, intro offers, buy button — from productIDs; no manual Product fetch/pricing/localization. A custom SubscriptionStoreControlStyle swaps a compact picker on small iPhones for a paged-prominent picker otherwise. You own ONLY the marketing header and the gating logic.

**Gotcha** — VERIFY before unlocking: .onInAppPurchaseCompletion hands you a VerificationResult — check the .verified case before granting entitlement; do not treat the callback as truth (a corpus sample prints a TODO instead of verifying). Derive entitlement truth from .subscriptionStatusTask / Transaction.currentEntitlements, not the purchase callback alone. .storeButton(.visible, for: .restorePurchases) is required by App Review; make Terms/Privacy links point at real URLs.

```swift
SubscriptionStoreView(productIDs: ids) { MarketingHeader() }
 .subscriptionStoreControlStyle(.prominentPicker, placement: .scrollView)
 .storeButton(.visible, for: .restorePurchases)
 .onInAppPurchaseCompletion { _, result in
  if case .success(.success(let v)) = result, case .verified = v { unlock() }
 }
 .subscriptionStatusTask(for: groupID) { status in /* source of truth */ }
```

*Seen in:* PayWall StoreKit Updated

### Direction-aware collapsing header via onScrollGeometryChange + onScrollPhaseChange

**APIs** — ScrollView extension + ViewModifier; .safeAreaInset(edge:.top); .onScrollGeometryChange(for: CGFloat){ contentOffset.y + contentInsets.top }; .onScrollPhaseChange { phase }; computed progress + withAnimation snap

A reusable .scrollableHeader(dismissDistance:) installs the header in a top safeAreaInset and translates/fades it by a 0...1 progress computed from onScrollGeometryChange deltas — but only while scrollPhase == .interacting (so momentum doesn't move it). On phase end, snap to fully shown/hidden with a spring and rebaseline an anchor so the next drag starts from the current position.

**Gotcha** — This is the modern replacement for a per-frame GeometryReader+PreferenceKey header — onScrollGeometryChange fires on the scroll system's cadence and returns a tiny Equatable, no preference-key tree walk, no layout thrash. Read contentOffset.y + contentInsets.top (NOT raw offset) and gate updates on the .interacting phase, or the header jitters during deceleration. compositingGroup() keeps the fade flattened.

```swift
.onScrollGeometryChange(for: CGFloat.self) {
  min($0.contentOffset.y + $0.contentInsets.top, $0.contentSize.height - $0.containerSize.height)
 } action: { old, new in if phase == .interacting { progress = max(min((new - anchor)/dist, 1), 0) } }
.onScrollPhaseChange { _, p in phase = p
  if p != .interacting { withAnimation { progress = progress > 0.5 ? 1 : 0 } } }
```

*Seen in:* SHeaderView; ScrollToolBarEffect Updated

### Bidirectional infinite scroll with velocity-preserving offset compensation

**APIs** — ScrollView + .scrollPosition($pos); .defaultScrollAnchor(.center); .onScrollGeometryChange(for: Equatable); pos.scrollTo(y:) inside withTransaction { scrollPositionUpdatePreservesVelocity = true }

Keep a window of ~30 fixed-height items: when the user nears either end, prepend/append a batch and trim an equal batch from the far end. To hide the splice, recompute the content offset from the height delta and apply it via pos.scrollTo(y:) inside a Transaction with scrollPositionUpdatePreservesVelocity = true, so a flick keeps flowing through the splice.

**Gotcha** — Reset the load flags in the NEXT runloop (DispatchQueue.main.async), not synchronously — otherwise the geometry change re-fires and spawns an infinite create loop. The offset math requires FIXED-height rows; variable heights break it. Disabling scrollsToTop reaches into UIKit (depends on subview ordering) — isolate it as an easily-removed opt-out, never load-bearing.

```swift
.onScrollGeometryChange(for: Info.self) { Info($0) } action: { _, v in
 if v.offsetY < 100, !loadingTop { prepend(); compensate(v) } }
func compensate(_ v: Info) {
 var t = Transaction(); t.scrollPositionUpdatePreservesVelocity = true
 withTransaction(t) { pos.scrollTo(y: v.offsetY + addedHeight) }
 DispatchQueue.main.async { loadingTop = false } }
```

*Seen in:* iOS Calendar Scroll View

### Looping card stack via Group(subviews:) + array rotation + completion-criteria animation

**APIs** — Group(subviews: content) (SubviewsCollection); array rotate; .zIndex; .rotation3DEffect(perspective:); DragGesture velocity; withAnimation(...logicallyComplete(after:), completionCriteria:.logicallyComplete){}completion:{}

Decompose passed-in children with Group(subviews:) into a SubviewsCollection, then logically rotate by an Int so swiping the front card 'sends it to the back' without reordering data. Each card derives offset/scale from its index and a 3D Y-rotation from live drag. On release, velocity decides completion; the top card animates out and ONLY in the animation's completion does rotation increment + offset reset, so the z-index swap is invisible.

**Gotcha** — The two-phase animation (logicallyComplete(after:) + completion handler) is what hides the z-index pop — doing the rotation increment synchronously would flash the card jumping behind. Enable the gesture only for index==0 && count>1 so only the front card hit-tests. All state/gesture-driven, nothing repeats — cheap at rest. viewSize comes from onGeometryChange, so a zero first-frame size makes swipe math degenerate until measured.

```swift
Group(subviews: content) { col in
 let cards = col.rotateFromLeft(by: rotation)
 ZStack { ForEach(cards) { v in Card(v).zIndex(Double(cards.count - cards.index(v))) } } }
withAnimation(.smooth.logicallyComplete(after: 0.15), completionCriteria: .logicallyComplete) {
 offset = -width } completion: { rotation += 1; offset = 0 }
```

*Seen in:* Pro Max Flash Cards

## On-device inference — quick how-to

On-device inference with Apple's FoundationModels (iOS 26+, M1-class hardware with Apple Intelligence). 1) GATE FIRST: switch on SystemLanguageModel.default.availability and branch the whole view — .available your AI surface; each .unavailable(reason) a distinct ContentUnavailableView (.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady), plus @unknown default. availability is a cheap synchronous read but changes at runtime, so re-read it; never cache at launch. 2) SESSION: let session = LanguageModelSession(instructions: \"…\"); optionally session.prewarm(promptPrefix:) but ONLY on a concrete intent signal (field focus, mic tap) — never at launch or per route (it loads the model and costs memory/energy). 3) STRUCTURED OUTPUT is the safe path: annotate a Sendable struct/enum with @Generable, each field with @Guide(description: \"…\") (on the PROPERTY, not @Guide(\"…\") on the type) and constraints like .count(1...3); call try await session.respond(to:generating: T.self).content for a typed value — no JSON, no regex. Closed @Generable enums give robust, hallucination-proof classification (critical for medical). 4) STREAMING: for await snap in session.streamResponse(to:) yields CUMULATIVE snapshots — output = snap.content (assign, never append); drive from a cancellable Task and guard !Task.isCancelled before committing; keep the per-snapshot body cheap (no .animation(value:)/.drawingGroup() on the live Text). 5) OPTIONS: GenerationOptions(sampling: .greedy, temperature: 0.1) for extraction/classification/auditable output (temperature is ignored under .greedy); .random(probabilityThreshold: 0.9, …) with a seed for reproducible creative copy; cap with maximumResponseTokens. 6) ERRORS: catch specific GenerationError cases via one shared handler — on .decodingFailure retry ONCE with a stricter prompt + temperature 0; .refusal is async-throwing and a normal outcome; do NOT retry .guardrailViolation or .exceededContextWindowSize with the same input; always @unknown default. 7) TOOLS: conform to Tool with a typed @Generable Arguments struct and func call(arguments:) (not call(with:)); expose only the narrow consented data slice (never a full private dataset); for any WRITE, draft-then-confirm (model emits a @Generable draft, you commit only after explicit user confirmation). Attaching tools disables context-window auto-trimming, so budget context manually. 8) LONG CHATS: proactively rebuild the session from Transcript(entries:) within a token budget (read model.contextSize, not a magic 4096), with a .exceededContextWindowSize backstop that summarizes via a throwaway session. 9) PRIVACY: default everything on-device; offer Private Cloud Compute ONLY as an explicit, labeled opt-in gated behind #if compiler(>=6.4) + #available(iOS 27, *), checking PrivateCloudComputeLanguageModel().isAvailable && !quotaUsage.isLimitReached — never a silent fallback. Validate any new prompt or @Generable schema in an Xcode #Playground {} before wiring it into a ViewModel.

