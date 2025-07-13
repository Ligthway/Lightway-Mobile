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

// Compute shader for updating particles
kernel void updateFallingParticles(device Particle* particles [[buffer(0)]],
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
        
        // Progressively remove particles as they get lower for tapering effect
        float normalizedY = particle.position.y / uniforms.particleAreaHeight;
        if (normalizedY > 0.3) { // Start thinning after 30% down
            float removalProbability = (normalizedY - 0.3) * 1.2; // 0 to 0.56 probability
            float rand = fract(sin(uniforms.time + float(id) * 45.234) * 43758.5453);
            if (rand < removalProbability * uniforms.deltaTime * 3.0) {
                particle.life = 0;
                particle.alpha = 0;
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
kernel void spawnFallingParticles(device Particle* particles [[buffer(0)]],
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
        particle.life = 2.0; // increased lifetime to compensate for slower speed
    }
}

// Vertex shader for rendering particles with glow
vertex VertexOut fallingParticleVertex(uint vertexID [[vertex_id]],
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
fragment float4 fallingParticleFragment(VertexOut in [[stage_in]]) {
    
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
        float glowAlpha = glowIntensity * in.alpha * 0.4; // 0.4 is the glow intensity (reduced)
        float glowBrightness = 1.0 + glowIntensity * 0.8; // Up to 1.8x brightness for HDR (reduced)
        
        color = float4(glowBrightness, glowBrightness, glowBrightness, glowAlpha);
    } else {
        // Outside particle area
        discard_fragment();
    }
    
    return color;
}
