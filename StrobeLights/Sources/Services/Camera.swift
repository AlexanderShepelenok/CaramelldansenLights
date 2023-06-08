//
//  Camera.swift
//  StrobeLights
//
//  Created by Aleksandr Shepelenok on 5.04.23.
//

import AVFoundation
import CoreMedia
import Foundation

// MARK: - Camera

final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

  private let captureSession = AVCaptureSession()
  private let videoCaptureDevice: AVCaptureDevice
  private let videoInput: AVCaptureDeviceInput
  private let cameraQueue = DispatchQueue(label: "com.alexshep.StrobeLights.cameraQueue")
  private let bufferQueue = DispatchQueue(label: "com.alexshep.StrobeLights.cameraBufferQueue")

  weak var delegate: CameraDelegate?

  // MARK: Lifecycle

  override init() {
    guard
      let videoCaptureDevice = AVCaptureDevice.default(for: .video),
      let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice)
    else {
      fatalError("Unable to initialize camera")
    }
    self.videoCaptureDevice = videoCaptureDevice
    self.videoInput = videoInput

    super.init()

    cameraQueue.async { [unowned self] in
      if self.captureSession.canAddInput(videoInput) {
        self.captureSession.addInput(videoInput)
      }
      let videoOutput = AVCaptureVideoDataOutput()
      videoOutput.setSampleBufferDelegate(self, queue: self.bufferQueue)
      videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
      videoOutput.alwaysDiscardsLateVideoFrames = true

      self.captureSession.addOutput(videoOutput)
    }
  }

  // MARK: Internal

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

  func captureOutput(_: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from _: AVCaptureConnection) {
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    delegate?.cameraDidOutputImageBuffer(buffer, presentationTime: presentationTime)
  }

}

// MARK: - CameraDelegate

protocol CameraDelegate: AnyObject {
  func cameraDidOutputImageBuffer(_ buffer: CVPixelBuffer, presentationTime: CMTime)
}
