//
//  ViewController.swift
//  CaramelldansenLights
//
//  Created by Aleksandr Shepelenok on 23.02.23.
//

import UIKit
import MetalKit

class ViewController: UIViewController {

    private enum Constants {
        static let vertices = [
            Vertex(position: [-1, 1]),
            Vertex(position: [1, 1]),
            Vertex(position: [-1, -1]),
            Vertex(position: [1, -1])
        ]

    }
    struct Renderer {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let pipelineState: MTLRenderPipelineState
        let textureCache: CVMetalTextureCache
    }

    @IBOutlet var mtkView: MTKView!

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

    lazy var camera: Camera = {
        $0.delegate = self
        return $0
    }(Camera())

    var texture: MTLTexture?

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
}

struct Vertex {
    let position: vector_float2
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
                                                          options: []) else {
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
        renderEncoder.setRenderPipelineState(renderer.pipelineState)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        renderEncoder.endEncoding()

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }

}

extension ViewController: CameraDelegate {
    // MARK: - Camera delegate

    func cameraDidOutputImageBuffer(_ buffer: CVPixelBuffer) {
        let bufferWidth = CVPixelBufferGetWidth(buffer)
        let bufferHeight = CVPixelBufferGetHeight(buffer)
        var textureOutput: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            renderer.textureCache,
            buffer,
            nil,
            .bgra8Unorm,
            bufferWidth,
            bufferHeight,
            0,
            &textureOutput
        )
        if let textureOutput = textureOutput {
            self.texture = CVMetalTextureGetTexture(textureOutput)
        }
    }
}
