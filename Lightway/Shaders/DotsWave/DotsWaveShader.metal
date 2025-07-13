#include <metal_stdlib>
using namespace metal;

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#ifndef M_PI_2
#define M_PI_2 (M_PI * 0.5)
#endif

struct Uniforms {
    float    time;
    float2   resolution;
    float    dotSize;
    float    spacing;
    float    waveWidth;
    float    peakFlatFraction;
    float    baseOpacity;
    float    peakOpacity;
    float    animationSpeed;
    float    falloffExponent;
    float    minBrightness;    // brightness at bottom
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertexShader(uint vid [[vertex_id]],
                              constant Uniforms& u [[buffer(1)]]) {
    float2 coords[6] = {
        {-1,-1},{ 1,-1},{-1, 1},
        {-1, 1},{ 1,-1},{ 1, 1}
    };
    float2 p = coords[vid];
    VertexOut out;
    out.position = float4(p, 0, 1);
    out.uv = (p * 0.5 + 0.5) * u.resolution;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms& u [[buffer(1)]]) {
    float cellH = u.dotSize + u.spacing;
    float cellW = u.dotSize + u.spacing;

    int row = int(in.uv.y / cellH);
    int col = int(in.uv.x / cellW);

    float rowsF = u.resolution.y / cellH;
    // bottom row→0, top→1
    float yNorm = float(row) / (rowsF - 1);

    // wave position
    float pct = fmod(u.time, u.animationSpeed) / u.animationSpeed;
    float wCenter = -u.waveWidth + pct * (1 + 2 * u.waveWidth);

    // opacity falloff
    float dist = fabs(yNorm - wCenter);
    float halfW = u.waveWidth * 0.5;
    float flatW = halfW * u.peakFlatFraction;
    float alpha = u.baseOpacity;
    if (dist <= flatW) {
        alpha = u.peakOpacity;
    } else if (dist <= halfW) {
        float t = (dist - flatW) / (halfW - flatW);
        float raw = cos(t * M_PI_2);
        float sharp = pow(raw, u.falloffExponent);
        alpha = u.baseOpacity + (u.peakOpacity - u.baseOpacity) * sharp;
    }

    // dot mask
    float2 center = float2(col * cellW + u.dotSize * 0.5,
                           row * cellH + u.dotSize * 0.5);
    float d = distance(in.uv, center);
    float radius = u.dotSize * 0.5;
    float mask = 1.0 - smoothstep(radius, radius + 1.0, d);

    // brightness ramp: bottom→minBrightness, top→1.0
    float brightness = mix(u.minBrightness, 1.0, yNorm);

    return float4(brightness, brightness, brightness, alpha * mask);
}
