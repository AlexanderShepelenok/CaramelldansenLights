//
//  ViewController.swift
//  CaramelldansenLights
//
//  Created by Aleksandr Shepelenok on 23.02.23.
//

import UIKit
import MetalKit

class ViewController: UIViewController {

    struct Renderer {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let pipelineState: MTLRenderPipelineState
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

        return Renderer(device: device, commandQueue: queue, pipelineState: pipelineState)
    }()

    lazy var uniforms: Uniforms = {
        Uniforms(viewportSize: viewportSize(with: mtkView.drawableSize), modelViewMatrix: matrix_identity_float4x4)
    }()

    var angle: Float = 0.0

    override func viewDidLoad() {
        super.viewDidLoad()

        mtkView.delegate = self
        mtkView.device = renderer.device
    }

    private func viewportSize(with size: CGSize) -> simd_float2 {
        simd_float2(Float(size.width), Float(size.height))
    }

}

struct Vertex {
    let position: simd_float2
    let color: simd_float3
}

struct Uniforms {
    var viewportSize: simd_float2
    var modelViewMatrix: simd_float4x4
}

extension ViewController: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.viewportSize = viewportSize(with: size)
    }

    func draw(in view: MTKView) {
        angle += 1
        if angle >= 360 {
            angle = 0
        }
        let radians = angle * .pi / 180.0
        let rotationQuaternion = simd_quatf(angle: radians, axis: simd_float3(0, 0, 1))
        let rotationMatrix = simd_float4x4(rotationQuaternion)
        uniforms.modelViewMatrix = rotationMatrix

        guard let currentDrawable = view.currentDrawable else { return }

        let vertices = [
            Vertex(position: [-250, 250], color: [1, 0, 0]),
            Vertex(position: [250, 250], color: [1, 1, 0]),
            Vertex(position: [-250, -250], color: [0, 1, 1]),
            Vertex(position: [250, -250], color: [0, 1, 0])
        ]

        guard
            let renderPassDescriptor = mtkView.currentRenderPassDescriptor,
            let commandBuffer = renderer.commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
            let vertexBuffer = renderer.device.makeBuffer(bytes: vertices,
                                                          length: vertices.count * MemoryLayout<Vertex>.stride,
                                                          options: []),
            let uniformsBuffer = renderer.device.makeBuffer(bytes: [uniforms],
                                                            length: MemoryLayout<Uniforms>.stride,
                                                            options: [])
        else {
            print("Failed to draw vertices")
            return
        }

        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setRenderPipelineState(renderer.pipelineState)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        renderEncoder.endEncoding()

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }

}

