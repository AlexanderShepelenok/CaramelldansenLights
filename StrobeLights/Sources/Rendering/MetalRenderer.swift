//
//  Renderer.swift
//  StrobeLights
//
//  Created by Aleksandr Shepelenok on 2.06.23.
//

import CoreVideo
import Metal
import MetalKit
import simd

final class MetalRenderer {

  // MARK: Lifecycle

  init(colorPixelFormat: MTLPixelFormat) {
    guard
      let device = MTLCreateSystemDefaultDevice(),
      let commandQueue = device.makeCommandQueue()
    else {
      fatalError("Unable to init Metal")
    }

    let library = device.makeDefaultLibrary()
    let vertexFunction = library?.makeFunction(name: "vertex_main")
    let fragmentFunction = library?.makeFunction(name: "fragment_main")

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat

    guard
      let renderPipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else
    {
      fatalError("Unable to create pipeline")
    }

    guard
      let computeFunction = library?.makeFunction(name: "compute_color"),
      let computePipelineState = try? device.makeComputePipelineState(function: computeFunction)
    else {
      fatalError("Unable to create pipeline")
    }

    var textureCache: CVMetalTextureCache?
    guard
      CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess,
      let textureCache = textureCache
    else {
      fatalError("Unable to allocate texture cache.")
    }

    self.device = device
    self.commandQueue = commandQueue
    self.renderPipelineState = renderPipelineState
    self.computePipelineState = computePipelineState
    self.textureCache = textureCache
  }

  // MARK: Internal

  let device: MTLDevice

  func renderTexture(_ texture: MTLTexture?, in view: MTKView) {
    guard let currentDrawable = view.currentDrawable else { return }

    guard
      let renderPassDescriptor = view.currentRenderPassDescriptor,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
      let vertexBuffer = device.makeBuffer(
        bytes: Constants.vertices,
        length: Constants.vertices.count * MemoryLayout<Vertex>.stride,
        options: [])
    else {
      return
    }

    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    if let texture {
      renderEncoder.setFragmentTexture(texture, index: 0)
    }
    renderEncoder.setRenderPipelineState(renderPipelineState)
    renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: Constants.vertices.count)
    renderEncoder.endEncoding()

    commandBuffer.present(currentDrawable)
    commandBuffer.commit()
  }

  func applyMask(_ mask: simd_float4, to inputTexture: MTLTexture, outputTexture: MTLTexture) {
    let outputSize = simd_uint2(UInt32(outputTexture.width), UInt32(outputTexture.height))
    let colorUniform = Uniforms(mask: mask, outputSize: outputSize)
    guard
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
      let colorMaskBuffer = device.makeBuffer(
        bytes: [colorUniform],
        length: MemoryLayout<Uniforms>.stride,
        options: [])
    else {
      return
    }

    computeEncoder.setComputePipelineState(computePipelineState)

    computeEncoder.setTexture(inputTexture, index: 0)
    computeEncoder.setTexture(outputTexture, index: 1)
    computeEncoder.setBuffer(colorMaskBuffer, offset: 0, index: 0)

    let threadGroupCount = MTLSize(width: 8, height: 8, depth: 1)
    let threadGroups = MTLSize(
      width: (inputTexture.width + threadGroupCount.width - 1) / threadGroupCount.width,
      height: (inputTexture.height + threadGroupCount.height - 1) / threadGroupCount.height,
      depth: 1)
    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)

    computeEncoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
  }

  // MARK: Private

  private enum Constants {
    static let vertices = [
      Vertex(position: [-1, -1]),
      Vertex(position: [1, -1]),
      Vertex(position: [-1, 1]),
      Vertex(position: [1, 1])
    ]
  }

  private let commandQueue: MTLCommandQueue
  private let renderPipelineState: MTLRenderPipelineState
  private let computePipelineState: MTLComputePipelineState
  private let textureCache: CVMetalTextureCache
}
