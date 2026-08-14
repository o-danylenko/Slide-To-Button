<p align="center">
  <img src="Media/confirm.gif" width="420" alt="Sliding to send a payment: the knob travels, the trail fills behind it, a spinner runs while the transfer completes, then the control re-arms.">
</p>

<h1 align="center">Slide-To</h1>

<p align="center">
  A slide-to-confirm control for SwiftUI, built for Liquid Glass.
</p>

<p align="center">
  <a href="https://github.com/o-danylenko/SlideToConfirm/actions/workflows/ci.yml"><img src="https://github.com/o-danylenko/SlideToConfirm/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://o-danylenko.github.io/SlideToConfirm/documentation/slidetoconfirm/"><img src="https://img.shields.io/badge/docs-DocC-blue" alt="Documentation"></a>
  <a href="https://swiftpackageindex.com/o-danylenko/SlideToConfirm"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fo-danylenko%2FSlideToConfirm%2Fbadge%3Ftype%3Dswift-versions" alt="Swift versions"></a>
  <a href="https://swiftpackageindex.com/o-danylenko/SlideToConfirm"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fo-danylenko%2FSlideToConfirm%2Fbadge%3Ftype%3Dplatforms" alt="Platforms"></a>
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT">
</p>

## Why this exists

A tap is one event. A slide is a hundred, in one direction, held for most of a second. That
difference is the whole point: a pocket, a stray thumb, or a mis-aimed reach cannot produce a slide,
so a slide is the right gesture in front of anything you cannot undo — sending money, wiping a
device, arming an alarm.

The pattern is everywhere in shipped apps and nowhere in SwiftUI. Every team rebuilds it, and most
rebuilds get the same three things wrong:

- **The trail lags the finger.** The fill is animated separately from the knob, so a fast flick
  leaves it behind. Here the knob and the trail are two readings of one interpolated value, so they
  cannot drift apart.
- **It latches forever.** The control confirms, and nothing can un-confirm it, because the state is
  private. Here the latch is a binding the caller owns.
- **It cannot show progress.** Confirming usually starts work that takes time. Here the knob's
  contents are a function of the state, so a spinner is a `switch`, not a second flag.

It is also built for Liquid Glass rather than retrofitted to it. On iOS 26 the capsule is real glass;
below that it falls back to a translucent fill, and nothing in the API mentions which era you are in.

## Contents

- [Installation](#installation)
- [Basic usage](#basic-usage)
- [The confirm latch](#the-confirm-latch)
- [Progress in the knob](#progress-in-the-knob)
- [Styles](#styles)
- [Size and density](#size-and-density)
- [Ripples](#ripples)
- [Accessibility](#accessibility)
- [How it works](#how-it-works)
- [Example app](#example-app)
- [Documentation](#documentation)
- [Tests](#tests)
- [License](#license)

## Installation

Add the package in Xcode with **File → Add Package Dependencies**, or declare it directly:

```swift
.package(url: "https://github.com/o-danylenko/SlideToConfirm", from: "1.0.0")
```

Then add `SlideToConfirm` to your target's dependencies.

iOS 17 is the floor. Liquid Glass activates on iOS 26 and later.

## Basic usage

```swift
import SlideToConfirm

@State private var isSending = false

SlideToConfirm(isConfirmed: $isSending) {
    send()
} label: {
    Text("Slide to Confirm").font(.headline)
}
```

Three parts: a binding that holds whether the control has confirmed, an action that runs the moment
it does, and a label.

The control sizes itself to its label, so Dynamic Type and multi-line copy grow it instead of being
clipped by it. `disabled(_:)` dims it and drops the gesture, as on any control.

## The confirm latch

`isConfirmed` is a binding, not internal state, because the gesture is not the only thing that can
confirm. A server event, a push, or a restored session can latch it too, and only the caller knows
when the work behind it has finished.

Set it back to `false` to re-arm:

```swift
withAnimation(.slideSnapBack) { isSending = false }
```

If the action can fail, clear the latch on the error path as well as the success path. A control
that stays confirmed after a failed request is the usual bug in this pattern.

## Progress in the knob

The knob's contents come from a closure that receives the whole state, so an in-flight spinner needs
no extra bookkeeping:

```swift
SlideToConfirm(isConfirmed: $isSending) { send() } label: {
    Text("Slide to Confirm")
} handleContent: { state in
    if state == .confirmed {
        ProgressView().tint(.white)
    } else {
        SlideChevron()
    }
}
```

## Styles

<p align="center">
  <img src="Media/materials.gif" width="380" alt="Four bars with different materials: clear glass, untinted glass, half-tinted glass, and a flat fill. Sliding each shows the same gesture reading differently through each material.">
</p>

Four built-in styles, applied through the environment:

```swift
.slideStyle(.tinted(.green))     // clear glass capsule, tinted knob
.slideStyle(.monochrome(.red))   // glass tinted at half strength
.slideStyle(.clear(.mint))       // the clear glass variant
.slideStyle(.solid(.orange))     // a flat fill on every OS version
```

Because the style travels in the environment, setting it on a container reaches every control
inside — a sheet, a list, or a whole screen. Any `ShapeStyle` works as the capsule's surface,
including gradients and materials:

```swift
.slideStyle(.solid(.white, surface: LinearGradient(
    colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing
)))
```

The capsule carries the glass and the knob stays solid, deliberately. Glass is a lens: it needs area
to refract through and something behind it to bend, and a knob-sized pane has neither. Keeping the
knob solid also keeps it legible against whatever the capsule is refracting.

## Size and density

<p align="center">
  <img src="Media/sizing.gif" width="380" alt="One control cycling through heights of 40, 56 and 76 points, the knob scaling with the capsule; below it a second control with height nil, sized by its own two lines of copy.">
</p>

`height` sets the capsule's height and `inset` the gap between the knob and its edge. Both scale
with Dynamic Type.

```swift
.slideStyle(.tinted(.blue, inset: 3, height: 40))
.slideStyle(.monochrome(.purple, height: nil))
```

Pass `height: nil` where the label must be free to grow — multi-line copy, or the accessibility text
sizes, which a fixed height cannot expand to fit.

## Ripples

Optional. The knob can leave a wake behind it, as though it were dragged across water:

```swift
SlideToConfirm(isConfirmed: $isSending) { send() } label: {
    Text("Slide to Confirm")
}
.slideStyle(.solid(.blue))
.slideWake(.still)
```

Three presets, cheapest first: `.still`, `.water`, `.splash`.

<details>
<summary><strong>How it works, and why it needs a solid surface</strong></summary>

<br>

Each place the knob has been becomes a ripple source that keeps radiating after the knob has moved on.
That is what makes it a wake rather than a wobble — a single origin tracking the knob cannot leave
anything behind it. The wave is born at its source and travels outward at a finite speed, so the phase
is written `k * (distance - speed * age)`: pixels near that moving radius are in the crest, and the rest
are windowed out.

Sources are emitted on a **time** cadence, not a distance threshold. Water has no threshold; it is
disturbed continuously while something moves through it. Pacing by distance makes the surface respond
in steps, which reads as a mechanism rather than a liquid. Ripple strength follows the knob's speed, so
a slow drag leaves a faint trail and a flick a strong one.

Displacement is radial, which is what makes each ring act as a lens, and decays twice: with age,
because the disturbance dies, and with distance, because a spreading ring divides its energy over a
longer circumference. Ripples are retired when they decay below visibility rather than when a buffer
fills — a fixed-size buffer evicts the oldest whether or not it has finished, and at low damping it has
not.

**Cost.** Measured on an iPhone 14 Pro with Metal System Trace over 13 seconds of dragging: 0.38ms mean
per encoder, 3.01ms worst, GPU busy 4.5% of the window, thermal state Fair throughout. Two early-outs
in the shader — dead ripple, and pixel outside the wavefront — mean most sources cost almost nothing
most of the time. Nothing is allocated and no timeline runs until a ripple exists.

**Why solid only.** `distortionEffect` rasterises what it bends. Liquid Glass samples what lies behind
it at composite time, so once flattened it has nothing left to sample and the capsule draws nothing at
all. The two cannot be composed at the drawing layer, so this is a choice between materials rather than
a limitation to work around: on a glass style the wake is skipped and the control renders normally.

**Design.** The control publishes one value — `SlideKnob`, a centre, a diameter, and whether a finger
is down — through a preference. The wake is a `ViewModifier` that reads it and owns its own trail. So
the dependency points inward: `SlideToConfirm` does not know the effect exists, a control without the
modifier carries no ripple storage, and a second effect needs no change to the control.

</details>

## Accessibility

- **VoiceOver** substitutes a plain button, because a drag cannot be performed through it.
- **Reduce Motion** confirms immediately instead of springing the knob to the end, and suppresses the
  wake entirely — ripples carry no information the knob does not.
- **Dynamic Type** scales the height, the inset and the label together.
- **Haptics** fire at both ends of the gesture.

## How it works

Four types, each with a single job:

| Type | Responsibility | Depends on |
| --- | --- | --- |
| `SlideState` | the input state machine | nothing |
| `SlideGeometry` | translation and size to progress | CoreGraphics |
| `SlideToConfirm` | the gesture and its storage | SwiftUI |
| `SlideTrack` | drawing | SwiftUI |
| `SlideWake` | ripples, if applied | SwiftUI + Metal |

`SlideTrack` holds no `@State`, no `@GestureState` and no gesture, so no change to how the control
looks can regress how it drags.

`SlideState` is a total transition in which `confirmed` absorbs, so a latched confirm outranks a live
finger by construction rather than by a check at every read.

`SlideFill` carries progress as `animatableData`. That is what keeps the trail locked to the knob:
both are readings of the same interpolated value, so a fast flick cannot separate them.

The first two types are pure values and carry the test suite. The last two are thin enough to review
by eye.

## Example app

`Example.xcodeproj` is a gallery of the built-in styles over an animated backdrop, plus a
device-pairing screen where the confirm arrives from a simulated server rather than the gesture.

The moving backdrop is not decoration. Over a flat background, glass has nothing to refract and
reads as flat colour; dragging a knob across a moving field is the only way to see the material
behave like a lens.

## Documentation

The API reference is published at
[o-danylenko.github.io/SlideToConfirm](https://o-danylenko.github.io/SlideToConfirm/documentation/slidetoconfirm/).

To build it yourself, open the package in Xcode and choose **Product → Build Documentation**, or:

```sh
xcodebuild docbuild -scheme SlideToConfirm -destination 'generic/platform=iOS'
```

## Tests

```sh
swift test
```

The state machine and the geometry are pure values, so the suites run on the host without a
simulator.

## License

MIT. See [LICENSE](LICENSE).
