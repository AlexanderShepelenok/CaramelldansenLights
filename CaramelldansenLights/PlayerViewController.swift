//
//  PlayerViewController.swift
//  Caramellights
//
//  Created by Aleksandr Shepelenok on 31.05.23.
//

import AVKit

class PlayerViewController: AVPlayerViewController {

    let url: URL

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        player = AVPlayer(url: url)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareButtonTapped))

        self.navigationItem.rightBarButtonItem = shareButton
    }

    @objc func shareButtonTapped() {
        guard let player = self.player else { return }
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        self.present(activityViewController, animated: true, completion: nil)
    }

}
