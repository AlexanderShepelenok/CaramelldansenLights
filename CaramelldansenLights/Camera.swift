//
//  Camera.swift
//  Caramellights
//
//  Created by Aleksandr Shepelenok on 5.04.23.
//

import Foundation
import AVFoundation

final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let cameraQueue = DispatchQueue(label: "com.zoobras.CaramelldansenLights.cameraQueue")
    private let bufferQueue = DispatchQueue(label: "com.zoobras.CaramelldansenLights.cameraBufferQueue")

    weak var delegate: CameraDelegate?

    override init() {
        super.init()
        cameraQueue.async {
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
                fatalError("🚨 Unable to initialize camera")
            }
            if self.captureSession.canAddInput(videoInput) {
                self.captureSession.addInput(videoInput)
            }
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            videoOutput.alwaysDiscardsLateVideoFrames = true

            self.captureSession.addOutput(videoOutput)
        }
    }

    func start() {
        cameraQueue.async {
            self.captureSession.startRunning()
        }
    }

    func stop() {
        cameraQueue.async {
            self.captureSession.stopRunning()
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate implementation

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        delegate?.cameraDidOutputImageBuffer(buffer)
    }
}

protocol CameraDelegate: AnyObject {
    func cameraDidOutputImageBuffer(_ buffer: CVPixelBuffer)
}
