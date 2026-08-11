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

    public init(
        surface: Surface = .glass(),
        tint: Color,
        inset: CGFloat = 4,
        height: CGFloat? = 52
    ) {
        self.surface = surface
        self.tint = tint
        self.inset = inset
        self.height = height
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
    public static func solid<S: ShapeStyle>(
        _ tint: Color,
        surface: S = .quaternary,
        inset: CGFloat = 4,
        height: CGFloat? = 52
    ) -> SlideStyle {
        SlideStyle(surface: .filled(surface), tint: tint, inset: inset, height: height)
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
    public func slideStyle(_ style: SlideStyle) -> some View {
        environment(\.slideStyle, style)
    }
}
