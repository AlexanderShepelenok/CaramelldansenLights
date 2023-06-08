//
//  MetalTextureFactory.swift
//  StrobeLights
//
//  Created by Aleksandr Shepelenok on 2.06.23.
//

import CoreVideo
import Metal

final class MetalTextureFactory {

  // MARK: Lifecycle

  init(device: MTLDevice) {
    var textureCache: CVMetalTextureCache?
    guard
      CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) == kCVReturnSuccess,
      let textureCache
    else {
      fatalError("Unable to allocate texture cache.")
    }
    self.device = device
    self.textureCache = textureCache
  }

  // MARK: Internal

  func createTexture(from buffer: CVPixelBuffer) -> MTLTexture? {
    let bufferWidth = CVPixelBufferGetWidth(buffer)
    let bufferHeight = CVPixelBufferGetHeight(buffer)
    var cvMetalTexture: CVMetalTexture?
    CVMetalTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault,
      textureCache,
      buffer,
      nil,
      .bgra8Unorm,
      Int(bufferWidth),
      Int(bufferHeight),
      0,
      &cvMetalTexture)

    guard let cvMetalTexture = cvMetalTexture else { return nil }
    return CVMetalTextureGetTexture(cvMetalTexture)
  }

  func createSharedBufferTexture(width: Int, height: Int) -> MTLTexture? {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel

    let alignment = device.minimumLinearTextureAlignment(for: .bgra8Unorm)
    let alignedBytesPerRow = ((bytesPerRow + alignment - 1) / alignment) * alignment
    let bufferSize = alignedBytesPerRow * height

    guard
      let buffer = device.makeBuffer(
        length: bufferSize,
        options: .storageModeShared) else { return nil }

    let textureDescriptor = MTLTextureDescriptor()
    textureDescriptor.textureType = .type2D
    textureDescriptor.pixelFormat = .bgra8Unorm
    textureDescriptor.width = width
    textureDescriptor.height = height
    textureDescriptor.usage = [.shaderRead, .shaderWrite]

    return buffer.makeTexture(
      descriptor: textureDescriptor,
      offset: 0,
      bytesPerRow: alignedBytesPerRow)
  }

  func pixelBuffer(from texture: MTLTexture) -> CVPixelBuffer? {
    guard let buffer = texture.buffer else { return nil }
    let pixelFormat = kCVPixelFormatType_32BGRA
    let width = texture.width
    let height = texture.height
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreateWithBytes(
      //        texture.bufferBytesPerRow
      nil, width, height, pixelFormat, buffer.contents(), 4352, nil, nil, nil, &pixelBuffer)

    guard status == kCVReturnSuccess else {
      return nil
    }

    return pixelBuffer
  }

  // MARK: Private

  private let device: MTLDevice
  private let textureCache: CVMetalTextureCache

}
