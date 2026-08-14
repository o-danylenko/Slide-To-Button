#include <metal_stdlib>
using namespace metal;

// Ripples trailing a knob dragged across a slide control, as a `distortionEffect`.
//
// A distortion reads inside-out. To make content appear to move *right*, sample from the *left* — the
// returned position is where to read from, not where to put the pixel.

/// Ripples trailing a finger dragged across water.
///
/// Each source is a place the knob has been, and it keeps radiating after the knob has moved on —
/// which is what makes this a wake rather than a wobble. A single origin tracking the knob cannot
/// leave anything behind it, and a wave with no propagation term changes phase everywhere at once,
/// which reads as a bar flexing instead of a surface disturbed.
///
/// The wave is born at the source and travels outward at `speed`, so at age `t` its crest has reached
/// radius `speed * t`. Writing the phase as `k * (distance - speed * age)` is what carries it: pixels
/// near that moving radius are in the crest, and everything else is windowed out. Two decays then keep
/// it physical — with age, because the disturbance dies, and with distance, because a spreading ring
/// divides its energy over a longer circumference.
///
/// - Parameters:
///   - position: The destination pixel, in user space.
///   - sources: Flattened `x, y, age, strength` per source. Ages arrive already computed, since the
///     shader has no clock of its own.
///   - count: The flattened element count, so the loop steps by four.
///   - amplitude: Peak displacement, in points. Zero returns every pixel untouched.
///   - speed: How fast a ring travels outward, in points per second.
///   - wavelength: Distance between crests, in points.
///   - damping: How fast a ripple dies. Larger settles sooner.
///   - frontWidth: How thick the travelling crest is, in points. Wider reads as a swell, narrower as
///     a sharp ring.
[[ stitchable ]] float2 slideWake(
    float2 position,
    device const float *sources,
    int count,
    float amplitude,
    float speed,
    float wavelength,
    float damping,
    float frontWidth
) {
    if (amplitude < 0.01) {
        return position;
    }

    float2 total = float2(0.0);

    float waveNumber = 2.0 * M_PI_F / max(wavelength, 1.0);
    float spread = 2.0 * max(frontWidth, 1.0) * max(frontWidth, 1.0);

    for (int i = 0; i + 3 < count; i += 4) {
        float2 origin = float2(sources[i], sources[i + 1]);
        float age = sources[i + 2];
        float strength = sources[i + 3];

        // A ripple that has died contributes nothing, and most sources in the buffer are dead most of
        // the time — so leaving early is what keeps a long trail affordable.
        float decay = exp(-damping * age) * strength;
        if (decay < 0.01) {
            continue;
        }

        float2 offset = position - origin;
        float distance = length(offset);

        // Signed distance from the crest: negative inside the ring, positive outside it.
        float fromFront = distance - speed * age;

        // A Gaussian around the wavefront, so each source is a travelling ring rather than a standing
        // pattern filling the whole control.
        float window = exp(-(fromFront * fromFront) / spread);
        if (window < 0.01) {
            continue;
        }

        // Energy spread around a growing circumference.
        float falloff = 1.0 / (1.0 + distance * 0.015);

        float wave = sin(waveNumber * fromFront) * window * decay * falloff * amplitude;

        // Radial, which is what reads as water: content is pushed away from and drawn toward the
        // disturbance, so each ring acts as a lens. At the source itself there is no direction to
        // displace along, and no visible area either.
        if (distance > 0.001) {
            total += (offset / distance) * wave;
        }
    }

    return position + total;
}
