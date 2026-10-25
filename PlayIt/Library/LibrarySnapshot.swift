import Foundation

/// A group of rows under one section index letter.
struct IndexedSection<ID: Hashable & Sendable>: Identifiable, Sendable {
  let letter: String
  let ids: [ID]
  var id: String { letter }
}

/// An immutable, fully indexed view of the library. Built off the main actor
/// whenever the library changes.
struct LibrarySnapshot: Sendable {
  let tracks: [Track.ID: Track]
  let albums: [Album.ID: Album]
  let artists: [Artist.ID: Artist]
  let systemPlaylists: [Playlist]

  let tracksByTitle: [IndexedSection<Track.ID>]
  let tracksByDateAdded: [Track.ID]
  let albumsByTitle: [IndexedSection<Album.ID>]
  let artistsByName: [IndexedSection<Artist.ID>]
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

    tracksByTitle = Self.sections(trackList, id: \.id, name: \.title)
    tracksByDateAdded = trackList.sorted { $0.dateAdded > $1.dateAdded }.map(\.id)
    albumsByTitle = Self.sections(Array(albums.values), id: \.id, name: \.title)
    artistsByName = Self.sections(Array(artists.values), id: \.id, name: \.name)
    searchIndex = SearchIndex(
      tracks: trackList, albums: Array(albums.values), artists: Array(artists.values))
  }

  // MARK: - Lookups

  func tracks(_ ids: some Sequence<Track.ID>) -> [Track] {
    ids.compactMap { tracks[$0] }
  }

  /// Every track by an artist: albums by title, each in track order.
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

  /// Sorts by `SortKey` and groups by first letter, with "#" last like the
  /// Music app.
  private static func sections<T, ID: Hashable & Sendable>(
    _ items: [T], id: (T) -> ID, name: (T) -> String
  ) -> [IndexedSection<ID>] {
    let keyed = items
      .map { (key: SortKey.make(name($0)), id: id($0)) }
      .sorted { SortKey.less($0.key, $1.key) }
    var result: [IndexedSection<ID>] = []
    var other: [ID] = []
    var letter: String?
    var ids: [ID] = []
    for item in keyed {
      let section = SortKey.section(item.key)
      if section == "#" {
        other.append(item.id)
        continue
      }
      if section != letter {
        if let letter { result.append(IndexedSection(letter: letter, ids: ids)) }
        letter = section
        ids = []
      }
      ids.append(item.id)
    }
    if let letter { result.append(IndexedSection(letter: letter, ids: ids)) }
    if !other.isEmpty { result.append(IndexedSection(letter: "#", ids: other)) }
    return result
  }
}
