//
//  ColorMaskProvider.swift
//  StrobeLights
//
//  Created by Aleksandr Shepelenok on 2.06.23.
//

import simd

final class ColorMaskProvider {

  private enum Constants {
    static let masks: [simd_float4] = {
      [
        simd_float4(1.0, 1.0, 0.35, 1.0),
        simd_float4(0.35, 1.0, 1.0, 1.0),
        simd_float4(1.0, 0.35, 0.35, 1.0),
        simd_float4(0.35, 1.0, 0.35, 1.0),
        simd_float4(0.35, 0.35, 1.0, 1.0),
        simd_float4(1.0, 0.5, 0.2, 1.0),
        simd_float4(1.0, 0.35, 1.0, 1.0)
      ]
    }()

    static let emptyMask = simd_float4(repeating: 1.0)
  }

  var currentMask: simd_float4 {
    guard let currentMaskIndex else { return Constants.emptyMask }
    return Constants.masks[currentMaskIndex]
  }

  private var currentMaskIndex: Int?

  // MARK: Internal

  func switchMask() {
    guard var newIndex = currentMaskIndex else {
      currentMaskIndex = 0
      return
    }
    newIndex += 1
    if newIndex > Constants.masks.count - 1 {
      newIndex = 0
    }
    currentMaskIndex = newIndex
  }

  func reset() {
    currentMaskIndex = nil
  }
}
