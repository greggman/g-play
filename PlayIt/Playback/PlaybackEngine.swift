import Foundation

@MainActor
protocol PlaybackEngineDelegate: AnyObject {
  /// The engine moved to another track by itself (track ended, or a remote
  /// command it handles). `nil` means it ran out of tracks.
  func engine(_ engine: PlaybackEngine, didMoveTo trackID: Track.ID?)
  /// Play/pause state changed.
  func engineStateChanged(_ engine: PlaybackEngine)
}

/// Plays a current track followed by an upcoming list. `PlayQueue` is the
/// source of truth; the engine is handed a window of it and reports when it
/// moves on so the queue can catch up.
@MainActor
protocol PlaybackEngine: AnyObject {
  var delegate: PlaybackEngineDelegate? { get set }

  /// True when the system publishes Now Playing info and handles remote
  /// commands itself (the system music player). Otherwise the app must.
  var managesNowPlaying: Bool { get }

  var isPlaying: Bool { get }
  var currentTime: TimeInterval { get }
  /// The track the engine is playing, if any.
  var currentTrackID: Track.ID? { get }

  /// Replace everything: start `current` at `startTime`, followed by `upcoming`.
  func setQueue(current: Track, upcoming: [Track], startTime: TimeInterval, play: Bool)
  /// Replace what follows the current track, leaving it playing.
  func setUpcoming(_ upcoming: [Track])
  func stop()

  func play()
  func pause()
  func seek(to time: TimeInterval)
}

extension PlaybackEngine {
  func togglePlayPause() {
    if isPlaying { pause() } else { play() }
  }
}
