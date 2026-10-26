import Foundation
import Testing
@testable import PlayIt

struct PlayQueueTests {
  private func queue(mode ids: [Track.ID], start: Int = 0) -> PlayQueue {
    var q = PlayQueue()
    q.play(mode: .album(1), trackIDs: ids, startIndex: start)
    return q
  }

  @Test func playStartsModeAtIndex() {
    let q = queue(mode: [1, 2, 3], start: 1)
    #expect(q.current == 2)
    #expect(q.upcomingTrackIDs == [3])
    #expect(q.mode == .album(1))
  }

  @Test func playClearsTopQueue() {
    var q = queue(mode: [1, 2])
    q.playLater([9])
    q.play(mode: .artist(5), trackIDs: [7, 8])
    #expect(q.topQueue.isEmpty)
    #expect(q.current == 7)
    #expect(q.history == [1])
  }

  @Test func playNextGoesToFrontOfTopQueue() {
    var q = queue(mode: [1, 2, 3])
    q.playLater([10])
    q.playNext([20, 21])
    #expect(q.upcomingTrackIDs == [20, 21, 10, 2, 3])
  }

  @Test func playLaterGoesToBackOfTopQueue() {
    var q = queue(mode: [1, 2])
    q.playLater([10])
    q.playLater([11])
    #expect(q.upcomingTrackIDs == [10, 11, 2])
  }

  @Test func playNowPlaysImmediatelyAndKeepsRestQueued() {
    var q = queue(mode: [1, 2])
    q.playLater([10])
    q.playNow([20, 21])
    #expect(q.current == 20)
    #expect(q.upcomingTrackIDs == [21, 10, 2])
    #expect(q.history == [1])
  }

  @Test func topQueueDrainsBackToMode() {
    var q = queue(mode: [1, 2, 3])
    q.playNext([10])
    #expect(q.advance() == 10)
    #expect(q.currentSource == .topQueue)
    #expect(q.advance() == 2)
    #expect(q.currentSource == .mode)
    #expect(q.advance() == 3)
    #expect(q.advance() == nil)
    #expect(q.history == [1, 10, 2, 3])
  }

  @Test func queueingWhenIdleStartsPlaying() {
    var q = PlayQueue()
    q.playLater([5])
    #expect(q.current == 5)
    #expect(q.topQueue.isEmpty)
  }

  @Test func goBackReturnsModeTrack() {
    var q = queue(mode: [1, 2, 3])
    q.advance()
    let ok = q.goBack()
    #expect(ok)
    #expect(q.current == 1)
    #expect(q.upcomingTrackIDs == [2, 3])
  }

  @Test func goBackPutsTopQueueTrackBack() {
    var q = queue(mode: [1, 2])
    q.playNow([10])
    let ok = q.goBack()
    #expect(ok)
    #expect(q.current == 1)
    #expect(q.upcomingTrackIDs == [10, 2])
  }

  @Test func goBackWithNoHistoryFails() {
    var q = queue(mode: [1])
    let ok = q.goBack()
    #expect(!ok)
    #expect(q.current == 1)
  }

  @Test func goBackTwiceThenForward() {
    var q = queue(mode: [1, 2, 3])
    q.advance()
    q.advance()
    q.goBack()
    q.goBack()
    #expect(q.current == 1)
    #expect(q.advance() == 2)
    #expect(q.advance() == 3)
    #expect(q.advance() == nil)
  }

  @Test func removeAndMoveInTopQueue() {
    var q = queue(mode: [1])
    q.playLater([10, 11, 12, 13])
    q.removeFromTopQueue(at: [1])
    #expect(q.topQueue.map(\.trackID) == [10, 12, 13])
    q.moveInTopQueue(fromOffsets: [0], toOffset: 3)
    #expect(q.topQueue.map(\.trackID) == [12, 13, 10])
    q.moveInTopQueue(fromOffsets: [2], toOffset: 0)
    #expect(q.topQueue.map(\.trackID) == [10, 12, 13])
  }

  @Test func duplicateEntriesAreIndependent() {
    var q = queue(mode: [1])
    q.playLater([10, 10])
    #expect(q.topQueue[0].id != q.topQueue[1].id)
    q.removeFromTopQueue(at: [0])
    #expect(q.topQueue.map(\.trackID) == [10])
  }

  @Test func removeTracksNotInLibrary() {
    var q = queue(mode: [1, 2, 3, 4])
    q.advance()
    q.playLater([3, 9])
    q.removeTracks(notIn: [1, 3, 4, 9])
    // Current track 2 vanished, so the queue moved on.
    #expect(q.current == 3)
    #expect(q.upcomingTrackIDs == [9, 3, 4])
  }

  @Test func syncAdvancesToTrackEngineIsPlaying() {
    var q = queue(mode: [1, 2, 3, 4])
    q.playNext([10])
    let ok = q.sync(toPlaying: 2)
    #expect(ok)
    #expect(q.current == 2)
    #expect(q.history == [1, 10])
    #expect(q.upcomingTrackIDs == [3, 4])
  }

  @Test func syncBackOne() {
    var q = queue(mode: [1, 2, 3])
    q.advance()
    let ok = q.sync(toPlaying: 1)
    #expect(ok)
    #expect(q.current == 1)
  }

  @Test func syncUnknownTrackChangesNothing() {
    var q = queue(mode: [1, 2])
    let ok = q.sync(toPlaying: 99)
    #expect(!ok)
    #expect(q.current == 1)
  }

  @Test func syncToNilFinishes() {
    var q = queue(mode: [1, 2])
    q.playLater([5])
    let ok = q.sync(toPlaying: nil)
    #expect(ok)
    #expect(q.current == nil)
    #expect(q.upcomingTrackIDs.isEmpty)
  }

  @Test func unshuffledModeEnds() {
    var q = queue(mode: [1, 2])
    q.advance()
    #expect(q.advance() == nil)
  }

  @Test func shuffleStartsOverInSameOrder() {
    var q = PlayQueue()
    q.play(mode: .allTracks, trackIDs: [3, 1, 2], shuffled: true)
    #expect(q.upcomingTrackIDs == [1, 2, 3])
    q.advance()
    q.advance()
    #expect(q.advance() == 3)
    #expect(q.advance() == 1)
    #expect(q.modePosition == 1)
    #expect(q.upcomingTrackIDs == [2, 3, 1])
  }

  @Test func syncToNilLeavesShuffle() {
    var q = PlayQueue()
    q.play(mode: .allTracks, trackIDs: [1, 2], shuffled: true)
    let ok = q.sync(toPlaying: nil)
    #expect(!ok)
    #expect(q.current == 1)
  }

  @Test func jumpCarriesOnFromThere() {
    var q = queue(mode: [1, 2, 3, 4, 5])
    q.playLater([9])
    q.jump(toModeIndex: 3)
    #expect(q.current == 4)
    #expect(q.modePosition == 3)
    #expect(q.history == [1])
    #expect(q.upcomingTrackIDs == [9, 5])
  }

  @Test func modePositionWhilePlayingFromTopQueue() {
    var q = queue(mode: [1, 2, 3])
    q.playNow([9])
    // 1 was played; 2 is next.
    #expect(q.modePosition == 1)
  }

  @Test func reshuffleKeepsCurrentFirst() {
    var q = PlayQueue()
    q.play(mode: .allTracks, trackIDs: [1, 2, 3, 4], shuffled: true)
    q.advance()
    q.reshuffle([4, 3, 2, 1])
    #expect(q.current == 2)
    #expect(q.modeTrackIDs == [2, 4, 3, 1])
    #expect(q.upcomingTrackIDs == [4, 3, 1, 2])
  }

  @Test func libraryShuffleIsSavedAndResumed() {
    var q = PlayQueue()
    q.play(mode: .allTracks, trackIDs: [5, 6, 7, 8], shuffled: true)
    q.advance()
    q.play(mode: .album(1), trackIDs: [1, 2])
    #expect(q.savedLibraryShuffle == .init(trackIDs: [5, 6, 7, 8], index: 1))
    q.play(mode: .artist(1), trackIDs: [3])
    let resumed = q.resumeLibraryShuffle()
    #expect(resumed)
    #expect(q.mode == .allTracks)
    #expect(q.isShuffled)
    #expect(q.current == 6)
    #expect(q.savedLibraryShuffle == nil)
    #expect(q.upcomingTrackIDs == [7, 8, 5, 6])
  }

  @Test func newLibraryShuffleReplacesSaved() {
    var q = PlayQueue()
    q.play(mode: .allTracks, trackIDs: [5, 6], shuffled: true)
    q.play(mode: .album(1), trackIDs: [1])
    q.play(mode: .allTracks, trackIDs: [6, 5], shuffled: true)
    q.play(mode: .album(1), trackIDs: [1])
    #expect(q.savedLibraryShuffle?.trackIDs == [6, 5])
  }

  @Test func removeTracksFromSavedShuffle() {
    var q = PlayQueue()
    q.play(mode: .allTracks, trackIDs: [5, 6, 7, 8], startIndex: 2, shuffled: true)
    q.play(mode: .album(1), trackIDs: [1])
    q.removeTracks(notIn: [1, 6, 7, 8])
    #expect(q.savedLibraryShuffle == .init(trackIDs: [6, 7, 8], index: 1))
  }

  @Test func updateLibraryShuffleUpcoming() {
    var q = PlayQueue()
    q.play(mode: .allTracks, trackIDs: [5, 6, 7], shuffled: true)
    q.updateLibraryShuffleUpcoming { [9] + $0 }
    #expect(q.modeTrackIDs == [5, 9, 6, 7])
    q.play(mode: .album(1), trackIDs: [1])
    q.updateLibraryShuffleUpcoming { $0 + [10] }
    #expect(q.savedLibraryShuffle?.trackIDs == [5, 9, 6, 7, 10])
    #expect(q.libraryShuffleTrackIDs == [5, 9, 6, 7, 10])
  }

  @Test func codableRoundTrip() throws {
    var q = queue(mode: [1, 2, 3])
    q.playLater([10])
    q.advance()
    let decoded = try JSONDecoder().decode(PlayQueue.self, from: JSONEncoder().encode(q))
    #expect(decoded == q)
  }

  @Test func loadsStateSavedBeforeShuffles() throws {
    let json = #"{"modeTrackIDs":[1,2],"modeIndex":1,"topQueue":[],"current":1,"currentSource":{"mode":{}},"history":[],"mode":{"album":{"_0":1}}}"#
    let q = try JSONDecoder().decode(PlayQueue.self, from: Data(json.utf8))
    #expect(q.current == 1)
    #expect(!q.isShuffled)
  }
}
