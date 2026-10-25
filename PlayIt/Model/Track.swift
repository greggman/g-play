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

extension Track {
  static let unknownTitle = String(localized: "Unknown Title")
  static let unknownArtist = String(localized: "Unknown Artist")
  static let unknownAlbum = String(localized: "Unknown Album")

  /// Builds a track from library metadata, filling in missing names.
  ///
  /// The library gives each song with no album name its own album ID, so
  /// an artist's album-less songs would show as many untitled albums. They
  /// are grouped instead into one "Unknown Album" per album artist.
  static func fromLibrary(
    id: ID, title: String?, artist: String?, artistID: UInt64,
    album: String?, albumID: UInt64, albumArtist: String?, albumArtistID: UInt64,
    trackNumber: Int, discNumber: Int, duration: TimeInterval,
    dateAdded: Date, lastPlayedDate: Date?, playCount: Int
  ) -> Track {
    let album = nonBlank(album)
    let groupArtistID = albumArtistID != 0 ? albumArtistID : artistID
    return Track(
      id: id,
      title: nonBlank(title) ?? unknownTitle,
      artist: nonBlank(artist) ?? unknownArtist,
      artistID: artistID,
      album: album ?? unknownAlbum,
      albumID: album == nil ? unknownAlbumID(forArtist: groupArtistID) : albumID,
      albumArtist: nonBlank(albumArtist) ?? "",
      trackNumber: trackNumber,
      discNumber: discNumber,
      duration: duration,
      dateAdded: dateAdded,
      lastPlayedDate: lastPlayedDate,
      playCount: playCount)
  }

  /// A made-up album ID for an artist's songs with no album.
  static func unknownAlbumID(forArtist artistID: UInt64) -> Album.ID {
    artistID ^ 0x5EED_0F0A_1B0C_0000
  }

  private static func nonBlank(_ s: String?) -> String? {
    guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return s
  }
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

  /// Songs with no album name, grouped by artist.
  var isUnknown: Bool { title == Track.unknownAlbum }
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
