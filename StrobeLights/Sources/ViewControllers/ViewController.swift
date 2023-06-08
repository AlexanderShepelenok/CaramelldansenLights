//
//  ViewController.swift
//  StrobeLights
//
//  Created by Aleksandr Shepelenok on 23.02.23.
//

import CoreVideo
import MetalKit
import UIKit

import AVFoundation
import AVKit

// MARK: - ViewController

class ViewController: UIViewController {

  @IBOutlet private var mtkView: MTKView!

  private var texture: MTLTexture?
  private var timer: Timer?
  private var player: AVAudioPlayer?
  private var recorder: VideoRecorder?

  private lazy var colorMaskProvider = ColorMaskProvider()
  private lazy var songProvider = SongProvider()
  private lazy var textureFactory: MetalTextureFactory = .init(device: renderer.device)

  private lazy var camera: Camera = {
    $0.delegate = self
    return $0
  }(Camera())

  private lazy var renderer: MetalRenderer = .init(colorPixelFormat: mtkView.colorPixelFormat)

  // MARK: - ViewController lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    mtkView.delegate = self
    mtkView.device = renderer.device
  }

  override func viewWillAppear(_: Bool) {
    camera.start()
  }

  override func viewWillDisappear(_: Bool) {
    camera.stop()
  }

  // MARK: Private

  @IBAction private func startAction(_: Any) {
    let song = songProvider.selectedSong
    guard let player = try? AVAudioPlayer(contentsOf: song.url) else {
      fatalError("Unable to create AudioPlayer for selected song")
    }

    player.prepareToPlay()
    self.player = player

    if let texture {
      recorder = try? VideoRecorder(videoWidth: texture.width,
                                    videoHeight: texture.height,
                                    song: song)
      recorder?.start()
      let interval = TimeInterval(60.0 / Double(song.details.bpm))
      timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        self?.colorMaskProvider.switchMask()
      }
      timer?.fire()
      player.play()
    }
  }

  @IBAction private func stopAction(_: Any) {
    recorder?.stop { [weak self] videoURL in
      if let videoURL {
        DispatchQueue.main.async {
          self?.playVideo(url: videoURL)
          self?.recorder = nil
        }
      }
    }
    player?.stop()
    player?.currentTime = 0
    timer?.invalidate()
    timer = nil
    colorMaskProvider.reset()
  }

}

// MARK: MTKViewDelegate

extension ViewController: MTKViewDelegate {
  func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) { }

  func draw(in view: MTKView) {
    renderer.renderTexture(texture, in: view)
  }
}

// MARK: CameraDelegate

extension ViewController: CameraDelegate {

  func cameraDidOutputImageBuffer(_ buffer: CVPixelBuffer, presentationTime: CMTime) {
    guard
      let cameraTexture = textureFactory.createTexture(from: buffer),
      let outputTexture = textureFactory.createSharedBufferTexture(
        width: cameraTexture.height,
        height: cameraTexture.width)
    else { return }

    renderer.applyMask(colorMaskProvider.currentMask, to: cameraTexture, outputTexture: outputTexture)

    texture = outputTexture

    if let recorder, let pixelBuffer = textureFactory.pixelBuffer(from: outputTexture) {
      recorder.appendPixelBuffer(pixelBuffer, presentationTime: presentationTime)
    }
  }
}

extension ViewController {
  func playVideo(url: URL) {
    let playerViewController = PlayerViewController(url: url)
    let navigationViewController = UINavigationController(rootViewController: playerViewController)
    navigationViewController.modalPresentationStyle = .pageSheet
    present(navigationViewController, animated: true)
  }
}
