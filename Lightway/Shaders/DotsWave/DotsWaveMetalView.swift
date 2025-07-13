import MetalKit
import SwiftUI

/// SwiftUI wrapper for our Metal‐backed dot‐wave renderer, with a transparent background.
struct DotsWaveMetalView: UIViewRepresentable {
    func makeCoordinator() -> DotsWaveRenderer { DotsWaveRenderer() }

    func makeUIView(context: Context) -> MTKView {
        let mtk = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        guard let device = mtk.device else {
            fatalError("Metal not supported on this device")
        }

        // Make Metal view transparent
        mtk.isOpaque = false
        mtk.backgroundColor = .clear
        mtk.layer.isOpaque = false
        // ClearColor alpha = 0 so we draw nothing behind the dots
        mtk.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtk.colorPixelFormat = .bgra8Unorm

        // Drive continuous redraw
        mtk.enableSetNeedsDisplay = false
        mtk.isPaused = false
        mtk.preferredFramesPerSecond = 60

        mtk.delegate = context.coordinator
        context.coordinator.setup(device: device, view: mtk)
        return mtk
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}

/// Handles the Metal rendering of the wave dots.
class DotsWaveRenderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var queue: MTLCommandQueue!
    var pipeline: MTLRenderPipelineState!
    var startTime: CFTimeInterval = CACurrentMediaTime()

    func setup(device: MTLDevice, view: MTKView) {
        self.device = device
        queue = device.makeCommandQueue()

        let lib = device.makeDefaultLibrary()!
        let vFunc = lib.makeFunction(name: "vertexShader")
        let fFunc = lib.makeFunction(name: "fragmentShader")

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vFunc
        desc.fragmentFunction = fFunc
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat

        // Enable alpha blending so dots blend over transparent background
        let att = desc.colorAttachments[0]!
        att.isBlendingEnabled = true
        att.rgbBlendOperation = .add
        att.alphaBlendOperation = .add
        att.sourceRGBBlendFactor = .sourceAlpha
        att.sourceAlphaBlendFactor = .sourceAlpha
        att.destinationRGBBlendFactor = .oneMinusSourceAlpha
        att.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipeline = try! device.makeRenderPipelineState(descriptor: desc)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let passDesc = view.currentRenderPassDescriptor
        else { return }

        let cb = queue.makeCommandBuffer()!
        let encoder = cb.makeRenderCommandEncoder(descriptor: passDesc)!
        encoder.setRenderPipelineState(pipeline)

        var u = DotsWaveUniforms(
            time: Float(CACurrentMediaTime() - startTime),
            resolution: float2(
                Float(view.drawableSize.width),
                Float(view.drawableSize.height)
            ),
            dotSize: 9.0,
            spacing: 11.0,
            waveWidth: 0.8,
            peakFlatFraction: 0.1,
            baseOpacity: 0.0,
            peakOpacity: 1.0,
            animationSpeed: 1.75,
            falloffExponent: 6.0,
            minBrightness: 0.3
        )
        encoder.setVertexBytes(
            &u,
            length: MemoryLayout<DotsWaveUniforms>.stride,
            index: 1
        )
        encoder.setFragmentBytes(
            &u,
            length: MemoryLayout<DotsWaveUniforms>.stride,
            index: 1
        )

        // Render full‐screen quad
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        cb.present(drawable)
        cb.commit()
    }
}

/// Shared uniforms must match the layout in the .metal shader.
struct DotsWaveUniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var dotSize: Float
    var spacing: Float
    var waveWidth: Float
    var peakFlatFraction: Float
    var baseOpacity: Float
    var peakOpacity: Float
    var animationSpeed: Float
    var falloffExponent: Float
    var minBrightness: Float
}
