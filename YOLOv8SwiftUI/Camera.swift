//
//  Camera.swift
//  YOLOv8SwiftUI
//
//  Created by Jin on 2024-03-19.
//

import AVFoundation
import os.log
import UIKit

class Camera : NSObject {
    public let photoStream = AsyncStream.makeStream(of: AVCapturePhoto.self)
    public let previewStream = AsyncStream.makeStream(of: CIImage.self)

    private let captureSession = {
        let _captureSession = AVCaptureSession()
        _captureSession.sessionPreset = AVCaptureSession.Preset.photo
        return _captureSession
    }()
    private let photoOutput = {
        AVCapturePhotoOutput()
    }()
    private let videoOutput = {
        AVCaptureVideoDataOutput()
    }()
    private var captureDevice : AVCaptureDevice? {
        AVCaptureDevice.default(for: .video)
    }
    private var isCaptureSessionConfigured = false
    private let sessionQueue = DispatchQueue(label: "CameraSessionQueue")

    public func start() async {
        logger.info("Starting camera")

        let authorized = await checkAuthorization()
        guard authorized else {
            logger.error("No access to camera")
            return
        }

        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async { [self] in
                    self.captureSession.startRunning()
                }
            }
        } else {
            // Configure the capture session
            sessionQueue.async { [self] in
                self.captureSession.beginConfiguration()
                
                defer {
                    self.captureSession.commitConfiguration()
                    if isCaptureSessionConfigured {
                        self.captureSession.startRunning()
                    }
                }
                
                guard let captureDevice = captureDevice,
                      let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
                else {
                    logger.error("Failed to get device input")
                    return
                }
                
                videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoOutput"))
                
                guard captureSession.canAddInput(deviceInput) else {
                    logger.error("Unable to add device input to capture session.")
                    return
                }
                
                guard captureSession.canAddOutput(photoOutput) else {
                    logger.error("Unable to add photo output to capture session.")
                    return
                }
                
                guard captureSession.canAddOutput(videoOutput) else {
                    logger.error("Unable to add video output to capture session.")
                    return
                }
                
                captureSession.addInput(deviceInput)
                captureSession.addOutput(photoOutput)
                captureSession.addOutput(videoOutput)
                captureSession.sessionPreset = .hd1920x1080
                
                isCaptureSessionConfigured = true
                logger.info("Camera is configured")
            }
        }
    }
    
    public func stop() {
        logger.info("Stopping camera")
        guard isCaptureSessionConfigured else {
            logger.info("Capture session is not configured.")
            return
        }
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    public func capturePhoto() {
        sessionQueue.async {
            var photoSettings = AVCapturePhotoSettings()
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            let isFlashAvailable = self.captureDevice?.isFlashAvailable ?? false
            photoSettings.flashMode = isFlashAvailable ? .auto : .off
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            let status = await AVCaptureDevice.requestAccess(for: .video)
            return status
        case .denied:
            return false
        case .restricted:
            return false
        default:
            return false
        }
    }
    
    private func getOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .portrait:
            return .right
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        default:
            return .right
        }
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    // Callback of photoOutput.capturePhoto()
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            logger.error("Error capturing photo: \(error.localizedDescription)")
            return
        }
        photoStream.continuation.yield(photo)
    }
}

// Callbacks of videoOutput.setSampleBufferDelegate()
extension Camera : AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }
        let ciImage = CIImage(cvImageBuffer: imageBuffer).oriented(getOrientation())
        previewStream.continuation.yield(ciImage)
    }
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        logger.debug("A video frame was discarded.")
    }
}

fileprivate let logger = Logger(subsystem: "com.jinshub.yolov8swiftui", category: "Camera")
