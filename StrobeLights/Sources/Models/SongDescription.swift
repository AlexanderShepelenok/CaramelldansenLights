//
//  SongDetails.swift
//  StrobeLights
//
//  Created by Aleksandr Shepelenok on 1.06.23.
//

struct SongDetails: Decodable {
  enum CodingKeys: String, CodingKey {
    case format
    case name
    case bpm
  }

  let format: String
  let name: String
  let bpm: Int
}
