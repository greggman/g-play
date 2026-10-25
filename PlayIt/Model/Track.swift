import Foundation

/// A song in the library. Our own value type so nothing outside `Library/`
/// and `Playback/` touches `MPMediaItem`.
struct Track: Identifiable, Hashable, Sendable, Codable {
  typealias ID = UInt64

  let id: ID
  let title: String
  let artist: String
  let artistID: UInt64
  let album: String
  let albumID: UInt64
  let albumArtist: String
  let trackNumber: Int
  let discNumber: Int
  let duration: TimeInterval
  let dateAdded: Date
  let lastPlayedDate: Date?
  let playCount: Int
}

struct Album: Identifiable, Hashable, Sendable {
  typealias ID = UInt64

  let id: ID
  let title: String
  let artist: String
  let artistID: UInt64
  /// In disc / track order.
  let trackIDs: [Track.ID]
  /// A track whose artwork represents the album.
  let artworkTrackID: Track.ID
}

struct Artist: Identifiable, Hashable, Sendable {
  typealias ID = UInt64

  let id: ID
  let name: String
  /// Sorted by album title.
  let albumIDs: [Album.ID]
  let trackCount: Int
  let artworkTrackID: Track.ID
}

enum PlaylistID: Hashable, Sendable, Codable {
  /// A playlist from the Music app. Read-only.
  case system(UInt64)
  /// A playlist owned by Play-It. Fully editable.
  case app(UUID)
}

struct Playlist: Identifiable, Hashable, Sendable {
  let id: PlaylistID
  var name: String
  var trackIDs: [Track.ID]

  var isEditable: Bool {
    if case .app = id { return true }
    return false
  }
}
