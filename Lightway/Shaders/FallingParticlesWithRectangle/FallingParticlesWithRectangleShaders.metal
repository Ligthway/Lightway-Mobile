//
//  Shaders.metal
//  particle slider
//
//  Created by Alexandru Simedrea on 09.07.2025.
//

#include <metal_stdlib>
using namespace metal;

struct Particle {
    float2 position;     // x (normalized 0-1), y (points from top)
    float2 velocity;     // velocity in points/sec
    float size;          // size in points
    float alpha;         // opacity
    float life;          // remaining life (0-1)
    float padding;       // for alignment
};

struct Uniforms {
    float deltaTime;
    float screenWidth;
    float screenHeight;
    float spawnRate;
    uint maxParticles;
    float time;
    float particleAreaHeight;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float alpha;
    float size;
    float glowRadius;
};

#pragma mark - Helper Functions

// Signed distance to a rounded rectangle centered at origin.
// p: point relative to center
// halfSize: half-width/height of the rect minus corner radius
// r: corner radius
static inline float sdRoundRect(float2 p, float2 halfSize, float r) {
    float2 q = abs(p) - halfSize;
    return length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Compute shader for updating particles
kernel void updateParticles(device Particle* particles [[buffer(0)]],
                           constant Uniforms& uniforms [[buffer(1)]],
                           device atomic_uint& aliveCount [[buffer(2)]],
                           uint id [[thread_position_in_grid]]) {
    
    if (id >= uniforms.maxParticles) return;
    
    device Particle& particle = particles[id];
    
    // Update existing particles
    if (particle.life > 0) {
        // Update position
        particle.position.y += particle.velocity.y * uniforms.deltaTime;
        
        // Update life
        particle.life -= uniforms.deltaTime;
        
        // No position-based fading - handled by SwiftUI gradient mask
        particle.alpha = 1.0;
        
        // Rectangle outline parameters
        const float outlineStartY = 85.0;  // begin forming outline after this Y (points)

        // BEGIN SDF-BASED STEERING -------------------------------------------------
        if (particle.position.y >= outlineStartY - 40.0) { // start steering ~40 pt before threshold

            // Rounded-rect geometry (world coordinates)
            float rectTop      = outlineStartY;
            float rectHeight   = 40.0;
            float rectLeft     = uniforms.screenWidth * 0.1;
            float rectRight    = uniforms.screenWidth * 0.9;
            float rectWidth    = rectRight - rectLeft;
            float rectBottom   = rectTop + rectHeight;
            float cornerR      = 20.0;

            float2 center      = float2((rectLeft + rectRight) * 0.5, (rectTop + rectBottom) * 0.5);
            float2 halfSize    = float2(rectWidth * 0.5 - cornerR, rectHeight * 0.5 - cornerR);
            // Pre-compute the bottom edge of the rounded rectangle in the pRel coordinate system
            float bottomEdge   = halfSize.y + cornerR; // where the outline actually ends vertically

            // Use helper SDF

            // Particle world position
            float worldX = particle.position.x * uniforms.screenWidth;
            float worldY = particle.position.y;
            float2 pRel  = float2(worldX, worldY) - center;

            float dist   = sdRoundRect(pRel, halfSize, cornerR);

            // Band within which we consider particle "attached" (~20 pt)
            const float band = 20.0; // revert to 20 pt band

            // Horizontal half-width of the centre gate – narrower so particles converge more
            const float gateHalfWidth = 3.0;

            // Compute gradient (numerical)
            float eps = 1.0;
            float gradX = sdRoundRect(pRel + float2(eps, 0.0), halfSize, cornerR) - sdRoundRect(pRel - float2(eps, 0.0), halfSize, cornerR);
            float gradY = sdRoundRect(pRel + float2(0.0, eps), halfSize, cornerR) - sdRoundRect(pRel - float2(0.0, eps), halfSize, cornerR);
            float2 grad = normalize(float2(gradX, gradY));

            // Steering force magnitude (points per sec)
            float strength = 25.0;

            bool gateXgeneral = fabs(pRel.x) < (gateHalfWidth + 5.0); // near centre in X (for pull check)
            // Outside the outline → pull inward unless we're under the bottom centre gate
            if (dist > band) {
                // Skip inward pull if we're below the outline (dist ≥ 0) *and* in the gate
                if (!(gateXgeneral && dist >= 0.0f)) {
                    pRel -= grad * strength * uniforms.deltaTime;
                }
            } else if (dist < -band) {
                pRel += grad * strength * uniforms.deltaTime;
            } else {
                // On the outline → small tangential drift to keep motion
                // Choose tangent direction based on side: left half CCW, right half CW
                // Left half should move CLOCKWISE (toward bottom), right half COUNTER-CLOCKWISE
                float2 tangent = (pRel.x < 0.0) ? float2( grad.y, -grad.x)  // clockwise
                                                  : float2(-grad.y,  grad.x); // counter-clockwise
                float driftMag = 30.0; // visible perimeter movement
                pRel += tangent * driftMag * uniforms.deltaTime;

                // Slightly refresh lifetime but cap to prevent immortality
                particle.life = min(particle.life + uniforms.deltaTime * 0.2, 20.0);

                // Determine if particle is at the bottom-centre "gate"
                bool gateX = fabs(pRel.x) < gateHalfWidth;    // centred within tightened gate horizontally
                bool gateY = pRel.y > (bottomEdge - 5.0);     // within 5 pt of bottom edge

                if (gateX && gateY) {
                    // Let it fall out of the rectangle
                    particle.velocity = float2(0.0, 50.0);     // resume downward speed
                } else {
                    // Otherwise keep it stuck to outline
                    particle.velocity = float2(0.0, 0.0);
                }

                // Strong normal wobble for greater spacing (±15 pt)
                float wobble = (fract(sin(uniforms.time * 2.0 + float(id) * 13.77) * 43758.5453) - 0.5) * 45.0; // ±30pt range for wider spread
                pRel += grad * wobble * uniforms.deltaTime;

                // Slightly refresh lifetime but cap to prevent immortality
                particle.life = min(particle.life + uniforms.deltaTime * 0.2, 20.0);

                // Freeze downward velocity while attached – but allow motion if in the gate so they can exit
                if (!(gateX && gateY)) {
                    particle.velocity = float2(0.0, 0.0);
                }
            }

            // Re-evaluate gate condition for damping and killing logic
            bool gateCondition = (fabs(pRel.x) < gateHalfWidth && pRel.y > (bottomEdge - 5.0));

            // Dampen downward velocity only when not in gate zone
            if (fabs(dist) < band && !gateCondition) {
                particle.velocity.y = max(particle.velocity.y - 40.0 * uniforms.deltaTime, 0.0);
            }

            // Update particle pos back to normalized coordinates
            float2 newWorld = pRel + center;
            particle.position.x = clamp(newWorld.x / uniforms.screenWidth, 0.0, 1.0);
            particle.position.y = newWorld.y;

            // Kill the particle after it has exited below the rectangle via the gate
            // Gate test (re-use for kill & pull)
            // Allow particles to travel ~12 pt below the bottom before killing
            if (fabs(pRel.x) < gateHalfWidth && pRel.y > (bottomEdge + 12.0)) {
                // Particle has cleared bottom edge by 12 pt -> remove
                particle.life = 0.0;
            }
        }
        // END SDF-BASED STEERING -------------------------------------------------
        
        // Progressively remove particles only while they are ABOVE the outline area
        if (particle.position.y < outlineStartY) {
            float normalizedY = particle.position.y / uniforms.particleAreaHeight;
            if (normalizedY > 0.3) { // Start thinning after 30% down
                float removalProbability = (normalizedY - 0.3) * 1.2; // 0 to 0.56 probability
                float rand = fract(sin(uniforms.time + float(id) * 45.234) * 43758.5453);
                if (rand < removalProbability * uniforms.deltaTime * 3.0) {
                    particle.life = 0;
                    particle.alpha = 0;
                }
            }
        }
        
        // Remove if out of bounds or dead
        if (particle.position.y > uniforms.particleAreaHeight || particle.life <= 0) {
            particle.life = 0;
            particle.alpha = 0;
        }
    }
}

// Compute shader for spawning new particles
kernel void spawnParticles(device Particle* particles [[buffer(0)]],
                          constant Uniforms& uniforms [[buffer(1)]],
                          device atomic_uint& spawnIndex [[buffer(2)]],
                          uint id [[thread_position_in_grid]]) {
    
    // Calculate how many particles to spawn this frame
    uint particlesToSpawn = uint(uniforms.spawnRate * uniforms.deltaTime);
    
    if (id >= particlesToSpawn) return;
    
    // Find next available slot
    uint index = atomic_fetch_add_explicit(&spawnIndex, 1, memory_order_relaxed) % uniforms.maxParticles;
    
    device Particle& particle = particles[index];
    
    // Only spawn if slot is empty
    if (particle.life <= 0) {
        // Simple random using time and thread id
        float rand1 = fract(sin(uniforms.time + float(id) * 12.9898) * 43758.5453);
        float rand2 = fract(sin(uniforms.time + float(id) * 78.233) * 43758.5453);
        float rand3 = fract(sin(uniforms.time + float(id) * 31.416) * 43758.5453);
        float rand4 = fract(sin(uniforms.time + float(id) * 94.673) * 43758.5453);
        
        particle.position.x = rand1; // normalized 0-1
        particle.position.y = 0;
        particle.velocity.x = 0;
        particle.velocity.y = 40.0 + rand2 * 20.0; // 40-60 speed (slower)
        particle.size = 0.5 + rand3 * 1.0; // 0.5-1.5 size (reduced)
        particle.alpha = 0.8 + rand4 * 0.2; // 0.8-1.0 alpha
        particle.life = 20.0; // longer lifetime so particles can reach bottom center
    }
}

// Vertex shader for rendering particles with glow
vertex VertexOut particleVertex(uint vertexID [[vertex_id]],
                                uint instanceID [[instance_id]],
                                constant Particle* particles [[buffer(0)]],
                                constant Uniforms& uniforms [[buffer(1)]]) {
    
    constant Particle& particle = particles[instanceID];
    
    VertexOut out;
    
    // Skip dead particles
    if (particle.life <= 0) {
        out.position = float4(0, 0, 0, 0);
        out.alpha = 0;
        return out;
    }
    
    // Quad vertices in local space (-1 to 1)
    float2 vertices[4] = {
        float2(-1, -1),
        float2( 1, -1),
        float2(-1,  1),
        float2( 1,  1)
    };
    
    float2 localPos = vertices[vertexID];
    
    // Convert normalized x to screen space
    float screenX = particle.position.x * uniforms.screenWidth;
    
    // Expand the quad to include glow area (1.5x the particle size for more controlled glow)
    float glowRadius = particle.size * 1.5;
    float2 worldPos = float2(screenX, particle.position.y) + localPos * glowRadius;
    
    // Convert to normalized device coordinates
    // Use dynamic particle area height
    float2 ndc;
    ndc.x = (worldPos.x / uniforms.screenWidth) * 2.0 - 1.0;
    ndc.y = ((uniforms.particleAreaHeight - worldPos.y) / uniforms.particleAreaHeight) * 2.0 - 1.0; // Flip Y and normalize to particle area
    
    out.position = float4(ndc, 0, 1);
    out.uv = localPos;
    out.alpha = particle.alpha;
    out.size = particle.size;
    out.glowRadius = glowRadius;
    
    return out;
}

// Fragment shader for rendering particles with glow effect
fragment float4 particleFragment(VertexOut in [[stage_in]]) {
    
    float dist = length(in.uv);
    
    // Core particle (solid circle)
    float coreRadius = in.size / in.glowRadius; // normalized core radius
    float4 color = float4(0);
    
    if (dist <= coreRadius) {
        // Inside the core particle
        float coreAlpha = (1.0 - (dist / coreRadius)) * in.alpha;
        color = float4(1.0, 1.0, 1.0, coreAlpha);
    } else if (dist <= 1.0) {
        // In the glow area
        float glowDist = (dist - coreRadius) / (1.0 - coreRadius);
        float glowIntensity = 1.0 - glowDist;
        glowIntensity = smoothstep(0.0, 1.0, glowIntensity);
        
        // HDR glow - values > 1.0 for bright glow
        float glowAlpha = glowIntensity * in.alpha * 0.1; // 0.4 is the glow intensity (reduced)
        float glowBrightness = 1.0 + glowIntensity * 0.1; // Up to 1.8x brightness for HDR (reduced)
        
        color = float4(glowBrightness, glowBrightness, glowBrightness, glowAlpha);
    } else {
        // Outside particle area
        discard_fragment();
    }
    
    return color;
}
