//
//  CameraView.swift
//  Lightway
//
//  Created by Alexandru Simedrea on 13.07.2025.
//

import SwiftUI
import AVKit

struct CameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> CameraPreviewView {
        let cameraView = CameraPreviewView()
        cameraView.startSession()
        return cameraView
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
    }
}

class CameraPreviewView: UIView {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high

        guard let captureSession = captureSession else { return }

        guard
            let backCamera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ),
            let input = try? AVCaptureDeviceInput(device: backCamera)
        else {
            print("Failed to create camera input")
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill

        if let previewLayer = previewLayer {
            layer.addSublayer(previewLayer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

#Preview {
    CameraView()
}
