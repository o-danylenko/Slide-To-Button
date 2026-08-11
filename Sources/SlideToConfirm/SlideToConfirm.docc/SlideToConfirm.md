# ``SlideToConfirm``

A slide-to-confirm control for actions that should not fire by accident.

## Overview

A tap is one event; a slide is a hundred. That makes a slide the right gesture for anything
irreversible — placing a bet, sending money, deleting a record — because a pocket or a stray thumb
cannot produce one.

```swift
@State private var isPlacing = false

SlideToConfirm(isConfirmed: $isPlacing) {
    place()
} label: {
    Text("Slide to Place Bet").font(.headline)
}
```

The control sizes itself to its label, so Dynamic Type and multi-line copy grow it rather than
being clipped by it. `disabled(_:)` dims it and drops the gesture, as on any control.

On iOS 26 and later the capsule is Liquid Glass, refracting whatever it floats over. Below that it
falls back to an ordinary translucent fill, so one style ships to both.

### The caller owns the confirm latch

``SlideToConfirm/isConfirmed`` is a binding rather than internal state, because the gesture is not
the only thing that can confirm — a server event or a push notification can latch it too, and only
the caller knows when the work behind it has finished.

Set it back to `false` to re-arm:

```swift
withAnimation(.slideSnapBack) { isPlacing = false }
```

A control that never re-arms is the usual bug here. If the action can fail, clear the latch on the
error path as well as the success path.

### Showing progress in the knob

The knob's contents are a function of ``SlideState``, so an in-flight spinner is a switch on the
state rather than a second flag to keep in sync:

```swift
SlideToConfirm(isConfirmed: $isPlacing) { place() } label: {
    Text("Slide to Place Bet")
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

## Topics

### Creating a control

- ``SlideToConfirm``
- ``SlideChevron``

### Styling

- ``SlideStyle``
- ``SwiftUI/View/slideStyle(_:)``

### Reading the gesture

- ``SlideState``

### Animations

- ``SwiftUI/Animation/slideSnapBack``
- ``SwiftUI/Animation/slideConfirm``
- ``SwiftUI/Animation/slideAppearance``
