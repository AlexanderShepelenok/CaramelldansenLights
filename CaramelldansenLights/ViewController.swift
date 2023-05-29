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
        let pipelineState: MTLRenderPipelineState
        let textureCache: CVMetalTextureCache
    }
    
    struct Computer {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let pipelineState: MTLComputePipelineState
    }
    
    @IBOutlet var mtkView: MTKView!
    
    private var texture: MTLTexture?
    private var currentMaskIndex: Int?
    private var timer: Timer?
    private var player: AVAudioPlayer?
    private var recorder: VideoRecorder?
    
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
        
        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
            fatalError("Unable to create pipeline")
        }
        
        var textureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess,
              let textureCache = textureCache else {
            fatalError("Unable to allocate texture cache.")
        }
        
        return Renderer(device: device, commandQueue: queue, pipelineState: pipelineState, textureCache: textureCache)
    }()
    
    lazy var computer: Computer = {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("Unable to init Metal")
        }
        
        let library = device.makeDefaultLibrary()

        guard let computeFunction = library?.makeFunction(name: "compute_color"),
              let pipelineState = try? device.makeComputePipelineState(function: computeFunction) else {
            fatalError("Unable to create pipeline")
        }
        
        return Computer(device: device, commandQueue: queue, pipelineState: pipelineState)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView.delegate = self
        mtkView.device = renderer.device
        
        guard let url = Bundle.main.url(forResource: "jagermeister", withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url) else { fatalError() }
        
        player.prepareToPlay()
        self.player = player
    }
    
    override func viewWillAppear(_ animated: Bool) {
        camera.start()
    }
    
    @IBAction func startAction(_ sender: Any) {
        let videoSize = camera.videoSize
        recorder = VideoRecorder(videoWidth: videoSize.width, videoHeight: videoSize.height)
        recorder?.start()
        let interval = TimeInterval(60.0 / 150.0)
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
        renderEncoder.setRenderPipelineState(renderer.pipelineState)
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
        var textureOutput: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            renderer.textureCache,
            buffer,
            nil,
            .bgra8Unorm,
            Int(bufferWidth),
            Int(bufferHeight),
            0,
            &textureOutput
        )
        
        guard let textureOutput = textureOutput else { return }
        guard let texture = CVMetalTextureGetTexture(textureOutput) else { return }
        
        applyMetalShaders(to: texture)
        
        self.texture = texture
        
        recorder?.appendPixelBuffer(buffer, presentationTime: presentationTime)
    }
    
    func applyMetalShaders(to texture: MTLTexture) {
        let commandQueue = computer.commandQueue
        var currentMask = Constants.emptyMask
        if let maskIndex = self.currentMaskIndex {
            currentMask = Constants.masks[maskIndex]
        }
        let colorUniform = Uniforms(mask: currentMask)
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let colorMaskBuffer = computer.device.makeBuffer(bytes: [colorUniform],
                                                           length: MemoryLayout<Uniforms>.stride,
                                                           options: [])
        else {
            return
        }


        // Set the compute pipeline state
        computeEncoder.setComputePipelineState(computer.pipelineState)

        // Set the input and output textures for the shader
        computeEncoder.setTexture(texture, index: 0)
        computeEncoder.setBuffer(colorMaskBuffer, offset: 0, index: 0)

        // Dispatch the compute shader
        let threadGroupCount = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(width: (texture.width + threadGroupCount.width - 1) / threadGroupCount.width,
                                   height: (texture.height + threadGroupCount.height - 1) / threadGroupCount.height,
                                   depth: 1)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)

        // End encoding and commit the command buffer
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
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
