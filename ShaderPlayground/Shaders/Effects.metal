#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float rand(float2 st) {
    return fract(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453123);
}

static float noise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = rand(i);
    float b = rand(i + float2(1, 0));
    float c = rand(i + float2(0, 1));
    float d = rand(i + float2(1, 1));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

[[ stitchable ]]
half4 glitchRipple(float2 pos, SwiftUI::Layer layer, float2 size, float2 center, float age) {
    float dist  = distance(pos, center);
        float front = age * 160.0;                        // ring travels outward

        // TRIGGER: hard band around the front, dying after ~1.4s.
        float band   = step(abs(dist - front), 90.0);
        float fade   = smoothstep(1.4, 0.0, age);
        float energy = band * fade;                        // 0 = clean, 1 = full effect

        // ---- coordinate we will bend, then break ----
        float2 p = pos;

        // 1) WARP — smooth organic push with noise + a sin wave.
        float2 q = float2(noise(p * 0.01 + age),
                          noise(p * 0.01 + float2(5.2, 1.3) + age));
        p += q * 40.0 * energy;                             // domain warp
        p.x += sin(p.y * 0.05 + age * 4.0) * 20.0 * energy; // flowing sin displacement

        // 2) GLITCH — quantize the ALREADY-WARPED coord into blocks.
        float2 grid = mix(float2(1.0), float2(40.0, 14.0), energy);
        p = floor(p / grid) * grid;

        // 3) SAMPLE the warped+blocked position.
        half4 c = layer.sample(p);

        // 4) POINTWISE color corruption (works on smooth areas too).
        c.rgb = mix(c.rgb, step(0.4h, c.bgr), energy);      // swap + posterize

        return c;
}
