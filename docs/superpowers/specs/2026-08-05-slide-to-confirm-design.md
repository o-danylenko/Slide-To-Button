# Slide-to-confirm: clean layered rebuild

Date: 2026-08-05

## Goal

Rebuild the slide-to-confirm control with one purpose per type: an explicit input state
machine, pure geometry, one thin control that owns interaction, and a paint layer that
structurally cannot touch the gesture.

Behaviour stays what it is today — a one-shot latching swipe that fires a `() -> Void`
action. This is a restructuring, not a redesign.

Supersedes and replaces the earlier `2026-08-05-swipe-to-confirm-simplification-design.md`,
which targeted a parameter-stripping pass on the existing `PrimitiveButtonStyle` shape.
That target changed.

## Problem with the current shape

Four files, and the interaction is spread across three of them.

`SwipeToConfirmTrack` owns the gesture, the input state, the geometry wiring, the layout,
*and* the paint. That is a consequence of `PrimitiveButtonStyle`: in that model the style
owns the gesture, so a second look would have to re-implement the drag.

Concretely:

- `@GestureState translation: CGFloat?` and `@State isConfirmed: Bool` are four
  combinations, and `(translation: x, isConfirmed: true)` is reachable — the action fires
  while the finger is still down. Nothing is broken, but the precedence is implicit and
  re-derived in three places: `travel`'s guard order, `isActive`, and `body`'s opacity.
  There is no single named state.
- `handle` is generic, so it infects two types and forces two factory extensions —
  `where Self == ...` does not compose with a generic default.
- `SwipeDragManager` mixes pure arithmetic with input flags (`isTouching`, `isActive`).
- `View+OnSizeChange.swift` is 43 lines of plumbing for a size that a layout-neutral
  `GeometryReader` in `.overlay`/`.background` provides directly.

Nothing outside `SwipeToConfirm/` references any of it. No call sites to migrate.

## Design rationale

Six sources converge on the same three-part structure for a drag-driven widget. Each maps
onto exactly one file below.

**Input is a state machine, not booleans.** Buxton's three-state model of graphical input
(INTERACT '90) — out of range, tracking, dragging — with the observation that a
touchscreen has no tracking state. That absence is why the control needs a visible handle:
it is the design compensation for a state the device cannot express. Olsen's *Developing
User Interfaces* (1998) separates the *input* machine from application semantics; GoF's
State pattern gives the shape. `translation` is input state; `isConfirmed` is application
semantics. One derived enum names the combination.

**Behaviour is a separate object from appearance.** Myers, "A New Model for Handling
Input" (ACM TOIS 8(3), 1990) — the Interactor model. Myers' argument is that welding
behaviour to graphics forces every widget to re-implement its own input handling, and his
`move-grow-interactor` *is* the slider abstraction: a slider is not a kind of widget, it is
a behaviour bound to some graphics. This is precisely the `ButtonStyle` versus
`PrimitiveButtonStyle` fork, and the current code is on the wrong side of it. GoF, same
conclusion: "Favor object composition over class inheritance."

**Geometry is a Presentation Model.** Fowler — represent the state and behaviour of the
presentation independently of the GUI controls used. `SwipeDragManager` already is this and
is the healthiest existing file. Fowler is explicit that this layer holds *presentation*
state, not input plumbing, so `isTouching`/`isActive` move out.

**The paint layer holds no logic.** Meszaros' Humble Object (*xUnit Test Patterns*, 2007)
and Fowler's Passive View — no logic in the view means nothing in it to test. A paint type
with no `@State`, no `@GestureState`, and no gesture cannot regress the drag.

**Direct manipulation sets a correctness constraint.** Shneiderman's requirements —
continuous representation of the object, and immediately visible effect — are why the
handle must be offset rather than reframed, and why the travel offset must stay outside any
`withAnimation` scope. Interpolating the handle breaks 1:1 finger coupling. These two
decisions in the current code are already textbook-correct and are preserved verbatim.

Not applicable, stated to avoid confusion: classic MVC's Controller does not map onto
SwiftUI. MVC's controller exists to push updates into a passive view; SwiftUI owns update
propagation, so re-render is a pure function of state. Structurally this is MVU.

### Why no style protocol

A protocol (`SlideStyle` + `SlideStyleConfiguration` + `AnySlideStyle` eraser +
`EnvironmentKey` + `.automatic` default + modifier) buys exactly one capability a plain
type does not: cascading through the environment into a hierarchy you do not own.

One app, one control, one look. That capability is unused, and the infrastructure is
roughly 50 lines serving one implementation. The separation asked for comes from types with
one purpose each, not from a protocol.

If a second look appears, extracting the protocol is a mechanical refactor — the
`SlideTrack` boundary is already the `Configuration` boundary.

## Files

Five files. `SwipeDragManager.swift`, `SwipeToConfirmTrack.swift`,
`SwipeToConfirmStyle.swift`, and `View+OnSizeChange.swift` are all deleted.

The Xcode project uses a `PBXFileSystemSynchronizedRootGroup`, so adding and removing
source files requires no `project.pbxproj` edits.

| File | Single purpose | Imports |
| --- | --- | --- |
| `SlideState.swift` | the machine and its threshold policy | none |
| `SlideGeometry.swift` | points ↔ progress | none |
| `SlideToConfirm.swift` | gesture and storage (Myers' interactor) | `SwiftUI` |
| `SlideTrack.swift` | paint (Passive View) | `SwiftUI` |
| `SlideToConfirmStyle.swift` | style adapter and factory | `SwiftUI` |

`CGFloat` is used throughout, including for progress. It is declared in CoreFoundation
(`CFCGTypes.h:45`, `typedef CGFLOAT_TYPE CGFloat`) and re-exported by the Swift standard
library, so neither `SlideState` nor `SlideGeometry` needs an import. One numeric type
means no mixed arithmetic and no conversions.

### `SlideState.swift`

Reasons in progress rather than points, so the machine is resolution-independent and
testable with no size involved.

```swift
enum SlideState: Equatable {
    case idle
    case sliding(progress: CGFloat)
    case confirmed

    /// The fraction of the travel range past which the swipe confirms.
    static let threshold: CGFloat = 0.8

    /// The only place a drag event acquires meaning.
    ///
    /// Total, and `confirmed` absorbs — so the precedence of a latched confirm over a
    /// live finger is stated once here rather than re-derived at each read.
    func applying(progress: CGFloat) -> SlideState {
        switch self {
        case .confirmed:
            .confirmed
        case .idle, .sliding:
            progress >= Self.threshold ? .confirmed : .sliding(progress: progress)
        }
    }

    var progress: CGFloat {
        switch self {
        case .idle: 0
        case .sliding(let progress): progress
        case .confirmed: 1
        }
    }
}
```

There is deliberately no `released` event or case. Release-to-idle is implemented by
`@GestureState`'s automatic reset, not by this function; a case never reached would be dead
code.

### `SlideGeometry.swift`

Pure arithmetic. Sizes are derived, never declared: the track's height comes from its
label, the handle is a circle inset into that height, and the travel range follows from
both.

```swift
struct SlideGeometry: Equatable {
    let trackSize: CGSize
    let inset: CGFloat

    var handleDiameter: CGFloat { max(0, trackSize.height - inset * 2) }

    /// Clamped at zero, so a track narrower than its handle — or one not yet measured —
    /// cannot produce a negative range.
    var maxTravel: CGFloat { max(0, trackSize.width - handleDiameter - inset * 2) }

    /// Zero when there is no room to travel, so this never divides by zero.
    func progress(forTranslation translation: CGFloat) -> CGFloat {
        guard maxTravel > 0 else { return 0 }
        return min(max(0, translation), maxTravel) / maxTravel
    }

    func travel(at progress: CGFloat) -> CGFloat { maxTravel * progress }

    /// Where the handle sits. One definition, consumed by both the paint layer and the
    /// hit region, so they cannot drift apart.
    func handleOffset(at progress: CGFloat) -> CGSize {
        CGSize(width: inset + travel(at: progress), height: inset)
    }

    /// How far the progress fill must be pushed to sit flush with the leading edge.
    ///
    /// The fill is a full-width capsule shifted left, so revealing it costs a render
    /// transform rather than a layout pass. It ends two insets past the handle.
    func fillOffset(at progress: CGFloat) -> CGFloat {
        inset * 3 + handleDiameter + travel(at: progress) - trackSize.width
    }
}
```

### `SlideToConfirm.swift`

The only type that touches the gesture. Thin: it wires, it does not decide.

Two storage slots, one authoritative state:

```swift
@Environment(\.isEnabled) private var isEnabled
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@ScaledMetric(relativeTo: .headline) private var inset: CGFloat = 4

/// The finger's progress along the track, or `nil` when nothing is touching.
///
/// `GestureState` resets on cancellation as well as on lift — unlike `onEnded`, which
/// never fires when the system claims the gesture — and `resetTransaction` gives the
/// snap-back its spring, keeping animation off the drag path.
@GestureState(resetTransaction: Transaction(animation: .slideSnapBack))
private var slideProgress: CGFloat?

/// Latched: the only state that outlives the gesture.
@State private var isConfirmed = false

/// Precedence stated once; every reader downstream sees one value.
private var state: SlideState {
    if isConfirmed { return .confirmed }
    if let slideProgress { return .sliding(progress: slideProgress) }
    return .idle
}
```

Both slots are kept deliberately. `@GestureState`'s reset covers system cancellation, where
`onEnded` does not fire; `@State` is needed because the latch must outlive the gesture. The
derived enum is what removes the four-combination ambiguity, not collapsing the storage.

Body — the hit region is the handle only, placed by the same `handleOffset` the paint layer
uses:

```swift
SlideTrack(label: label, state: state, inset: inset)
    .opacity(isEnabled ? 1 : 0.5)
    .overlay(alignment: .topLeading) {
        GeometryReader { proxy in
            let geometry = SlideGeometry(trackSize: proxy.size, inset: inset)
            Color.clear
                .frame(width: geometry.handleDiameter, height: geometry.handleDiameter)
                .contentShape(.circle)
                .offset(geometry.handleOffset(at: state.progress))
                // High priority keeps an enclosing scroll view or sheet from claiming
                // the touch first.
                .highPriorityGesture(drag(in: geometry), including: isEnabled ? .all : .none)
        }
    }
    .accessibilityRepresentation {
        // VoiceOver cannot drag a handle, so it gets a plain button.
        Button(action: action) { label }
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: slideProgress != nil) { _, t in t }
    .sensoryFeedback(.success, trigger: isConfirmed) { _, confirmed in confirmed }
```

`GeometryReader` in `.overlay` is proposed the size layout already decided for its parent,
so it neither expands greedily nor re-runs layout for real content. It replaces
`View+OnSizeChange.swift` outright, along with the `@State` size, the `PreferenceKey`, the
`#available(iOS 18)` branch, and the zero-size first frame.

Gesture — the threshold crossing is caught in the event that produced it, not a render pass
later:

```swift
private func drag(in geometry: SlideGeometry) -> some Gesture {
    DragGesture(minimumDistance: 0)
        .updating($slideProgress) { value, slideProgress, _ in
            slideProgress = geometry.progress(forTranslation: value.translation.width)
        }
        .onChanged { value in
            let progress = geometry.progress(forTranslation: value.translation.width)
            guard state.applying(progress: progress) == .confirmed, !isConfirmed else {
                return
            }
            confirm()
        }
}

private func confirm() {
    guard !reduceMotion else {
        isConfirmed = true
        action()
        return
    }
    withAnimation(.slideConfirm) { isConfirmed = true } completion: { action() }
}
```

### `SlideTrack.swift`

Paint only. No `@State`, no `@GestureState`, no gesture — so no styling change can regress
the drag. That guarantee comes from the shape of the type.

```swift
struct SlideTrack<Label: View>: View {
    let label: Label
    let state: SlideState
    let inset: CGFloat
}
```

Structure, unchanged from the current track: the label is flanked by two hidden square
footprints, which is what makes the control self-sizing — they establish the track's height
and the lane the centred label must keep clear, from one rule rather than two constants
that could drift.

The fill sits behind the label and the handle in front of it, or the label paints over the
handle.

```swift
labelRow
    .opacity(state == .confirmed ? 0 : 1)
    .background(.quaternary)
    .background { GeometryReader { progressFill(in: geometry(for: $0.size)) } }
    .clipShape(.capsule)
    .overlay(alignment: .topLeading) { GeometryReader { handle(in: geometry(for: $0.size)) } }
```

Palette — semantic, adapts to light and dark, no literal colours:

| Element | Value |
| --- | --- |
| Track background | `.quaternary` |
| Progress fill | `Color.accentColor.opacity(0.24)` |
| Handle | `Color.accentColor` |
| Chevron | `.white`, `.title3.weight(.bold)` |

Two decisions preserved verbatim from the current implementation, for the reason given
under Shneiderman above:

- Everything that moves is an `offset`, never a `frame` — a render transform, not a layout
  pass.
- The travel offset sits outside the press-scale `animation` scope, so travel tracks the
  finger with no interpolation.

Animations stay as they are:

```swift
extension Animation {
    static let slideSnapBack = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let slideConfirm = Animation.spring(response: 0.3, dampingFraction: 0.6)
}
```

### `SlideToConfirmStyle.swift`

The `Button` entry point, kept as a thin adapter so `.buttonStyle(.slideToConfirm)` still
works. No generic, no stored properties, one factory.

```swift
struct SlideToConfirmStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SlideToConfirm(action: configuration.trigger) { configuration.label }
    }
}

extension PrimitiveButtonStyle where Self == SlideToConfirmStyle {
    static var slideToConfirm: Self { SlideToConfirmStyle() }
}
```

`PrimitiveButtonStyle` survives only here, as a five-line adapter over the real control.
The interaction lives in `SlideToConfirm` and is written once.

### `ContentView.swift`

Reduced to the control and a counter. The existing `Mode` enum, segmented picker, threshold
slider, auto-reset `Task`, and `@ViewBuilder label` all go: the slider drove a parameter
that no longer exists, and the spinner branch drove a `handle` parameter that no longer
exists.

```swift
struct ContentView: View {
    @State private var confirmations = 0

    var body: some View {
        VStack(spacing: 32) {
            SlideToConfirm { confirmations += 1 } label: {
                Text("Slide to Confirm").font(.headline)
            }

            Text("Confirmed \(confirmations)×")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview { ContentView() }
```

`#Preview { ContentView() }` is the only preview in the project. The four previews
currently in `SwipeToConfirmStyle.swift` are deleted.

## Behaviour parity

Preserved exactly:

- One-shot latching confirm firing a `() -> Void` action, no progress in the callback
- Threshold checked inside `onChanged`, in the event that produced the crossing
- Snap-back spring via `resetTransaction`; confirm spring via `withAnimation` completion
- The `accessibilityReduceMotion` path, which skips animation and fires immediately
- `accessibilityRepresentation` substituting a plain `Button` for VoiceOver
- Both `sensoryFeedback` triggers — impact on touch down, success on confirm
- `.disabled(_:)` dimming to 0.5 and dropping the gesture
- Self-sizing to the label, so Dynamic Type and multi-line copy grow the track
- `@ScaledMetric` inset
- Handle-only hit target, roughly 44pt at headline size

Changed:

- Entry point gains `SlideToConfirm` as a first-class control;
  `.buttonStyle(.slideToConfirm)` still works via the adapter
- `handle`, `tint`, and `threshold` parameters removed; threshold becomes
  `SlideState.threshold`
- Palette moves to `.quaternary` plus `Color.accentColor`

## Testing

The two pure types carry all the logic and need no host app. Cases with real branching:

**`SlideState`**

1. `.idle.applying(progress:)` below threshold gives `.sliding`; at or above gives
   `.confirmed`
2. Boundary: exactly `threshold` confirms; just below does not
3. `.confirmed.applying(progress: 0)` stays `.confirmed` — the absorbing property
4. `.sliding` below threshold updates its progress rather than latching

**`SlideGeometry`**

5. `maxTravel` is `0`, never negative, when the track is narrower than its handle or has
   not been measured
6. `progress(forTranslation:)` clamps to `0...1` — negative translation and translation
   past the end
7. `progress(forTranslation:)` returns `0` when `maxTravel == 0`, rather than dividing by
   zero

Not tested: `handleDiameter`, `travel(at:)`, `handleOffset(at:)`, and `fillOffset(at:)`
beyond the clamping in (5) — branchless arithmetic, where a test would only restate the
formula.

Verified by hand in the simulator: 1:1 finger tracking, both springs, haptics, the
reduce-motion path, VoiceOver activation, and Dynamic Type at accessibility sizes.

**The project has no test target.** One must be added before these tests can run. Swift
Testing, matching the toolchain.

## Known trade-offs

- `Color.accentColor` reads the app-level tint and does *not* respond to a `.tint(_:)`
  modifier on the control. Per-instance colour would need a stored tint or an environment
  read. Accepted; the seam is the two `Color.accentColor` call sites in `SlideTrack`.
- Changing the confirm distance is now a source edit to `SlideState.threshold`.
- Three `GeometryReader`s appear across the two view files instead of one cached size. All
  are layout-neutral one-liners inside `.background`/`.overlay`. The alternative — one
  `@State` size fed by a preference key — reintroduces the deleted file and the zero-size
  first frame.

## Correction to an existing comment

`SwipeDragManager.fillOffset`'s documentation says the fill "ends one inset past the
handle". The arithmetic is two insets. The value is correct; the wording carries over
fixed as `fillOffset(at:)`.
