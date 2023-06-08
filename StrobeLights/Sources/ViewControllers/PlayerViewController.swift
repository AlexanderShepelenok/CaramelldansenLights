//
//  PlayerViewController.swift
//  StrobeLights
//
//  Created by Aleksandr Shepelenok on 31.05.23.
//

import AVKit

class PlayerViewController: AVPlayerViewController {

  // MARK: Lifecycle

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  init(url: URL) {
    self.url = url
    super.init(nibName: nil, bundle: nil)
    player = AVPlayer(url: url)
  }

  // MARK: Internal

  let url: URL

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Recorded video"
    view.backgroundColor = .systemGray
    navigationController?.navigationBar.tintColor = .white
    navigationController?.navigationBar.backgroundColor = .systemGray

    let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareButtonTapped))
    navigationItem.rightBarButtonItem = shareButton
  }

  @objc
  func shareButtonTapped() {
    let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    present(activityViewController, animated: true, completion: nil)
  }
}
