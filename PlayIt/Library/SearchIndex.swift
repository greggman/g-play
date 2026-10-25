import Foundation

/// In-memory search over track titles, album titles and artist names.
/// Case- and diacritic-insensitive. Matches at the start of a word rank above
/// matches elsewhere.
struct SearchIndex: Sendable {
  struct Results: Sendable, Equatable {
    var artists: [Artist.ID] = []
    var albums: [Album.ID] = []
    var tracks: [Track.ID] = []

    var isEmpty: Bool { artists.isEmpty && albums.isEmpty && tracks.isEmpty }
  }

  private struct Entry<ID: Sendable>: Sendable {
    let id: ID
    let folded: String
    let sortKey: String
  }

  private let tracks: [Entry<Track.ID>]
  private let albums: [Entry<Album.ID>]
  private let artists: [Entry<Artist.ID>]

  init(tracks: [Track], albums: [Album], artists: [Artist]) {
    self.tracks = tracks.map { Entry(id: $0.id, folded: SortKey.fold($0.title), sortKey: SortKey.make($0.title)) }
    self.albums = albums.map { Entry(id: $0.id, folded: SortKey.fold($0.title), sortKey: SortKey.make($0.title)) }
    self.artists = artists.map { Entry(id: $0.id, folded: SortKey.fold($0.name), sortKey: SortKey.make($0.name)) }
  }

  func search(_ query: String, limit: Int = 200) -> Results {
    let q = SortKey.fold(query).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return Results() }
    return Results(
      artists: Self.match(q, in: artists, limit: limit),
      albums: Self.match(q, in: albums, limit: limit),
      tracks: Self.match(q, in: tracks, limit: limit))
  }

  /// Ranks: exact match, then prefix, then word-prefix, then substring.
  private static func match<ID>(_ q: String, in entries: [Entry<ID>], limit: Int) -> [ID] {
    var ranked: [(rank: Int, key: String, id: ID)] = []
    for entry in entries {
      guard let range = entry.folded.range(of: q) else { continue }
      let rank: Int
      if entry.folded == q {
        rank = 0
      } else if range.lowerBound == entry.folded.startIndex {
        rank = 1
      } else if !entry.folded[entry.folded.index(before: range.lowerBound)].isLetter {
        rank = 2
      } else {
        rank = 3
      }
      ranked.append((rank, entry.sortKey, entry.id))
    }
    ranked.sort { $0.rank != $1.rank ? $0.rank < $1.rank : SortKey.less($0.key, $1.key) }
    return ranked.prefix(limit).map(\.id)
  }
}
