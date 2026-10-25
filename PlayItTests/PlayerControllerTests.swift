import Foundation
import Testing
@testable import PlayIt

@MainActor
final class FakeEngine: PlaybackEngine {
  weak var delegate: PlaybackEngineDelegate?
  var managesNowPlaying = true
  var isPlaying = false
  var currentTime: TimeInterval = 0
  var currentTrackID: Track.ID?
  var upcoming: [Track.ID] = []
  var setQueueCount = 0

  func setQueue(current: Track, upcoming: [Track], startTime: TimeInterval, play: Bool) {
    setQueueCount += 1
    currentTrackID = current.id
    self.upcoming = upcoming.map(\.id)
    currentTime = startTime
    isPlaying = play
  }

  func setUpcoming(_ upcoming: [Track]) { self.upcoming = upcoming.map(\.id) }

  func stop() {
    currentTrackID = nil
    upcoming = []
    isPlaying = false
  }

  func play() { isPlaying = true }
  func pause() { isPlaying = false }
  func seek(to time: TimeInterval) { currentTime = time }

  /// Simulates the current track ending.
  func finishTrack() {
    currentTrackID = upcoming.isEmpty ? nil : upcoming.removeFirst()
    currentTime = 0
    delegate?.engine(self, didMoveTo: currentTrackID)
  }
}

@MainActor
struct PlayerControllerTests {
  let engine = FakeEngine()
  let snapshot = LibrarySnapshot(tracks: (1...10).map { makeTrack(UInt64($0), number: $0) }, systemPlaylists: [])

  func makePlayer(store: StateStore? = nil) -> PlayerController {
    let player = PlayerController(engine: engine, store: store)
    player.libraryDidLoad(snapshot)
    return player
  }

  @Test func playLoadsEngineWithWholeQueue() {
    let player = makePlayer()
    player.play(mode: .album(1), trackIDs: [1, 2, 3])
    #expect(engine.currentTrackID == 1)
    #expect(engine.upcoming == [2, 3])
    #expect(player.isPlaying)
    #expect(player.currentTrack?.id == 1)
  }

  @Test func queueingUpdatesUpcomingWithoutRestarting() {
    let player = makePlayer()
    player.play(mode: .album(1), trackIDs: [1, 2, 3])
    let loads = engine.setQueueCount
    player.playNext([5])
    player.playLater([6])
    #expect(engine.setQueueCount == loads)
    #expect(engine.upcoming == [5, 6, 2, 3])
  }

  @Test func playNowRestartsEngine() {
    let player = makePlayer()
    player.play(mode: .album(1), trackIDs: [1, 2])
    player.playNow([7])
    #expect(engine.currentTrackID == 7)
    #expect(engine.upcoming == [2])
  }

  @Test func engineAdvancingUpdatesQueue() {
    let player = makePlayer()
    player.play(mode: .album(1), trackIDs: [1, 2, 3])
    player.playNext([9])
    engine.finishTrack()
    #expect(player.queue.current == 9)
    engine.finishTrack()
    #expect(player.queue.current == 2)
    #expect(player.recentlyPlayed[9] != nil)
  }

  @Test func syncAfterSuspension() {
    let player = makePlayer()
    player.play(mode: .album(1), trackIDs: [1, 2, 3, 4])
    // The engine moved on while the app wasn't told.
    engine.currentTrackID = 3
    player.syncWithEngine()
    #expect(player.queue.current == 3)
    #expect(engine.upcoming == [4])
  }

  @Test func previousRestartsWhenPastThreshold() {
    let player = makePlayer()
    player.play(mode: .album(1), trackIDs: [1, 2])
    player.next()
    engine.currentTime = 30
    player.previous()
    #expect(player.queue.current == 2)
    #expect(engine.currentTime == 0)
    player.previous()
    #expect(player.queue.current == 1)
  }

  @Test func nextAtEndStops() {
    let player = makePlayer()
    player.play(mode: .track(1), trackIDs: [1])
    player.next()
    #expect(player.currentTrack == nil)
    #expect(engine.currentTrackID == nil)
  }

  @Test func shuffleAllPlaysEverything() {
    let player = makePlayer()
    player.shuffleAll()
    #expect(player.queue.mode == .allTracks)
    #expect(Set(player.queue.modeTrackIDs) == Set(1...10))
  }

  @Test func restoresSavedStatePaused() {
    let store = StateStore(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
    defer { store.reset() }
    let first = makePlayer(store: store)
    first.play(mode: .album(1), trackIDs: [1, 2, 3])
    first.playLater([8])
    first.seek(to: 12)
    first.pause()

    let engine2 = FakeEngine()
    let second = PlayerController(engine: engine2, store: store)
    second.libraryDidLoad(snapshot)
    #expect(second.queue == first.queue)
    #expect(engine2.currentTrackID == 1)
    #expect(engine2.currentTime == 12)
    #expect(!engine2.isPlaying)
  }
}
