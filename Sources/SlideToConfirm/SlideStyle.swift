import SwiftUI

/// How a ``SlideToConfirm`` is painted and how tightly it is packed.
///
/// Liquid Glass carries the whole capsule — the largest surface the control has, and the one
/// with enough area for refraction to read. The knob rides on top as a solid tinted circle, the
/// way system controls sit on a glass toolbar rather than being made of glass themselves.
///
/// Carried in the environment, so a style set on a container reaches every control inside it:
///
/// ```swift
/// VStack { … }
///     .slideStyle(.tinted(.green))
/// ```
public struct SlideStyle {
    /// The floating capsule the knob travels along.
    public var surface: Surface

    /// The knob, and its trail at reduced opacity.
    ///
    /// Solid, so it stays legible over whatever the surface is refracting. This is the colour
    /// callers actually reach for.
    public var tint: Color

    /// The breathing room between the knob and the surface's edge.
    ///
    /// Sets the control's density: the knob is the surface's height minus this on both sides, so
    /// a larger inset means a smaller knob in a taller capsule. Scaled for Dynamic Type at the
    /// point of use, so this is the value at the default text size.
    public var inset: CGFloat

    /// The capsule's height, or `nil` to take it from the label.
    ///
    /// Overrides the label-derived height in both directions, so this is what makes a control
    /// shorter as well as taller. `nil` is the safer default — a height taken from the label
    /// cannot clip its own copy at large Dynamic Type sizes — so setting this means owning the
    /// label's font too.
    public var height: CGFloat?

    /// Ripples trailing the knob, or `nil` for none.
    ///
    /// Part of the style rather than a modifier of its own, because it is only possible on some
    /// surfaces: a distortion pass rasterises what it bends, and Liquid Glass has nothing left to
    /// sample once flattened. Reaching it through ``SlideStyle/Solid`` is what makes the impossible
    /// combination impossible to write — see ``SlideStyle/Solid/stillEffect``.
    public var wake: SlideWake?

    public init(
        surface: Surface = .glass(),
        tint: Color,
        inset: CGFloat = 4,
        height: CGFloat? = 52,
        wake: SlideWake? = nil
    ) {
        self.surface = surface
        self.tint = tint
        self.inset = inset
        self.height = height
        self.wake = wake
    }
}

// MARK: - Surface

extension SlideStyle {
    /// What the capsule is made of.
    public enum Surface {
        /// Liquid Glass on iOS 26 and later, `fallback` below it.
        ///
        /// `tint` is optional because untinted glass is the honest default: a tint is a hint of
        /// prominence, and at full strength it paints over the very refraction that makes the
        /// material read as material.
        case glass(tint: Color? = nil, fallback: AnyShapeStyle = AnyShapeStyle(.quaternary))

        /// The `clear` glass variant: more transparent, so what is behind shows through more
        /// strongly. Needs a backdrop with enough contrast for the label to stay readable.
        case clearGlass(fallback: AnyShapeStyle = AnyShapeStyle(.quaternary))

        /// An ordinary `ShapeStyle`: no glass on any version.
        ///
        /// Spelled differently from ``filled(_:)`` on purpose: a case and a factory of the same
        /// name are ambiguous at any call site passing an `AnyShapeStyle`, since it satisfies both.
        case shapeStyle(AnyShapeStyle)

        /// A surface painted with any `ShapeStyle` — a colour, a gradient, a material.
        public static func filled<S: ShapeStyle>(_ style: S) -> Surface {
            .shapeStyle(AnyShapeStyle(style))
        }
    }
}

// MARK: - Built-in styles

extension SlideStyle {
    /// The default: untinted glass with an accent-coloured knob.
    public static var automatic: SlideStyle { .tinted(.accentColor) }

    /// A coloured knob on untinted glass.
    ///
    /// The glass is left untinted so it refracts cleanly, and the colour goes where it is
    /// legible — the knob and its trail.
    public static func tinted(
        _ tint: Color,
        inset: CGFloat = 4,
        height: CGFloat? = 52
    ) -> SlideStyle {
        SlideStyle(surface: .glass(), tint: tint, inset: inset, height: height)
    }

    /// One colour throughout: the glass carries a wash of it, the knob the full strength.
    ///
    /// Half strength on the tint, because glass tinted to the hilt is just a coloured capsule.
    public static func monochrome(
        _ tint: Color,
        inset: CGFloat = 4,
        height: CGFloat? = 52
    ) -> SlideStyle {
        SlideStyle(
            surface: .glass(
                tint: tint.opacity(0.5),
                fallback: AnyShapeStyle(tint.opacity(0.12))
            ),
            tint: tint,
            inset: inset,
            height: height
        )
    }

    /// Maximum transparency: the backdrop reads almost undisturbed through the capsule.
    public static func clear(
        _ tint: Color,
        inset: CGFloat = 4,
        height: CGFloat? = 52
    ) -> SlideStyle {
        SlideStyle(surface: .clearGlass(), tint: tint, inset: inset, height: height)
    }

    /// A flat look: no glass even where the system offers it.
    ///
    /// Returns a ``SlideStyle/Solid`` rather than a plain style, which is what makes the distortion
    /// effects reachable — they are only possible on a surface that can be rasterised.
    public static func solid<S: ShapeStyle>(
        _ tint: Color,
        surface: S = .quaternary,
        inset: CGFloat = 4,
        height: CGFloat? = 52
    ) -> Solid {
        Solid(
            style: SlideStyle(
                surface: .filled(surface),
                tint: tint,
                inset: inset,
                height: height
            )
        )
    }
}

// MARK: - Solid styles

extension SlideStyle {
    /// A style on a flat surface, which is the only kind a distortion can bend.
    ///
    /// Exists to put ``stillEffect`` and its siblings somewhere a glass style cannot reach. The
    /// alternative — one `wake` property on every style, skipped at runtime when the surface is glass —
    /// makes an impossible combination compile and then quietly do nothing. Here the type system states
    /// the constraint: `.tinted(.blue).stillEffect` is not an expression.
    ///
    /// Callers do not usually name this type: `View.slideStyle(_:)` has an overload that takes it, so
    /// `.solid(.blue)` and `.solid(.blue).stillEffect` both pass straight to the modifier.
    ///
    /// Where a `SlideStyle` is needed as a stored value, ask for ``slideStyle``. Swift has no implicit
    /// conversions, and an initializer taking this type made `SlideStyle(…)` ambiguous at every other
    /// call site — so the explicit property is the cost of stating the constraint in the type system.
    public struct Solid {
        var style: SlideStyle

        /// The style without any effect, for passing where a plain ``SlideStyle`` is wanted.
        public var slideStyle: SlideStyle { style }

        /// Ripples trailing the knob: a low, slow swell, like a heavy liquid.
        ///
        /// The cheapest of the three — a wide wavefront spreads the same displacement over more pixels,
        /// so the peak offset stays small and the rasterised area with it.
        public var stillEffect: SlideStyle { effect(.still) }

        /// Ripples trailing the knob: tighter, faster rings. Reads most like water.
        public var waterEffect: SlideStyle { effect(.water) }

        /// Ripples trailing the knob: sharp and short-lived, struck often.
        public var splashEffect: SlideStyle { effect(.splash) }

        /// Ripples with parameters of your own.
        public func rippleEffect(_ wake: SlideWake) -> SlideStyle { effect(wake) }

        private func effect(_ wake: SlideWake) -> SlideStyle {
            var copy = style
            copy.wake = wake
            return copy
        }
    }
}


extension SlideStyle.Surface {
    /// Whether this surface survives being rasterised by a `distortionEffect`.
    ///
    /// Liquid Glass does not. It samples what lies behind it at composite time, and a distortion pass
    /// flattens its content first — which leaves the capsule drawing nothing at all. A flat
    /// `ShapeStyle` has no such dependency and distorts correctly.
    ///
    /// Measured, not assumed: a distorted glass capsule renders as empty space, with only the knob and
    /// label visible.
    ///
    /// Unreachable through the public API now that effects hang off ``SlideStyle/Solid`` — kept as the
    /// backstop for a `SlideStyle` assembled by hand, where `surface` and `wake` are both settable.
    var survivesDistortion: Bool {
        switch self {
        case .glass, .clearGlass: false
        case .shapeStyle: true
        }
    }
}

// MARK: - Environment

private struct SlideStyleKey: EnvironmentKey {
    static var defaultValue: SlideStyle { .automatic }
}

extension EnvironmentValues {
    public var slideStyle: SlideStyle {
        get { self[SlideStyleKey.self] }
        set { self[SlideStyleKey.self] = newValue }
    }
}

extension View {
    /// Sets how slide-to-confirm controls in this view are painted.
    ///
    /// ```swift
    /// VStack { … }
    ///     .slideStyle(.tinted(.green))
    /// ```
    public func slideStyle(_ style: SlideStyle) -> some View {
        environment(\.slideStyle, style)
    }

    /// Sets how slide-to-confirm controls in this view are painted, on a flat surface.
    ///
    /// An overload so ``SlideStyle/solid(_:surface:inset:height:)`` can be passed with or without an
    /// effect on the end — `.solid(.blue)` and `.solid(.blue).stillEffect` both work, and no caller has
    /// to know that one of them returns a different type.
    public func slideStyle(_ style: SlideStyle.Solid) -> some View {
        environment(\.slideStyle, style.slideStyle)
    }
}
