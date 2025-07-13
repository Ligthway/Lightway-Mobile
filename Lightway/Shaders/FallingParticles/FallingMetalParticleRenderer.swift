//
//  MetalParticle.swift
//  particle slider
//
//  Created by Alexandru Simedrea on 12.07.2025.
//


//
//  MetalParticleRenderer.swift
//  particle slider
//
//  Created by Alexandru Simedrea on 09.07.2025.
//

import Metal
import MetalKit
import SwiftUI

struct FallingMetalParticle {
    var position: SIMD2<Float>     // x (normalized 0-1), y (points from top)
    var velocity: SIMD2<Float>     // velocity in points/sec
    var size: Float                // size in points
    var alpha: Float               // opacity
    var life: Float                // remaining life (0-1)
    var padding: Float             // for alignment
}

struct FallingParticleUniforms {
    var deltaTime: Float
    var screenWidth: Float
    var screenHeight: Float
    var spawnRate: Float
    var maxParticles: UInt32
    var time: Float
    var particleAreaHeight: Float
}

class FallingMetalParticleRenderer {
    private let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Compute pipelines
    private let updatePipeline: MTLComputePipelineState
    private let spawnPipeline: MTLComputePipelineState
    
    // Render pipeline
    private let renderPipeline: MTLRenderPipelineState
    
    // Buffers
    private let particleBuffer: MTLBuffer
    private let uniformsBuffer: MTLBuffer
    private let spawnIndexBuffer: MTLBuffer
    
    private let maxParticles: Int = 4000
    private var startTime: CFTimeInterval = 0
    
    init?(device: MTLDevice) {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }
        
        self.commandQueue = commandQueue
        self.library = library
        
        // Create compute pipelines
        guard let updateFunction = library.makeFunction(name: "updateFallingParticles"),
              let spawnFunction = library.makeFunction(name: "spawnFallingParticles") else {
            return nil
        }
        
        do {
            updatePipeline = try device.makeComputePipelineState(function: updateFunction)
            spawnPipeline = try device.makeComputePipelineState(function: spawnFunction)
        } catch {
            print("Failed to create compute pipelines: \(error)")
            return nil
        }
        
        // Create render pipeline
        guard let vertexFunction = library.makeFunction(name: "fallingParticleVertex"),
              let fragmentFunction = library.makeFunction(name: "fallingParticleFragment") else {
            return nil
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgr10a2Unorm
        
        // Enable additive blending for bright glow effect
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        
        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline: \(error)")
            return nil
        }
        
        // Create buffers
        let particleBufferSize = maxParticles * MemoryLayout<FallingMetalParticle>.stride
        guard let particleBuffer = device.makeBuffer(length: particleBufferSize, options: .storageModeShared),
              let uniformsBuffer = device.makeBuffer(length: MemoryLayout<FallingParticleUniforms>.stride, options: .storageModeShared),
              let spawnIndexBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared) else {
            return nil
        }
        
        self.particleBuffer = particleBuffer
        self.uniformsBuffer = uniformsBuffer
        self.spawnIndexBuffer = spawnIndexBuffer
        
        // Initialize spawn index
        let spawnIndexPtr = spawnIndexBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        spawnIndexPtr.pointee = 0
        
        startTime = CACurrentMediaTime()
    }
    
    func update(deltaTime: Float, screenWidth: Float, screenHeight: Float, particleAreaHeight: Float) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Update uniforms
        let uniformsPtr = uniformsBuffer.contents().bindMemory(to: FallingParticleUniforms.self, capacity: 1)
        uniformsPtr.pointee = FallingParticleUniforms(
            deltaTime: deltaTime,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            spawnRate: 300.0, // particles per second (doubled)
            maxParticles: UInt32(maxParticles),
            time: Float(CACurrentMediaTime() - startTime),
            particleAreaHeight: particleAreaHeight
        )
        
        // Update particles
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(updatePipeline)
            computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(uniformsBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(spawnIndexBuffer, offset: 0, index: 2)
            
            let threadsPerThreadgroup = MTLSize(width: 64, height: 1, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (maxParticles + 63) / 64,
                height: 1,
                depth: 1
            )
            
            computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            computeEncoder.endEncoding()
        }
        
        // Spawn new particles
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(spawnPipeline)
            computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(uniformsBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(spawnIndexBuffer, offset: 0, index: 2)
            
            let particlesToSpawn = Int(400.0 * deltaTime) + 1
            let threadsPerThreadgroup = MTLSize(width: 64, height: 1, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (particlesToSpawn + 63) / 64,
                height: 1,
                depth: 1
            )
            
            computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            computeEncoder.endEncoding()
        }
        
        commandBuffer.commit()
    }
    
    func render(renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        
        // Draw particles as instanced quads
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: maxParticles)
        
        renderEncoder.endEncoding()
        commandBuffer.commit()
    }
}
