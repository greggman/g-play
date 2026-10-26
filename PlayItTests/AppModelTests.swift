import Foundation
import Testing
@testable import PlayIt

@MainActor
struct AppModelTests {
  let engine = FakeEngine()

  private func loadedModel() async throws -> AppModel {
    let model = AppModel(library: FixtureMusicLibrary(trackCount: 100), engine: engine, store: nil)
    Task { await model.start() }
    for _ in 0..<200 where model.snapshot.isEmpty {
      try await Task.sleep(for: .milliseconds(10))
    }
    try #require(!model.snapshot.isEmpty)
    return model
  }

  /// Picking a song from a list keeps playing that list, in its order.
  @Test(arguments: [MediaRef.songs, .recentlyAdded])
  func playingFromAListContinuesThroughIt(list: MediaRef) async throws {
    let model = try await loadedModel()
    let ids = model.trackIDs(for: list)
    model.play(list, startingAt: ids[10])
    #expect(model.player.queue.current == ids[10])
    #expect(Array(model.player.queue.upcomingTrackIDs.prefix(5)) == Array(ids[11..<16]))
    #expect(model.router.isShowingNowPlaying)
  }

  @Test func recentlyAddedIsNewestFirst() async throws {
    let model = try await loadedModel()
    let dates = model.trackIDs(for: .recentlyAdded).compactMap { model.track($0)?.dateAdded }
    #expect(dates == dates.sorted(by: >))
  }

  @Test func playingFromSearchResultsContinuesThroughThem() async throws {
    let model = try await loadedModel()
    let results = model.trackIDs(for: .searchResults("love"))
    try #require(results.count > 3)
    model.play(.searchResults("love"), startingAt: results[1])
    #expect(model.player.queue.current == results[1])
    #expect(model.player.queue.upcomingTrackIDs == Array(results[2...]))
    #expect(model.title(for: model.player.queue.mode!) == "Search “love”")
  }

  @Test func shufflePlaylistPlaysAllOfItShuffled() async throws {
    let model = try await loadedModel()
    let playlist = try #require(model.snapshot.systemPlaylists.first)
    let ids = model.trackIDs(for: .playlist(playlist.id))
    model.shuffle(.playlist(playlist.id))
    let queue = model.player.queue
    #expect(queue.mode == .playlist(playlist.id))
    #expect(queue.modeTrackIDs.sorted() == ids.sorted())
    #expect(queue.modeTrackIDs != ids)
    #expect(model.router.isShowingNowPlaying)
  }

  @Test func playNextDoesNotNavigate() async throws {
    let model = try await loadedModel()
    model.playNext(.track(model.trackIDs(for: .songs)[0]))
    #expect(!model.router.isShowingNowPlaying)
  }
}
