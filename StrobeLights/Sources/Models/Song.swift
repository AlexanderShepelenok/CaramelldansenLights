//
//  Song.swift
//  StrobeLights
//
//  Created by Aleksandr Shepelenok on 1.06.23.
//

import Foundation

struct Song {
  let url: URL
  let details: SongDetails

  init(url: URL, details: SongDetails) {
    self.url = url
    self.details = details
  }
}
