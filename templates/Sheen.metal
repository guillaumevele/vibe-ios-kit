#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// A restrained diagonal sheen for premium surfaces.
//
// `time` is a uniform OWNED BY SWIFT. Freeze it (stop updating from the view)
// and the effect is fully static — there is no wall clock inside the shader, so
// the GPU does no work at rest. See AGENTS.md §1 and §4.
//
// Apply from SwiftUI as a stitchable colorEffect:
//   .colorEffect(ShaderLibrary.sheen(.float2(size), .float(time)))
[[ stitchable ]] half4 sheen(float2 position, half4 color, float2 size, float time) {
    if (color.a < 0.001h) {
        return color;                       // never tint fully-transparent pixels
    }
    float2 uv = position / max(size, float2(1.0));
    float band = uv.x + uv.y * 0.6;         // diagonal coordinate
    float sweep = fract(band - time * 0.12); // slow-moving 0..1 band
    float highlight = smoothstep(0.92, 1.0, sweep) * 0.18;
    half3 lifted = color.rgb + half3(half(highlight));
    return half4(lifted, color.a);
}
