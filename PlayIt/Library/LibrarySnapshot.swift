import Foundation

/// An immutable, fully indexed view of the library. Built off the main actor
/// whenever the library changes.
struct LibrarySnapshot: Sendable {
  let tracks: [Track.ID: Track]
  let albums: [Album.ID: Album]
  let artists: [Artist.ID: Artist]
  let systemPlaylists: [Playlist]

  // Sorted lists hold values, not IDs, so a list's ForEach makes exactly one
  // row per element and SwiftUI only has to build the visible rows.
  let tracksByTitle: [Track]
  let tracksByDateAdded: [Track]
  let albumsByTitle: [Album]
  let artistsByName: [Artist]
  let searchIndex: SearchIndex

  static let empty = LibrarySnapshot(tracks: [], systemPlaylists: [])

  var isEmpty: Bool { tracks.isEmpty }

  init(tracks trackList: [Track], systemPlaylists: [Playlist]) {
    var tracks: [Track.ID: Track] = [:]
    tracks.reserveCapacity(trackList.count)
    for track in trackList { tracks[track.id] = track }
    self.tracks = tracks
    self.systemPlaylists = systemPlaylists.map { playlist in
      var playlist = playlist
      playlist.trackIDs = playlist.trackIDs.filter { tracks[$0] != nil }
      return playlist
    }

    // Albums, in disc / track order.
    let albumGroups = Dictionary(grouping: trackList, by: \.albumID)
    var albums: [Album.ID: Album] = [:]
    for (albumID, albumTracks) in albumGroups {
      let ordered = albumTracks.sorted {
        ($0.discNumber, $0.trackNumber, $0.title) < ($1.discNumber, $1.trackNumber, $1.title)
      }
      let first = ordered[0]
      let artist = first.albumArtist.isEmpty ? first.artist : first.albumArtist
      albums[albumID] = Album(
        id: albumID, title: first.album, artist: artist, artistID: first.artistID,
        trackIDs: ordered.map(\.id), artworkTrackID: first.id)
    }
    self.albums = albums

    // Artists, with their albums sorted by title.
    let artistGroups = Dictionary(grouping: trackList, by: \.artistID)
    var artists: [Artist.ID: Artist] = [:]
    for (artistID, artistTracks) in artistGroups {
      let albumIDs = Set(artistTracks.map(\.albumID)).sorted {
        SortKey.less(SortKey.make(albums[$0]?.title ?? ""), SortKey.make(albums[$1]?.title ?? ""))
      }
      artists[artistID] = Artist(
        id: artistID, name: artistTracks[0].artist, albumIDs: albumIDs,
        trackCount: artistTracks.count, artworkTrackID: artistTracks[0].id)
    }
    self.artists = artists

    tracksByTitle = Self.sorted(trackList, name: \.title)
    tracksByDateAdded = trackList.sorted { $0.dateAdded > $1.dateAdded }
    // "Unknown Album"s go last, by artist, as they have no title to sort by.
    let (unknownAlbums, namedAlbums) = albums.values.partitioned(by: \.isUnknown)
    albumsByTitle = Self.sorted(namedAlbums, name: \.title) + Self.sorted(unknownAlbums, name: \.artist)
    artistsByName = Self.sorted(Array(artists.values), name: \.name)
    searchIndex = SearchIndex(
      tracks: trackList, albums: Array(albums.values), artists: Array(artists.values))
  }

  // MARK: - Lookups

  func tracks(_ ids: some Sequence<Track.ID>) -> [Track] {
    ids.compactMap { tracks[$0] }
  }

  /// Every track by an artist: albums by title, each in track order.
  func tracks(forArtist id: Artist.ID) -> [Track] {
    tracks(trackIDs(forArtist: id))
  }

  func trackIDs(forArtist id: Artist.ID) -> [Track.ID] {
    guard let artist = artists[id] else { return [] }
    return artist.albumIDs.flatMap { albumID in
      (albums[albumID]?.trackIDs ?? []).filter { tracks[$0]?.artistID == id }
    }
  }

  func albumIDs(forArtist id: Artist.ID) -> [Album.ID] {
    artists[id]?.albumIDs ?? []
  }

  // MARK: - Private

  /// Items ordered by `SortKey` of their names.
  private static func sorted<T>(_ items: [T], name: (T) -> String) -> [T] {
    items
      .map { (key: SortKey.make(name($0)), item: $0) }
      .sorted { SortKey.less($0.key, $1.key) }
      .map(\.item)
  }
}

private extension Sequence {
  /// Elements where `predicate` is true, and where it's false.
  func partitioned(by predicate: (Element) -> Bool) -> ([Element], [Element]) {
    var matching: [Element] = []
    var rest: [Element] = []
    for element in self {
      if predicate(element) { matching.append(element) } else { rest.append(element) }
    }
    return (matching, rest)
  }
}
