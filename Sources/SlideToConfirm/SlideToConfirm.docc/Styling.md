# Styling a slide control

Choose the material, the colour, and the density.

## Overview

Style is carried in the environment, so setting it on a container reaches every control inside:

```swift
VStack {
    SlideToConfirm(isConfirmed: $a) { … } label: { … }
    SlideToConfirm(isConfirmed: $b) { … } label: { … }
}
.slideStyle(.tinted(.green))
```

### Where the glass goes

The capsule is the glass; the knob is solid.

That division is deliberate. Liquid Glass is a lens, so it needs area to refract through — a
knob-sized pane has too little, and would need a tint so strong it hid the effect it was applying.
It also needs something behind it: over a flat white background, glass returns white. The knob stays
solid so it remains legible against whatever the capsule is bending.

The same split appears throughout the system: glass carries the large floating surfaces — toolbars,
sidebars, tab bars — and the controls sitting on them are vivid and opaque.

### Tint is a hint, not a coat

``SlideStyle/Surface/glass(tint:fallback:)`` takes an optional colour, and `nil` is the useful
default. A tint suggests prominence; at full strength it paints over the refraction that makes the
material read as material. ``SlideStyle/monochrome(_:inset:height:)`` uses half strength for this
reason.

Reach for colour on the knob instead — that is what ``SlideStyle/tint`` is, and it is the parameter
every built-in style leads with.

### Built-in styles

| Style | Capsule | Knob |
| --- | --- | --- |
| ``SlideStyle/tinted(_:inset:height:)`` | untinted glass | the colour |
| ``SlideStyle/monochrome(_:inset:height:)`` | glass, half-tinted | the colour |
| ``SlideStyle/clear(_:inset:height:)`` | clear glass | the colour |
| ``SlideStyle/solid(_:surface:inset:height:)`` | a flat `ShapeStyle` | the colour |

``SlideStyle/clear(_:inset:height:)`` is the most transparent, so it needs a backdrop with enough
contrast for the label to stay readable. ``SlideStyle/solid(_:surface:inset:height:)`` opts out of
glass on every version — useful where a control sits somewhere a lens would not read.

For anything else, build a ``SlideStyle`` directly. Its surface accepts any `ShapeStyle`, so a
gradient or a `Material` works where a colour does:

```swift
.slideStyle(
    SlideStyle(
        surface: .filled(
            LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing)
        ),
        tint: .white,
        inset: 5
    )
)
```

### Size

``SlideStyle/inset`` is the gap between the knob and the capsule's edge, and it sets the control's
density: the knob is the capsule's height minus the inset on both sides, so a larger inset means a
smaller knob in a roomier capsule.

``SlideStyle/height`` overrides the height that would otherwise come from the label. Leaving it
`nil` is safer — a height derived from the label cannot clip its own copy at large Dynamic Type
sizes — so setting it means taking responsibility for the label's font too:

```swift
SlideToConfirm(isConfirmed: $isSending) { … } label: {
    Text("Slide to Confirm").font(.subheadline.weight(.semibold))
}
.slideStyle(.tinted(.blue, inset: 3, height: 40))
```

Both values scale with Dynamic Type, so a fixed height still grows as text does.

## Topics

### Styles

- ``SlideStyle``
- ``SlideStyle/Surface``

### Applying a style

- ``SwiftUI/View/slideStyle(_:)``
