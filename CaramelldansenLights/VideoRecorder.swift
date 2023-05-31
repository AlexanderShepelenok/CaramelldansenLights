
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
    private let audioInput: AVAssetWriterInput
    private let audioReaderOutput: AVAssetReaderOutput
    private let audioReader: AVAssetReader
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

        guard let audioURL = Bundle.main.url(forResource: "elbaion", withExtension: "m4a") else {
            fatalError("Unable to load audio from resources")
        }
        let audioAsset = AVURLAsset(url: audioURL)
        let audioTrack = audioAsset.tracks(withMediaType: .audio)[0]
        let formatDescription = audioTrack.formatDescriptions[0] as! CMFormatDescription
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: formatDescription)
        
        if assetWriter.canAdd(audioInput) {
            assetWriter.add(audioInput)
        }
        

        audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
        
        audioReader = try! AVAssetReader(asset: audioAsset)
        audioReader.add(audioReaderOutput)
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
                }
            }
        }
    }
    
    func stop(completion: @escaping () -> Void) {
        recorderQueue.async { [unowned self] in
            if isRecording {
                isRecording = false
                attachAudio()
                assetWriter.endSession(atSourceTime: latestRelativePresentationTime)
                assetWriter.finishWriting {
                    completion()
                }
            }
        }
    }
    
    func attachAudio() {
        audioReader.startReading()
        var isAttachingAudio = true
        while isAttachingAudio {
            if audioInput.isReadyForMoreMediaData,
               let audioBuffer = audioReaderOutput.copyNextSampleBuffer() {
                let audioSampleTime = CMSampleBufferGetPresentationTimeStamp(audioBuffer)
                if CMTimeCompare(audioSampleTime, latestRelativePresentationTime) <= 0 {
                    audioInput.append(audioBuffer)
                } else {
                    isAttachingAudio = false
                }
                
                CMSampleBufferInvalidate(audioBuffer)
            }
        }
        audioReader.cancelReading()
    }
}
