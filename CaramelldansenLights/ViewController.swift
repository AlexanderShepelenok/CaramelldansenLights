//
//  ViewController.swift
//  CaramelldansenLights
//
//  Created by Aleksandr Shepelenok on 23.02.23.
//

import UIKit
import MetalKit
import CoreVideo

import AVFoundation
import AVKit

class ViewController: UIViewController {
    
    private enum Constants {
        static let masks: [simd_float4] = {
            [simd_float4(1.0, 1.0, 0.35, 1.0),
             simd_float4(0.35, 1.0, 1.0, 1.0),
             simd_float4(1.0, 0.35, 0.35, 1.0),
             simd_float4(0.35, 1.0, 0.35, 1.0),
             simd_float4(0.35, 0.35, 1.0, 1.0),
             simd_float4(1.0, 0.5, 0.2, 1.0),
             simd_float4(1.0, 0.35, 1.0, 1.0)]
        }()
        static let emptyMask = simd_float4(repeating: 1.0)
        static let vertices = [
            Vertex(position: [-1, -1]),
            Vertex(position: [1, -1]),
            Vertex(position: [-1, 1]),
            Vertex(position: [1, 1])
        ]
    }
    
    struct Renderer {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let renderPipelineState: MTLRenderPipelineState
        let computePipelineState: MTLComputePipelineState
        let textureCache: CVMetalTextureCache
    }
    
    @IBOutlet var mtkView: MTKView!
    
    private var texture: MTLTexture?
    private var currentMaskIndex: Int?
    private var timer: Timer?
    private var player: AVAudioPlayer?
    private var recorder: VideoRecorder?
    
    weak var bufferAddress: CVPixelBuffer? = nil
    
    lazy var camera: Camera = {
        $0.delegate = self
        return $0
    }(Camera())
    
    lazy var renderer: Renderer = {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("Unable to init Metal")
        }
        
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        guard let renderPipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
            fatalError("Unable to create pipeline")
        }

        guard let computeFunction = library?.makeFunction(name: "compute_color"),
              let computePipelineState = try? device.makeComputePipelineState(function: computeFunction) else {
            fatalError("Unable to create pipeline")
        }

        var textureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess,
              let textureCache = textureCache else {
            fatalError("Unable to allocate texture cache.")
        }
        
        return Renderer(device: device,
                        commandQueue: queue,
                        renderPipelineState: renderPipelineState,
                        computePipelineState: computePipelineState,
                        textureCache: textureCache)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView.delegate = self
        mtkView.device = renderer.device
        
        guard let url = Bundle.main.url(forResource: "elbaion", withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { fatalError() }
        
        player.prepareToPlay()
        self.player = player
    }
    
    override func viewWillAppear(_ animated: Bool) {
        camera.start()
    }
    
    @IBAction func startAction(_ sender: Any) {
        let videoSize = camera.videoSize
        recorder = VideoRecorder(videoWidth: videoSize.height, videoHeight: videoSize.width)
        recorder?.start()
        let interval = TimeInterval(60.0 / 93.0)
        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] time in
            self?.switchMask()
        }
        player?.play()
    }
    
    @IBAction func stopAction(_ sender: Any) {
        recorder?.stop { [weak self] in
            if let url = self?.recorder?.fileUrl {
                DispatchQueue.main.async {
                    self?.playVideo(url: url)
                    self?.recorder = nil
                }
            }
        }
        player?.stop()
        player?.currentTime = 0
        self.timer?.invalidate()
        self.timer = nil
        self.currentMaskIndex = nil
    }
    
    private func switchMask() {
        guard var newIndex = self.currentMaskIndex else {
            self.currentMaskIndex = 0
            return
        }
        newIndex += 1
        if newIndex > Constants.masks.count - 1 {
            newIndex = 0
        }
        self.currentMaskIndex = newIndex
    }
}

struct Vertex {
    let position: simd_float2
}

struct Uniforms {
    let mask: simd_float4
    let outputSize: simd_uint2
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let currentDrawable = view.currentDrawable else { return }
        
        guard
            let renderPassDescriptor = mtkView.currentRenderPassDescriptor,
            let commandBuffer = renderer.commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
            let vertexBuffer = renderer.device.makeBuffer(bytes: Constants.vertices,
                                                          length: Constants.vertices.count * MemoryLayout<Vertex>.stride,
                                                          options: [])
        else {
            print("Failed to draw vertices")
            return
        }
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        if let texture = self.texture {
            renderEncoder.setFragmentTexture(texture, index: 0)
        }
        renderEncoder.setRenderPipelineState(renderer.renderPipelineState)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: Constants.vertices.count)
        renderEncoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

extension ViewController: CameraDelegate {
    
    // MARK: - Camera delegate
    
    func cameraDidOutputImageBuffer(_ buffer: CVPixelBuffer, presentationTime: CMTime) {
        let bufferWidth = CVPixelBufferGetWidth(buffer)
        let bufferHeight = CVPixelBufferGetHeight(buffer)
        var cvMetalTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            renderer.textureCache,
            buffer,
            nil,
            .bgra8Unorm,
            Int(bufferWidth),
            Int(bufferHeight),
            0,
            &cvMetalTexture
        )
        
        guard let cvMetalTexture = cvMetalTexture else { return }
        guard let texture = CVMetalTextureGetTexture(cvMetalTexture),
        let outputTexture = createOutputTexture(width: bufferHeight, height: bufferWidth) else { return }
        
        applyMetalShaders(to: texture, outputTexture: outputTexture)
        
        self.texture = outputTexture
        
        if let recorder, let pixelBuffer = pixelBuffer(fromTexture: outputTexture) {
            recorder.appendPixelBuffer(pixelBuffer, presentationTime: presentationTime)
        }
    }
    
    func applyMetalShaders(to texture: MTLTexture, outputTexture: MTLTexture) {
        let commandQueue = renderer.commandQueue
        var currentMask = Constants.emptyMask
        if let maskIndex = self.currentMaskIndex {
            currentMask = Constants.masks[maskIndex]
        }
        let outputSize = simd_uint2(UInt32(outputTexture.width), UInt32(outputTexture.height))
        let colorUniform = Uniforms(mask: currentMask, outputSize: outputSize)
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let colorMaskBuffer = renderer.device.makeBuffer(bytes: [colorUniform],
                                                               length: MemoryLayout<Uniforms>.stride,
                                                               options: [])
        else {
            return
        }


        computeEncoder.setComputePipelineState(renderer.computePipelineState)

        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        computeEncoder.setBuffer(colorMaskBuffer, offset: 0, index: 0)

        let threadGroupCount = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(width: (texture.width + threadGroupCount.width - 1) / threadGroupCount.width,
                                   height: (texture.height + threadGroupCount.height - 1) / threadGroupCount.height,
                                   depth: 1)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    
    func createOutputTexture(width: Int, height: Int) -> MTLTexture? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        let alignment = renderer.device.minimumLinearTextureAlignment(for: .bgra8Unorm)
        let alignedBytesPerRow = ((bytesPerRow + alignment - 1) / alignment) * alignment
        let bufferSize = alignedBytesPerRow * height

        guard let buffer = renderer.device.makeBuffer(length: bufferSize,
                                                      options: .storageModeShared) else { return nil }
        
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        return buffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: alignedBytesPerRow)
    }
    
    func pixelBuffer(fromTexture texture: MTLTexture) -> CVPixelBuffer? {
        guard let buffer = texture.buffer else { print("No buffer!!!"); return nil }
        let pixelFormat = kCVPixelFormatType_32BGRA
        let width = texture.width
        let height = texture.height

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(nil, width, height, pixelFormat, buffer.contents(), 4352, nil, nil, nil, &pixelBuffer)

        guard status == kCVReturnSuccess else {
            print("error!!! \(status)")
            return nil
        }

        return pixelBuffer
    }
}

extension ViewController {
    
    func playVideo(url: URL) {
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.modalPresentationStyle = .pageSheet
        present(playerViewController, animated: true)
    }
}
