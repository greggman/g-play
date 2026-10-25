import Observation
import UIKit

/// Owns the `PlayQueue` and drives a `PlaybackEngine` from it.
@MainActor
@Observable
final class PlayerController {
  private(set) var queue = PlayQueue()
  private(set) var isPlaying = false
  /// Playback position, refreshed periodically while a track is loaded.
  private(set) var elapsed: TimeInterval = 0
  private(set) var recentlyPlayed: [Track.ID: Date] = [:]

  /// Restart the current track instead of going back if past this point.
  static let restartThreshold: TimeInterval = 3

  @ObservationIgnored private let engine: PlaybackEngine
  @ObservationIgnored private let artwork: (Track.ID, CGFloat) async -> UIImage?
  @ObservationIgnored private let store: StateStore?
  @ObservationIgnored private var nowPlayingCenter: NowPlayingCenter?
  @ObservationIgnored private var timer: Timer?
  @ObservationIgnored private var nowPlayingArtwork: (id: Track.ID, image: UIImage?)?
  @ObservationIgnored private(set) var snapshot = LibrarySnapshot.empty

  init(
    engine: PlaybackEngine,
    store: StateStore?,
    artwork: @escaping (Track.ID, CGFloat) async -> UIImage? = { _, _ in nil }
  ) {
    self.engine = engine
    self.store = store
    self.artwork = artwork
    engine.delegate = self
    if !engine.managesNowPlaying {
      nowPlayingCenter = NowPlayingCenter(handlers: .init(
        play: { [weak self] in self?.play() },
        pause: { [weak self] in self?.pause() },
        togglePlayPause: { [weak self] in self?.togglePlayPause() },
        next: { [weak self] in self?.next() },
        previous: { [weak self] in self?.previous() },
        seek: { [weak self] in self?.seek(to: $0) }))
    }
    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
  }

  var currentTrack: Track? {
    queue.current.flatMap { snapshot.tracks[$0] }
  }

  var duration: TimeInterval { currentTrack?.duration ?? 0 }

  var topQueueTracks: [(entry: QueueEntry, track: Track)] {
    queue.topQueue.compactMap { entry in snapshot.tracks[entry.trackID].map { (entry, $0) } }
  }

  func upcomingModeTracks(limit: Int) -> [Track] {
    snapshot.tracks(queue.upcomingModeTrackIDs.prefix(limit))
  }

  // MARK: - Library

  /// Called whenever the library is (re)loaded. The first call restores the
  /// saved state.
  func libraryDidLoad(_ snapshot: LibrarySnapshot) {
    let isFirstLoad = self.snapshot.isEmpty
    self.snapshot = snapshot
    let before = queue.current
    if isFirstLoad, let saved = store?.loadPlayerState() {
      queue = saved.queue
      recentlyPlayed = saved.recentlyPlayed
      queue.removeTracks(notIn: Set(snapshot.tracks.keys))
      if engine.isPlaying, queue.sync(toPlaying: engine.currentTrackID) {
        // The system player kept playing while the app wasn't running.
        engine.setUpcoming(upcomingTracks())
      } else {
        reloadEngine(play: false, startTime: queue.current == saved.queue.current ? saved.currentTime : 0)
      }
    } else {
      queue.removeTracks(notIn: Set(snapshot.tracks.keys))
      if queue.current != before { reloadEngine(play: isPlaying) } else { engine.setUpcoming(upcomingTracks()) }
    }
    stateChanged()
  }

  // MARK: - Queue actions

  /// Starts a new mode. Clears the top queue.
  func play(mode: PlayMode, trackIDs: [Track.ID], startIndex: Int = 0) {
    queue.play(mode: mode, trackIDs: trackIDs, startIndex: startIndex)
    reloadEngine(play: true)
    stateChanged()
  }

  func playNow(_ trackIDs: [Track.ID]) {
    mutate(play: true) { $0.playNow(trackIDs) }
  }

  func playNext(_ trackIDs: [Track.ID]) {
    mutate { $0.playNext(trackIDs) }
  }

  func playLater(_ trackIDs: [Track.ID]) {
    mutate { $0.playLater(trackIDs) }
  }

  func removeFromTopQueue(at offsets: IndexSet) {
    mutate { $0.removeFromTopQueue(at: offsets) }
  }

  func moveInTopQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
    mutate { $0.moveInTopQueue(fromOffsets: source, toOffset: destination) }
  }

  func clearTopQueue() {
    mutate { $0.clearTopQueue() }
  }

  /// Weighted shuffle of the whole library.
  func shuffleAll() {
    let order = WeightedShuffle.order(Array(snapshot.tracks.values), recentlyPlayed: recentlyPlayed)
    play(mode: .allTracks, trackIDs: order)
  }

  // MARK: - Transport

  func play() {
    if queue.current == nil {
      return
    }
    if engine.currentTrackID == nil {
      reloadEngine(play: true, startTime: elapsed)
    } else {
      engine.play()
    }
    refreshPlaybackState()
  }

  func pause() {
    engine.pause()
    refreshPlaybackState()
    save()
  }

  func togglePlayPause() {
    if isPlaying { pause() } else { play() }
  }

  func next() {
    mutate(play: isPlaying) { $0.advance() }
  }

  func previous() {
    if engine.currentTime > Self.restartThreshold || queue.history.isEmpty {
      seek(to: 0)
      return
    }
    mutate(play: isPlaying) { $0.goBack() }
  }

  func seek(to time: TimeInterval) {
    engine.seek(to: time)
    elapsed = time
    updateNowPlaying()
  }

  /// Catch up with an engine that kept playing while the app was suspended.
  func syncWithEngine() {
    guard engine.currentTrackID != queue.current else {
      refreshPlaybackState()
      return
    }
    if queue.sync(toPlaying: engine.currentTrackID) {
      engine.setUpcoming(upcomingTracks())
      stateChanged()
    }
  }

  func save() {
    let cutoff = Date.now.addingTimeInterval(-WeightedShuffle.maxDays * 86_400)
    recentlyPlayed = recentlyPlayed.filter { $0.value > cutoff }
    store?.save(PlayerState(queue: queue, currentTime: elapsed, recentlyPlayed: recentlyPlayed))
  }

  // MARK: - Private

  /// Applies a queue change and updates the engine: reloads it if the
  /// current track changed, otherwise just replaces what's upcoming.
  private func mutate(play: Bool = false, _ change: (inout PlayQueue) -> Void) {
    let before = queue.current
    let wasIdle = engine.currentTrackID == nil
    change(&queue)
    if queue.current != before {
      reloadEngine(play: play || wasIdle)
    } else {
      engine.setUpcoming(upcomingTracks())
    }
    stateChanged()
  }

  private func upcomingTracks() -> [Track] {
    snapshot.tracks(queue.upcomingTrackIDs.prefix(SystemPlaybackEngine.windowSize))
  }

  private func reloadEngine(play: Bool, startTime: TimeInterval = 0) {
    elapsed = startTime
    guard let track = currentTrack else {
      engine.stop()
      refreshPlaybackState()
      return
    }
    engine.setQueue(current: track, upcoming: upcomingTracks(), startTime: startTime, play: play)
    if play { markPlayed(track.id) }
    refreshPlaybackState()
  }

  private func markPlayed(_ id: Track.ID) {
    recentlyPlayed[id] = .now
  }

  private func stateChanged() {
    updateNowPlaying()
    save()
  }

  private func refreshPlaybackState() {
    isPlaying = engine.isPlaying
    if engine.currentTrackID != nil { elapsed = engine.currentTime }
    updateNowPlaying()
  }

  private func tick() {
    guard engine.currentTrackID != nil else { return }
    let time = engine.currentTime
    if abs(time - elapsed) > 0.05 { elapsed = time }
    if engine.isPlaying != isPlaying { refreshPlaybackState() }
  }

  private func updateNowPlaying() {
    guard let nowPlayingCenter else { return }
    let track = currentTrack
    if let track, nowPlayingArtwork?.id != track.id {
      nowPlayingArtwork = (track.id, nil)
      Task {
        let image = await artwork(track.id, 600)
        guard nowPlayingArtwork?.id == track.id else { return }
        nowPlayingArtwork = (track.id, image)
        updateNowPlaying()
      }
    }
    nowPlayingCenter.update(track: track, artwork: nowPlayingArtwork?.image, elapsed: elapsed, isPlaying: isPlaying)
  }
}

extension PlayerController: PlaybackEngineDelegate {
  func engine(_ engine: PlaybackEngine, didMoveTo trackID: Track.ID?) {
    guard trackID != queue.current else { return }
    if queue.sync(toPlaying: trackID) {
      if let trackID { markPlayed(trackID) }
      elapsed = 0
      stateChanged()
    }
  }

  func engineStateChanged(_ engine: PlaybackEngine) {
    refreshPlaybackState()
  }
}
