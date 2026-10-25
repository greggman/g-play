import MediaPlayer

/// Plays through `MPMusicPlayerController.applicationQueuePlayer`, which can
/// play Apple Music and iCloud tracks that `AVPlayer` can't. Playback runs in
/// a system process, so it continues and shows on the lock screen while this
/// app is suspended.
///
/// Because the app may be suspended, the system player is given a long
/// window of upcoming tracks, and `PlayQueue` catches up from
/// `didMoveTo` / `currentTrackID` when the app runs again.
@MainActor
final class SystemPlaybackEngine: PlaybackEngine {
  weak var delegate: PlaybackEngineDelegate?
  let managesNowPlaying = true

  /// Upcoming tracks handed to the system player at once.
  static let windowSize = 500

  private let player = MPMusicPlayerController.applicationQueuePlayer
  private let library: SystemMusicLibrary
  private var observers: [NSObjectProtocol] = []

  init(library: SystemMusicLibrary) {
    self.library = library
    player.beginGeneratingPlaybackNotifications()
    let center = NotificationCenter.default
    observers.append(center.addObserver(
      forName: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.delegate?.engine(self, didMoveTo: self.currentTrackID)
      }
    })
    observers.append(center.addObserver(
      forName: .MPMusicPlayerControllerPlaybackStateDidChange, object: player, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.delegate?.engineStateChanged(self)
      }
    })
  }

  var isPlaying: Bool { player.playbackState == .playing }
  var currentTime: TimeInterval { player.currentPlaybackTime }
  var currentTrackID: Track.ID? { player.nowPlayingItem?.persistentID }

  func setQueue(current: Track, upcoming: [Track], startTime: TimeInterval, play: Bool) {
    let items = ([current] + upcoming.prefix(Self.windowSize)).compactMap { library.mediaItem(for: $0.id) }
    guard let first = items.first else {
      stop()
      return
    }
    player.setQueue(with: MPMediaItemCollection(items: items))
    player.nowPlayingItem = first
    player.prepareToPlay()
    if startTime > 0 { player.currentPlaybackTime = startTime }
    if play { player.play() }
  }

  func setUpcoming(_ upcoming: [Track]) {
    guard let nowPlayingID = currentTrackID else { return }
    let items = upcoming.prefix(Self.windowSize).compactMap { library.mediaItem(for: $0.id) }
    player.perform(queueTransaction: { queue in
      guard let nowPlaying = queue.items.firstIndex(where: { $0.persistentID == nowPlayingID }) else { return }
      for item in queue.items[(nowPlaying + 1)...] {
        queue.remove(item)
      }
      if !items.isEmpty {
        queue.insert(
          MPMusicPlayerMediaItemQueueDescriptor(itemCollection: MPMediaItemCollection(items: items)),
          after: queue.items[nowPlaying])
      }
    }, completionHandler: { _, error in
      if let error { print("SystemPlaybackEngine: queue update failed: \(error)") }
    })
  }

  func stop() {
    player.stop()
  }

  func play() { player.play() }
  func pause() { player.pause() }

  func seek(to time: TimeInterval) {
    player.currentPlaybackTime = time
  }
}
