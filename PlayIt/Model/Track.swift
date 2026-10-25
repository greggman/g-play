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
  /// See `Track.groupAlbums`.
  var albumID: UInt64
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

  /// Builds a track from library metadata, filling in missing names. Call
  /// `groupAlbums` on the results to finish assigning album IDs.
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
      // Songs with no album name: one "Unknown Album" per artist.
      albumID: albumID(name: album ?? "", artist: album == nil ? artist : ""),
      albumArtist: albumArtist ?? "",
      trackNumber: trackNumber,
      discNumber: discNumber,
      duration: duration,
      dateAdded: dateAdded,
      lastPlayedDate: lastPlayedDate,
      playCount: playCount)
  }

  /// Assigns album IDs by album name rather than the library's album ID,
  /// which can split one album into several and gives every song with no
  /// album name its own ID.
  ///
  /// Songs with the same album name are one album, even when tracks are by
  /// different artists, as on most soundtracks, and even when only some
  /// tracks have an album artist. A name is split only when there's
  /// evidence of different albums:
  /// - more than one album artist: split by album artist (tracks without
  ///   one join the album artist matching their artist, if any), or
  /// - the same disc and track number by two different artists (two
  ///   "Greatest Hits"): split by album artist, else artist.
  static func groupAlbums(_ tracks: [Track]) -> [Track] {
    var tracks = tracks
    let groups = Dictionary(grouping: tracks.indices, by: { tracks[$0].albumID })
    for indices in groups.values where tracks[indices[0]].album != unknownAlbum {
      let albumArtists = Set(indices.map { SortKey.fold(tracks[$0].albumArtist) }.filter { !$0.isEmpty })
      let splitArtist: (Track) -> String
      if albumArtists.count > 1 {
        splitArtist = { track in
          if !track.albumArtist.isEmpty { return track.albumArtist }
          return albumArtists.contains(SortKey.fold(track.artist)) ? track.artist : ""
        }
      } else if hasTrackNumberClash(indices.map { tracks[$0] }) {
        splitArtist = { $0.albumArtist.isEmpty ? $0.artist : $0.albumArtist }
      } else {
        continue
      }
      for i in indices {
        tracks[i].albumID = albumID(name: tracks[i].album, artist: splitArtist(tracks[i]))
      }
    }
    return tracks
  }

  /// Whether the same disc and track number appears under different artists.
  private static func hasTrackNumberClash(_ tracks: [Track]) -> Bool {
    var artistsByPosition: [String: Set<String>] = [:]
    for track in tracks where track.trackNumber > 0 {
      artistsByPosition["\(track.discNumber)-\(track.trackNumber)", default: []].insert(SortKey.fold(track.artist))
    }
    return artistsByPosition.values.contains { $0.count > 1 }
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
