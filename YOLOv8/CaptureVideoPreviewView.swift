//
//  CaptureVideoPreviewView.swift
//  YOLOv8
//
//  Created by Jin on 2023-05-29.
//

import SwiftUI
import AVFoundation

struct CaptureVideoPreviewView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CaptureVideoPreviewViewController {
        let captureVideoPreviewViewController = CaptureVideoPreviewViewController()
        return captureVideoPreviewViewController
    }
    
    func updateUIViewController(_ uiViewController: CaptureVideoPreviewViewController, context: Context) {}
    
    func makeCoordinator() -> () {
        
    }
}

class CaptureVideoPreviewViewController: UIViewController {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }

        do {
            let videoInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession = AVCaptureSession()
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoQueue"))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
            
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
        } catch {
            print("Error setting up capture session \(error)")
            AlertHelper.showAlert(title: "Oops!", message: "Error setting up capture session", buttonTitle: "OK")
        }
    }
}

extension CaptureVideoPreviewViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
}
