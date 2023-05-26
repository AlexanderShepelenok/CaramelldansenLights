
//  VideoRecorder.swift
//  Caramellights
//
//  Created by Aleksandr Shepelenok on 25.05.23.
//

import AVFoundation

final class VideoRecorder {
    
    let fileUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "output.mp4")
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    
    var isRecording = false
    
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
        if !isRecording {
            isRecording = true
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: .zero)
        }
    }
    
    func appendPixelBuffer(_ buffer: CVPixelBuffer, presentationTime: CMTime) {
        if isRecording {
            adaptor.append(buffer, withPresentationTime: presentationTime)
        }
    }
    
    func stop(completion: @escaping () -> Void) {
        if isRecording {
            isRecording = false
            assetWriter.finishWriting {
                completion()
            }
        }
    }
}
