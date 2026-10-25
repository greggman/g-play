import Foundation
import Testing
@testable import PlayIt

func makeTrack(
  _ id: Track.ID, title: String = "Song", artist: String = "Artist", artistID: UInt64 = 1,
  album: String = "Album", albumID: UInt64 = 1, number: Int = 1, lastPlayed: Date? = nil,
  added: Date = .distantPast
) -> Track {
  Track(
    id: id, title: title, artist: artist, artistID: artistID, album: album, albumID: albumID,
    albumArtist: "", trackNumber: number, discNumber: 1, duration: 200, dateAdded: added,
    lastPlayedDate: lastPlayed, playCount: 0)
}

struct WeightedShuffleTests {
  let now = Date(timeIntervalSinceReferenceDate: 1_000_000_000)

  @Test func weights() {
    #expect(WeightedShuffle.weight(lastPlayed: nil, now: now) == WeightedShuffle.neverPlayedWeight)
    #expect(WeightedShuffle.weight(lastPlayed: now, now: now) == 1)
    #expect(WeightedShuffle.weight(lastPlayed: now.addingTimeInterval(-10 * 86_400), now: now) == 11)
    #expect(WeightedShuffle.weight(lastPlayed: now.addingTimeInterval(-5_000 * 86_400), now: now) == 366)
  }

  @Test func everyTrackExactlyOnce() {
    let tracks = (0..<1_000).map { makeTrack(UInt64($0)) }
    var rng = SplitMix64(seed: 1)
    let order = WeightedShuffle.order(tracks, now: now, using: &rng)
    #expect(order.count == tracks.count)
    #expect(Set(order) == Set(tracks.map(\.id)))
  }

  @Test func deterministicWithSeed() {
    let tracks = (0..<100).map { makeTrack(UInt64($0)) }
    var a = SplitMix64(seed: 7)
    var b = SplitMix64(seed: 7)
    #expect(WeightedShuffle.order(tracks, now: now, using: &a) == WeightedShuffle.order(tracks, now: now, using: &b))
  }

  /// Tracks not played for a long time should land earlier on average than
  /// tracks played today.
  @Test func longUnplayedTracksComeFirst() {
    let recent = (0..<500).map { makeTrack(UInt64($0), lastPlayed: now) }
    let old = (500..<1_000).map { makeTrack(UInt64($0), lastPlayed: now.addingTimeInterval(-300 * 86_400)) }
    var rng = SplitMix64(seed: 3)
    let order = WeightedShuffle.order(recent + old, now: now, using: &rng)
    let position = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
    let averageRecent = recent.map { Double(position[$0.id]!) }.reduce(0, +) / 500
    let averageOld = old.map { Double(position[$0.id]!) }.reduce(0, +) / 500
    #expect(averageOld < averageRecent - 300)
    // The first 100 should be nearly all old tracks.
    #expect(order.prefix(100).filter { $0 >= 500 }.count > 95)
  }

  @Test func recentlyPlayedOverridesLibraryDate() {
    let tracks = (0..<200).map { makeTrack(UInt64($0), lastPlayed: nil) }
    let played = Dictionary(uniqueKeysWithValues: (0..<100).map { (UInt64($0), now) })
    var rng = SplitMix64(seed: 9)
    let order = WeightedShuffle.order(tracks, now: now, recentlyPlayed: played, using: &rng)
    #expect(order.prefix(50).filter { $0 >= 100 }.count > 45)
  }
}

struct SortKeyTests {
  @Test func stripsArticlesAndFolds() {
    #expect(SortKey.make("The Beatles") == "beatles")
    #expect(SortKey.make("A Tribe Called Quest") == "tribe called quest")
    #expect(SortKey.make("An Horse") == "horse")
    #expect(SortKey.make("Théâtre") == "theatre")
    #expect(SortKey.make("The") == "the")
    #expect(SortKey.make("Theory") == "theory")
  }

}

struct LibrarySnapshotTests {
  let snapshot = LibrarySnapshot(
    tracks: [
      makeTrack(1, title: "Zebra", artist: "The Bands", artistID: 10, album: "Second", albumID: 100, number: 2),
      makeTrack(2, title: "apple", artist: "The Bands", artistID: 10, album: "Second", albumID: 100, number: 1),
      makeTrack(3, title: "Éclair", artist: "Cool", artistID: 20, album: "First", albumID: 200, number: 1,
                added: Date(timeIntervalSince1970: 100)),
      makeTrack(4, title: "1999", artist: "The Bands", artistID: 10, album: "Aardvark", albumID: 300, number: 1),
    ],
    systemPlaylists: [Playlist(id: .system(1), name: "P", trackIDs: [3, 99, 1])])

  @Test func tracksSortedByTitle() {
    #expect(snapshot.tracksByTitle.map(\.id) == [4, 2, 3, 1])
  }

  @Test func albumsInTrackOrder() {
    #expect(snapshot.albums[100]?.trackIDs == [2, 1])
  }

  @Test func artistAlbumsAndTracks() {
    #expect(snapshot.artists[10]?.albumIDs == [300, 100])
    #expect(snapshot.trackIDs(forArtist: 10) == [4, 2, 1])
    #expect(snapshot.artistsByName.map(\.id) == [10, 20])
  }

  @Test func dateAddedNewestFirst() {
    #expect(snapshot.tracksByDateAdded.first?.id == 3)
  }

  @Test func playlistsDropMissingTracks() {
    #expect(snapshot.systemPlaylists[0].trackIDs == [3, 1])
  }

  @Test func search() {
    let index = snapshot.searchIndex
    #expect(index.search("ecl").tracks == [3])
    #expect(index.search("BANDS").artists == [10])
    #expect(index.search("ar").albums == [300])
    #expect(index.search("  ").isEmpty)
    #expect(index.search("nothing").isEmpty)
  }

  @Test func searchRanksPrefixFirst() {
    let index = SearchIndex(
      tracks: [makeTrack(1, title: "Brown Sugar"), makeTrack(2, title: "Sugar"), makeTrack(3, title: "Sugarcane")],
      albums: [], artists: [])
    #expect(index.search("sugar").tracks == [2, 3, 1])
  }

  @Test func fixtureLibraryIsConsistent() {
    let (tracks, playlists) = FixtureMusicLibrary.generate(trackCount: 400)
    let snapshot = LibrarySnapshot(tracks: tracks, systemPlaylists: playlists)
    #expect(snapshot.tracks.count == 400)
    #expect(snapshot.albums.count == 40)
    #expect(snapshot.artists.count == 10)
    #expect(snapshot.albums.values.allSatisfy { !$0.trackIDs.isEmpty })
    #expect(FixtureMusicLibrary.generate(trackCount: 400).0 == tracks)
  }
}

struct StateStoreTests {
  @Test func roundTrip() throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    let store = StateStore(directory: directory)
    defer { store.reset() }
    #expect(store.loadPlayerState() == nil)
    #expect(store.loadPlaylists().isEmpty)

    var queue = PlayQueue()
    queue.play(mode: .playlist(.app(UUID())), trackIDs: [1, 2, 3])
    queue.playLater([7])
    let state = PlayerState(queue: queue, currentTime: 42, recentlyPlayed: [1: Date(timeIntervalSince1970: 5)])
    store.save(state)
    #expect(store.loadPlayerState() == state)

    let playlists = [StoredPlaylist(id: UUID(), name: "Mine", trackIDs: [3, 3, 1])]
    store.save(playlists)
    #expect(store.loadPlaylists() == playlists)
  }
}
