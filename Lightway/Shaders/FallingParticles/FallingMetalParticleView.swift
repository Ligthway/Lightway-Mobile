//
//  MetalParticleView.swift
//  Lightway
//
//  Created by Alexandru Simedrea on 09.07.2025.
//

import SwiftUI
import Metal
import MetalKit

struct FallingMetalParticleView: UIViewRepresentable {
    let height: CGFloat
    
    init(height: CGFloat = 200) {
        self.height = height
    }
    
    func makeUIView(context: Context) -> UIMetalParticleView {
        let view = UIMetalParticleView()
        view.particleAreaHeight = Float(height)
        return view
    }
    
    func updateUIView(_ uiView: UIMetalParticleView, context: Context) {
        uiView.particleAreaHeight = Float(height)
        print("MetalParticleView height updated to: \(height)")
    }
    
    class UIMetalParticleView: UIView {
        override class var layerClass: AnyClass { CAMetalLayer.self }
        
        var metalLayer: CAMetalLayer { layer as! CAMetalLayer }
        var renderer: FallingMetalParticleRenderer?
        var displayLink: CADisplayLink?
        var lastTime: CFTimeInterval = 0
        var particleAreaHeight: Float = 200.0 {
            didSet {
                if particleAreaHeight != oldValue {
                    print("Height changed from \(oldValue) to \(particleAreaHeight) - clearing particles")
                    clearAllParticles()
                }
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }
        
        func setup() {
            guard let device = MTLCreateSystemDefaultDevice() else {
                print("Metal not supported")
                return
            }
            
            metalLayer.device = device
            metalLayer.pixelFormat = .bgr10a2Unorm
            metalLayer.colorspace = CGColorSpace(name: CGColorSpace.displayP3_PQ)
            metalLayer.framebufferOnly = false
            metalLayer.backgroundColor = UIColor.clear.cgColor
            metalLayer.isOpaque = false
            
            // Enable HDR content for bright glow
            metalLayer.setValue(NSNumber(booleanLiteral: true), forKey: "wantsExtendedDynamicRangeContent")
            
            renderer = FallingMetalParticleRenderer(device: device)
            
            lastTime = CACurrentMediaTime()
        }
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                startDisplayLink()
            } else {
                stopDisplayLink()
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            metalLayer.frame = bounds
            metalLayer.drawableSize = bounds.size
        }
        
        func startDisplayLink() {
            displayLink = CADisplayLink(target: self, selector: #selector(render))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }
        
        func clearAllParticles() {
            // Clear all existing particles when height changes
            // For now, just let them naturally expire and respawn with new bounds
            // The particle system will automatically adapt to the new height
            print("Particles will clear naturally and respawn with new height")
        }
        
        @objc func render() {
            guard let renderer = renderer,
                  let drawable = metalLayer.nextDrawable() else {
                return
            }
            
            let currentTime = CACurrentMediaTime()
            let deltaTime = Float(currentTime - lastTime)
            lastTime = currentTime
            
            // Update particles
            renderer.update(
                deltaTime: deltaTime,
                screenWidth: Float(bounds.width),
                screenHeight: Float(bounds.height),
                particleAreaHeight: particleAreaHeight
            )
            
            // Render particles
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            
            renderer.render(renderPassDescriptor: renderPassDescriptor)
            
            // Present the drawable
            let commandQueue = renderer.commandQueue
            if let commandBuffer = commandQueue.makeCommandBuffer() {
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
        }
    }
}
