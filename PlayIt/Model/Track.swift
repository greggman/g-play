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
  static let variousArtists = String(localized: "Various Artists")

  /// Builds a track from library metadata, filling in missing names.
  ///
  /// Albums are grouped by name, not by the library's album ID, which can
  /// split one album into several (and gives every song with no album name
  /// its own ID). Songs with the same album name are one album, unless
  /// they're by different album artists. Compilations group by name alone.
  /// Songs with no album name form one "Unknown Album" per artist.
  static func fromLibrary(
    id: ID, title: String?, artist: String?, artistID: UInt64,
    album: String?, albumArtist: String?, isCompilation: Bool,
    trackNumber: Int, discNumber: Int, duration: TimeInterval,
    dateAdded: Date, lastPlayedDate: Date?, playCount: Int
  ) -> Track {
    let album = nonBlank(album)
    let artist = nonBlank(artist) ?? unknownArtist
    let albumArtist = nonBlank(albumArtist) ?? (isCompilation && album != nil ? variousArtists : nil)
    return Track(
      id: id,
      title: nonBlank(title) ?? unknownTitle,
      artist: artist,
      artistID: artistID,
      album: album ?? unknownAlbum,
      albumID: albumID(name: album ?? "", artist: albumArtist ?? artist),
      albumArtist: albumArtist ?? "",
      trackNumber: trackNumber,
      discNumber: discNumber,
      duration: duration,
      dateAdded: dateAdded,
      lastPlayedDate: lastPlayedDate,
      playCount: playCount)
  }

  /// A stable ID for an album name and artist (FNV-1a hash), ignoring case
  /// and accents.
  static func albumID(name: String, artist: String) -> Album.ID {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in "\(SortKey.fold(name))\u{1}\(SortKey.fold(artist))".utf8 {
      hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
    }
    return hash
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
