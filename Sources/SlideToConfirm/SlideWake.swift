import SwiftUI

/// Ripples trailing the knob, as though it were dragged across water.
///
/// Applied as a modifier, so a control without one carries no ripple storage and runs no timeline:
///
/// ```swift
/// SlideToConfirm(isConfirmed: $isSending) { send() } label: {
///     Text("Slide to Confirm")
/// }
/// .slideWake(.still)
/// ```
///
/// A `distortionEffect`, so it moves pixels already drawn rather than painting over them: the label and
/// the trail bend, and the knob stays rigid. A finger does not deform — what gives way is the surface
/// under it.
///
/// Three presets, cheapest first. ``still`` is the default; ``water`` and ``splash`` raise the
/// amplitude and shorten the wavelength, which buys a more obvious effect with fill rate.
public struct SlideWake: Equatable, Sendable {
    /// Peak displacement, in points. Zero disables the effect.
    public var amplitude: CGFloat

    /// How fast a ripple travels outward, in points per second.
    public var speed: CGFloat

    /// Distance between crests, in points. Shorter reads as water, longer as a heavy liquid.
    public var wavelength: CGFloat

    /// How fast a ripple dies, per second. Larger settles sooner.
    public var damping: CGFloat

    /// How thick the travelling crest is, in points. Wider reads as a swell, narrower as a ring.
    public var frontWidth: CGFloat

    /// How often the knob disturbs the surface while it moves, in seconds.
    ///
    /// Paced by time rather than by distance, because water has no threshold — it is disturbed
    /// continuously while something moves through it. Pacing by distance makes the surface respond in
    /// steps, which reads as a mechanism rather than a liquid.
    public var emitInterval: TimeInterval

    public init(
        amplitude: CGFloat = 7,
        speed: CGFloat = 120,
        wavelength: CGFloat = 60,
        damping: CGFloat = 1.4,
        frontWidth: CGFloat = 44,
        emitInterval: TimeInterval = 0.08
    ) {
        self.amplitude = amplitude
        self.speed = speed
        self.wavelength = wavelength
        self.damping = damping
        self.frontWidth = frontWidth
        self.emitInterval = emitInterval
    }

    /// No ripples, for switching the effect off in a subtree that has it on.
    public static let none = SlideWake(amplitude: 0)

    /// A low, slow swell — a heavy liquid rather than a splash, and the cheapest of the three.
    ///
    /// A wide front spreads the same displacement over more pixels, so the peak offset stays small and
    /// the rasterised area with it.
    public static let still = SlideWake()

    /// Tighter, faster rings. Reads most like water, and costs more for it.
    public static let water = SlideWake(
        amplitude: 12,
        speed: 220,
        wavelength: 22,
        damping: 2.6,
        frontWidth: 12,
        emitInterval: 0.045
    )

    /// Sharp, short-lived ripples, struck often.
    public static let splash = SlideWake(
        amplitude: 16,
        speed: 340,
        wavelength: 20,
        damping: 3.6,
        frontWidth: 12,
        emitInterval: 0.03
    )

    /// Whether this configuration draws anything at all.
    var isActive: Bool { amplitude > 0 }

    /// The amplitude below which a ripple is dropped, matching the shader's own early-out.
    static let visibilityThreshold: CGFloat = 0.01

    /// A ceiling on live ripples, as a backstop rather than the usual limit.
    ///
    /// Ripples are normally retired by decay well before this bites. It exists so a pathological emit
    /// rate cannot grow the shader's per-pixel loop without bound.
    static let sourceCapacity = 48
}

// MARK: - Applying

/// Applies the wake to the capsule, or nothing at all when the style carries none.
///
/// Wraps the surface and the label but not the knob — the knob is drawn as an overlay after this, because
/// it stands in for the finger and a finger does not deform. Bending both reads as the control melting
/// rather than as a surface being disturbed.
///
/// Everything it needs is already here. `state` gives the progress and the press; the size arrives with
/// the effect itself, since `visualEffect` hands its closure a `GeometryProxy`. So there is nothing to
/// measure, store, or wait for — and no "not yet measured" case to represent.
struct WakeGeometry: ViewModifier {
    let wake: SlideWake?
    let surface: SlideStyle.Surface
    let state: SlideState
    let inset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The trail of places the knob has been.
    ///
    /// Lives here rather than in the control, so a style without a wake carries no ripple storage.
    @State private var trail = SlideRippleTrail()

    /// Whether the effect should draw at all.
    ///
    /// The surface check is a backstop rather than the guard: the public API cannot produce a glass style
    /// carrying a wake, since the effects hang off ``SlideStyle/Solid``. It still matters for a
    /// `SlideStyle` assembled by hand, where both properties are settable.
    ///
    /// Dropped under Reduce Motion, since ripples carry no information the knob does not.
    private var isActive: Bool {
        guard let wake else { return false }
        return wake.isActive && !reduceMotion && surface.survivesDistortion
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if let wake, isActive {
            // Redraws every frame while ripples live. Shader arguments are not interpolated — a new value
            // renders immediately, with nothing in between — so the clock that feeds them has to tick per
            // frame rather than be handed to an animation.
            TimelineView(.animation(paused: trail.isEmpty)) { context in
                let sources = trail.sourceData(at: context.date, wake: wake)

                content.distortionEffect(
                    wake.shader(sources: sources),
                    maxSampleOffset: wake.maxSampleOffset
                )
            }
            // The proxy is the control's own, so the knob's position follows from the layout without any
            // measurement of ours. Struck from the state rather than from a render pass, so a ripple is
            // born of the gesture that caused it.
            .onGeometryChange(for: SlideKnob.self) { proxy in
                knob(in: SlideGeometry(trackSize: proxy.size, inset: inset))
            } action: { knob in
                trail.follow(knob, wake: wake)
            }
        } else {
            content
        }
    }

    /// Where the ripples originate, and whether a finger is down.
    private func knob(in geometry: SlideGeometry) -> SlideKnob {
        let offset = geometry.handleOffset(at: state.progress)
        let radius = geometry.handleDiameter / 2

        return SlideKnob(
            centre: CGPoint(x: offset.width + radius, y: offset.height + radius),
            diameter: geometry.handleDiameter,
            isDragging: state.isSliding
        )
    }
}

// MARK: - Ripple storage

/// One disturbance: where the knob was, when it happened, and how hard.
struct SlideRipple: Equatable {
    let point: CGPoint
    let birth: Date
    let strength: CGFloat
}

/// The places the knob has been, and the arithmetic that turns them into shader arguments.
///
/// A value rather than a reference type, so an effect owns it as ordinary `@State` and every change
/// goes through SwiftUI's usual invalidation.
struct SlideRippleTrail: Equatable {
    private var ripples: [SlideRipple] = []

    /// When a ripple was last emitted, so emission can be paced by time.
    private var lastEmit: Date = .distantPast

    /// Where the knob was at the last emission, for the speed estimate.
    private var lastEmitPoint: CGPoint = .zero

    var isEmpty: Bool { ripples.isEmpty }

    /// Records the knob's position, emitting a ripple when one is due.
    ///
    /// The whole interface to the outside: an effect hands over what the control published and this
    /// decides whether the surface was disturbed. Keeping that judgement here is what lets the emit
    /// policy change — a different cadence, a different strength curve — without touching the drawing.
    mutating func follow(_ knob: SlideKnob, wake: SlideWake) {
        // A track narrower than its knob, or one asked about before layout, has no surface to disturb.
        guard knob.diameter > 0 else { return }

        let now = Date.now

        guard knob.isDragging else {
            // Lifting out disturbs the surface as much as entering it did, and only once: the knob
            // reports not-dragging on every frame of the snap-back too.
            if lastEmit != .distantPast {
                emit(at: knob.centre, strength: 1, now: now, wake: wake)
                lastEmit = .distantPast
            }
            return
        }

        // Entering the water is its own disturbance, and the largest single one.
        guard lastEmit != .distantPast else {
            emit(at: knob.centre, strength: 1, now: now, wake: wake)
            return
        }

        let elapsed = now.timeIntervalSince(lastEmit)
        guard elapsed >= wake.emitInterval else { return }

        // Strength follows the knob's speed over the interval just elapsed, so a slow drag leaves a
        // faint trail and a flick a strong one — without needing a velocity from the gesture.
        let travelled = abs(knob.centre.x - lastEmitPoint.x)
        let speed = elapsed > 0 ? travelled / CGFloat(elapsed) : 0

        emit(at: knob.centre, strength: min(1, 0.25 + speed / 900), now: now, wake: wake)
    }

    /// Records a disturbance, retiring any that have decayed past visibility.
    ///
    /// Retired by decay rather than by count, because a fixed-size buffer evicts the oldest ripple
    /// whether or not it has finished — and at low damping it has not. A ripple at 1.4/s is still at 7%
    /// of its strength when a 24-slot buffer would drop it, which reads as a ring vanishing mid-flight.
    private mutating func emit(at point: CGPoint, strength: CGFloat, now: Date, wake: SlideWake) {
        // Filtered into a new array rather than removed in place: `decay` is a method on `self`, so
        // reading it from inside a mutating `removeAll` would be an overlapping access.
        ripples = ripples.filter { ripple in
            decay(of: ripple, at: now.timeIntervalSince(ripple.birth), damping: wake.damping)
                >= SlideWake.visibilityThreshold
        }

        ripples.append(SlideRipple(point: point, birth: now, strength: strength))

        // A backstop only, and oldest-first because that is also the most decayed — so an overflowing
        // trail loses its faintest end rather than its freshest.
        if ripples.count > SlideWake.sourceCapacity {
            ripples.removeFirst(ripples.count - SlideWake.sourceCapacity)
        }

        lastEmit = now
        lastEmitPoint = point
    }

    /// The live ripples flattened to `x, y, age, strength` per source.
    ///
    /// Ages are computed here because a shader has no clock: it sees only the uniforms it is handed.
    /// This runs once per frame, not once per pixel, so the per-source arithmetic belongs on this side —
    /// as does dropping a decayed source, which then costs the GPU nothing at all.
    func sourceData(at now: Date, wake: SlideWake) -> [Float] {
        var data: [Float] = []
        data.reserveCapacity(ripples.count * 4)

        for ripple in ripples {
            let age = now.timeIntervalSince(ripple.birth)
            // A negative age would put the wavefront at a negative radius, which the shader's window
            // would read as a ring collapsing inward.
            guard age >= 0,
                  decay(of: ripple, at: age, damping: wake.damping) >= SlideWake.visibilityThreshold
            else { continue }

            data.append(Float(ripple.point.x))
            data.append(Float(ripple.point.y))
            data.append(Float(age))
            data.append(Float(ripple.strength))
        }

        return data
    }

    /// How much of a ripple is left, by the same rule the shader applies.
    ///
    /// Stated once and used for both pruning and flattening, so the two cannot disagree about which
    /// sources exist.
    private func decay(of ripple: SlideRipple, at age: TimeInterval, damping: CGFloat) -> CGFloat {
        exp(-damping * CGFloat(age)) * ripple.strength
    }
}

// MARK: - Shader

extension SlideWake {
    /// The shader function, loaded from this package's own bundle rather than the app's.
    ///
    /// A package's Metal sources link into its resource bundle, so `ShaderLibrary.default` — which
    /// reads the main bundle — would not find them.
    static let function = ShaderLibrary.bundle(.module).slideWake

    /// The distortion for a given frame, built from the live ripples.
    ///
    /// Arguments are bound through an explicit array rather than the dynamic-member call, which the
    /// type checker cannot resolve in reasonable time at this arity.
    func shader(sources: [Float]) -> Shader {
        let arguments: [Shader.Argument] = [
            .floatArray(sources),
            .float(Float(amplitude)),
            .float(Float(speed)),
            .float(Float(wavelength)),
            .float(Float(damping)),
            .float(Float(frontWidth))
        ]

        return Shader(function: Self.function, arguments: arguments)
    }

    /// Bounds the distortion for every frame, not the current one, so a peak cannot be clipped.
    ///
    /// The effect is rasterised over the control grown by this margin on all four sides, so too small
    /// silently clips the ripples and too large silently costs fill rate. The wake is radial, so the
    /// bound is the same on both axes.
    var maxSampleOffset: CGSize {
        let bound = amplitude.rounded(.up)
        return CGSize(width: bound, height: bound)
    }
}
