
//  VideoRecorder.swift
//  Caramellights
//
//  Created by Aleksandr Shepelenok on 25.05.23.
//

import AVFoundation

final class VideoRecorder {
    
    private let fileUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "output.mp4")
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    
    var isRecording = false
    var initialPresentationTime: CMTime?
    var latestRelativePresentationTime = CMTime.zero
    var currentAudioSampleBuffer: CMSampleBuffer?
    
    let recorderQueue = DispatchQueue(label: "com.zoobras.CaramelldansenLights.videoRecorderQueue")
    
    init(videoWidth: Int, videoHeight: Int) {
        self.assetWriter = try! AVAssetWriter(outputURL: fileUrl, fileType: AVFileType.mp4)
        let outputSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight
        ] as [String : Any]
        
        videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        videoInput.expectsMediaDataInRealTime = true
        assetWriter.add(videoInput)
        
        let sourcePixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
    }
    
    func start() {
        recorderQueue.async { [unowned self] in
            try? FileManager.default.removeItem(at: fileUrl)
            if !isRecording {
                isRecording = true
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: .zero)
            }
        }
    }
    
    func appendPixelBuffer(_ buffer: CVPixelBuffer, presentationTime: CMTime) {
        recorderQueue.sync { [unowned self] in
            if isRecording {
                if initialPresentationTime == nil { initialPresentationTime = presentationTime }
                let relativeTime = CMTimeSubtract(presentationTime, self.initialPresentationTime ?? presentationTime)
                if videoInput.isReadyForMoreMediaData {
                    adaptor.append(buffer, withPresentationTime: relativeTime)
                    latestRelativePresentationTime = relativeTime
                    print("data added! \(relativeTime.value)")
                }
            }
        }
    }
    
    func stop(completion: @escaping (URL?) -> Void) {
        recorderQueue.async { [unowned self] in
            if isRecording {
                isRecording = false
                assetWriter.endSession(atSourceTime: latestRelativePresentationTime)
                assetWriter.finishWriting {
                    completion(self.fileUrl)
                }
            }
        }
    }
}
