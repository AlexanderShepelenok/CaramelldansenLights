//
//  SongProvider.swift
//  StrobeLights
//
//  Created by Aleksandr Shepelenok on 1.06.23.
//

import Foundation

final class SongProvider {

  private enum Defaults {
    static let song = "electronic_rock_70"
  }

  private enum UserDefaultsKeys {
    static let selectedSong = "song"
  }

  private enum Resources {
    static let songsJSON = "songs.json"
  }

  var selectedSong: Song {
    let selectedSongKey = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedSong)
    ?? Defaults.song
    guard
      let songDetails = songs[selectedSongKey],
      let url = Bundle.main.url( forResource: selectedSongKey, withExtension: songDetails.format)
    else {
      fatalError("Unable to load song from resources")
    }
    return Song(url: url, details: songDetails)
  }

  private let songs: [String: SongDetails]

  // MARK: Lifecycle

  init() {
    guard
      let jsonURL = Bundle.main.url(forResource: Resources.songsJSON, withExtension: nil),
      let jsonData = try? Data(contentsOf: jsonURL),
      let songs = try? JSONDecoder().decode([String: SongDetails].self, from: jsonData)
    else {
      fatalError("Unable to read Songs JSON resource")
    }
    self.songs = songs
  }
}
