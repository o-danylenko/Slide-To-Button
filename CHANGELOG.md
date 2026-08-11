# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-08-11

First release.

### Added

- `SlideToConfirm`, a one-shot slide-to-confirm control. The caller owns the confirm latch through
  a binding, because the gesture is not the only thing that can confirm — a server event or a push
  can latch it too, and only the caller knows when the work behind it has finished.
- Liquid Glass on the capsule on iOS 26 and later, falling back to a translucent fill below it. The
  capsule carries the material rather than the knob: glass is a lens, so it needs area to refract
  through, and a knob-sized pane has too little.
- `SlideStyle` with four built-in styles — `tinted`, `monochrome`, `clear`, `solid` — carried in the
  environment, so a style set on a container reaches every control inside it. Any `ShapeStyle` works
  as a surface, including gradients and materials.
- A handle-content closure taking the whole `SlideState`, so an in-flight spinner is a switch on the
  state rather than a second flag to keep in sync.
- `height` and `inset` for size and density, both scaled for Dynamic Type. `height: nil` takes the
  height from the label, for multi-line copy.
- VoiceOver support: the control substitutes a plain button, since a drag cannot be performed with
  it. Haptics at both ends of the gesture, and an immediate confirm under Reduce Motion.
- A DocC catalog, and an example app demonstrating each style over a moving backdrop.

[Unreleased]: https://github.com/o-danylenko/SlideToConfirm/compare/1.0.0...HEAD
[1.0.0]: https://github.com/o-danylenko/SlideToConfirm/releases/tag/1.0.0
