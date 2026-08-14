# ``SlideToConfirm``

A slide-to-confirm control for actions that should not fire by accident.

## Overview

A tap is one event; a slide is a hundred, in one direction, held for most of a second. That makes a
slide the right gesture for anything irreversible — sending money, deleting a record, arming a
device — because a pocket or a stray thumb cannot produce one.

The pattern is common in shipped apps and absent from SwiftUI, so it gets rebuilt often. This one is
built around the three things those rebuilds usually get wrong: a trail that lags a fast flick, a
confirm that latches forever because the state is private, and no way to show the work the confirm
started.

```swift
@State private var isSending = false

SlideToConfirm(isConfirmed: $isSending) {
    send()
} label: {
    Text("Slide to Confirm").font(.headline)
}
```

The control sizes itself to its label, so Dynamic Type and multi-line copy grow it rather than
being clipped by it. `disabled(_:)` dims it and drops the gesture, as on any control.

On iOS 26 and later the capsule is Liquid Glass, refracting whatever it floats over. Below that it
falls back to an ordinary translucent fill, so one style ships to both.

### The caller owns the confirm latch

The `isConfirmed` argument to ``SlideToConfirm/init(isConfirmed:action:label:)`` is a binding rather
than internal state, because the gesture is not the only thing that can confirm — a server event or
a push notification can latch it too, and only the caller knows when the work behind it has
finished.

Set it back to `false` to re-arm:

```swift
withAnimation(.slideSnapBack) { isSending = false }
```

A control that never re-arms is the usual bug here. If the action can fail, clear the latch on the
error path as well as the success path.

### Showing progress in the knob

The knob's contents are a function of ``SlideState``, so an in-flight spinner is a switch on the
state rather than a second flag to keep in sync:

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

The closure receives the whole state, so `progress` is available too — enough to turn or fade the
mark as the finger moves, not only swap it at the ends.

### Accessibility

VoiceOver cannot perform a drag, so the control substitutes a plain button that fires the same
action. Haptics mark both ends of the gesture: an impact when the knob is grasped, a success when
it confirms.

Under Reduce Motion the confirm fires immediately instead of animating into place.

## Animations

Three springs are published as extensions on `Animation`, for use when the caller drives the latch
itself:

- `.slideSnapBack` returns the knob to rest when a slide is abandoned, and is what to wrap a re-arm
  in.
- `.slideConfirm` carries the knob the rest of the way once the threshold is crossed.
- `.slideAppearance` scales the knob as a slide begins and ends.

The style and wake modifiers are likewise extensions: `View.slideStyle(_:)` and `View.slideWake(_:)`.

## Effects

The knob's position is published as a ``SlideKnob`` preference, which is the seam a visual effect
attaches to. ``SlideWake`` is the one built in: ripples trailing the knob, applied with
`View.slideWake(_:)` and needing a non-glass surface, since a distortion pass rasterises what it bends.

The dependency points inward. A control without the modifier carries no ripple storage and runs no
timeline, and the control itself does not know the effect exists.

## Topics

### Creating a control

- ``SlideToConfirm``
- ``SlideChevron``

### Styling

- ``SlideStyle``

### Reading the gesture

- ``SlideState``
- ``SlideKnob``

### Effects

- ``SlideWake``
