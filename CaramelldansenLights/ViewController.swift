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
        let rendererPipelineState: MTLRenderPipelineState
        let computePipelineState: MTLComputePipelineState
        let textureCache: CVMetalTextureCache
    }

    @IBOutlet var mtkView: MTKView!
    
    private var texture: MTLTexture?
    private var currentMaskIndex: Int?
    private var timer: Timer?
    private var recorder: VideoRecorder?
    
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

        guard
            let computeFunction = library?.makeFunction(name: "write_texture"),
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
                        rendererPipelineState: renderPipelineState,
                        computePipelineState: computePipelineState,
                        textureCache: textureCache)
    }()

    lazy var camera: Camera = {
        $0.delegate = self
        return $0
    }(Camera())

    override func viewDidLoad() {
        super.viewDidLoad()

        mtkView.delegate = self
        mtkView.device = renderer.device
    }

    override func viewWillAppear(_ animated: Bool) {
        camera.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        camera.stop()
    }

    @IBAction func startAction(_ sender: Any) {
//        let videoSize = camera.videoSize
//        recorder = VideoRecorder(videoWidth: videoSize.height, videoHeight: videoSize.width)
//        recorder?.start()
        let interval = TimeInterval(0.5)
        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] time in
            self?.switchMask()
        }
    }
    
    @IBAction func stopAction(_ sender: Any) {
//        recorder?.stop { [weak self] videoURL in
//            if let videoURL {
//                DispatchQueue.main.async {
//                    self?.playVideo(url: videoURL)
//                    self?.recorder = nil
//                }
//            }
//        }
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

struct FragmentUniform {
    let mask: simd_float4
}

extension ViewController: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {

        guard let currentDrawable = view.currentDrawable else { return }
        let vertices = Constants.vertices
        guard
            let renderPassDescriptor = mtkView.currentRenderPassDescriptor,
            let commandBuffer = renderer.commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
            let vertexBuffer = renderer.device.makeBuffer(bytes: vertices,
                                                          length: vertices.count * MemoryLayout<Vertex>.stride,
                                                          options: [])
        else {
            print("Failed to draw vertices")
            return
        }

        if let texture {
            renderEncoder.setFragmentTexture(texture, index: 0)
            let aspectRatio = Double(texture.width) / Double(texture.height)
            renderEncoder.setViewport(MTLViewport(originX: 0,
                                                  originY: 0,
                                                  width: Double(mtkView.drawableSize.width),
                                                  height: Double(mtkView.drawableSize.width) * aspectRatio,
                                                  znear: 0,
                                                  zfar: 0))
        }

        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setRenderPipelineState(renderer.rendererPipelineState)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
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
            bufferWidth,
            bufferHeight,
            0,
            &cvMetalTexture
        )

        if let cvMetalTexture,
           let cameraTexture = CVMetalTextureGetTexture(cvMetalTexture),
           let outputTexture = createOutputTexture(width: bufferHeight, height: bufferWidth) {
            applyMetalShaders(to: cameraTexture, outputTexture: outputTexture)
            self.texture = outputTexture
        }
    }

    func applyMetalShaders(to texture: MTLTexture, outputTexture: MTLTexture) {
        var currentMask = Constants.emptyMask
        if let currentMaskIndex {
            currentMask = Constants.masks[currentMaskIndex]
        }
        let uniforms = FragmentUniform(mask: currentMask)

        guard
            let commandBuffer = renderer.commandQueue.makeCommandBuffer(),
            let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
            let colorMaskBuffer = renderer.device.makeBuffer(bytes: [uniforms],
                                                            length: MemoryLayout<FragmentUniform>.stride,
                                                            options: [])
        else {
            print("Failed to draw vertices")
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
