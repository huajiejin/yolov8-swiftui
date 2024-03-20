//
//  ContentView.swift
//  YOLOv8SwiftUI
//
//  Created by Jin on 2024-03-19.
//

import SwiftUI
import os.log
import AVFoundation
import UIKit
import Vision
import CoreML

struct ContentView: View {
    @StateObject private var model = DataModel()
    
    var body: some View {
        GeometryReader { geometry in
            if let previewImage = model.previewImage {
                previewImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .overlay {
                        GeometryReader { (geometry: GeometryProxy) in
                            ForEach(model.recognizedObjects){ obj in
                                BoundingBox(imageViewGeometry: geometry, label: obj.label, rect: obj.boundingBox, color: Color.red, hideLabel: false)
                            }
                        }
                    }
            }
        }
        .ignoresSafeArea()
        .background(.black)
        .onDisappear {
            model.camera.stop()
        }
        .onAppear {
            Task {
                await model.camera.start()
            }
        }
    }

    // Draw a bounding box around the recognized object
    private func BoundingBox(imageViewGeometry: GeometryProxy, label: String, rect: CGRect, color: Color, hideLabel: Bool) -> some View {
        let cgRect = self.denormalize(imageViewSize: imageViewGeometry.size, normalizedCGRect: rect)
            return Rectangle().path(in: cgRect)
                .stroke(color, lineWidth: 2.0)
                .overlay {
                    hideLabel ? nil : Text(label)
                        .foregroundColor(.white)
                        .background(Color.red)
                        .position(x: cgRect.minX, y: cgRect.minY)
                }
    }
    
    // Convert the normalized CGRect to a denormalized CGRect
    private func denormalize(imageViewSize: CGSize, normalizedCGRect: CGRect) -> CGRect {
        let imageViewWidth = imageViewSize.width
        let imageViewHeight = imageViewSize.height

        // Flip the Y coordinate, because the Vision framework uses a coordinate system with the origin in the bottom-left corner, while the SwiftUI uses a coordinate system with the origin in the top-left corner.
        let flippedY = 1.0 - normalizedCGRect.maxY
        return CGRect(x: normalizedCGRect.minX * imageViewWidth, y: flippedY * imageViewHeight, width: normalizedCGRect.width * imageViewWidth, height: normalizedCGRect.height * imageViewHeight)
    }
    
    @MainActor class DataModel : ObservableObject {
        @Published var previewImage: Image?
        @Published var recognizedObjects: [RecognizedObject] = []
        
        private var YOLOv8Model: VNCoreMLModel?
        let camera = Camera()
        
        init() {
            if let model = try? YOLOv8s().model {
                if let vnModel = try? VNCoreMLModel(for: model) {
                    YOLOv8Model = vnModel
                }
            }
            if let _ = YOLOv8Model {
                logger.info("Loaded YOLOv8n model")
            } else {
                logger.error("Failed to load YOLOv8n model")
            }
            
            Task {
                await camera.start()
                await consumePreviewStream()
            }
        }
        
        private func consumePreviewStream() async {
            for await ciImage in camera.previewStream.stream {
                Task { @MainActor in
                    let ciContext = CIContext()
                    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
                    previewImage = Image(decorative: cgImage, scale: 1)

                    if let YOLOv8nModel = self.YOLOv8Model {
                        // Create a VNCoreMLRequest with the YOLOv8 model
                        let request = VNCoreMLRequest(model: YOLOv8nModel) { (request, error) in
                            if let error = error {
                                logger.error("Failed to process YOLOv8n model: \(error)")
                                return
                            }
                            
                            // Process the results
                            if let results = request.results as? [VNRecognizedObjectObservation] {
                                // get results with confidence > 0.9
                                let results = results.filter { $0.labels[0].confidence > 0.9 }
                                // convert the results to RecognizedObject
                                self.recognizedObjects = results.map { $0.toRecognizedObject($0) }
                            }
                        }
                        // Create a VNImageRequestHandler with the previewImage
                        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                        // Perform the request
                        do {
                            try handler.perform([request])
                        } catch {
                            print("Failed to perform request: \(error)")
                        }
                    }
                }
            }
        }
    }
}

struct RecognizedObject: Identifiable {
    var id: UUID = UUID()
    var label: String
    var boundingBox: CGRect
}

extension VNRecognizedObjectObservation {
    // Convert a VNRecognizedObjectObservation to a RecognizedObject
    func toRecognizedObject(_ observation: VNRecognizedObjectObservation) -> RecognizedObject {
        let firstLabel = observation.labels.first?.identifier ?? "unknown"
        return RecognizedObject(label: firstLabel, boundingBox: observation.boundingBox)
    }
}

fileprivate let logger = Logger(subsystem: "com.jinshub.yolov8swiftui", category: "ContentView")
