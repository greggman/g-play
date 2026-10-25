import AVFoundation

/// Plays tracks in-process with `AVPlayer`. On the Simulator every track plays
/// a bundled tone file cut to the track's duration, so background audio, the
/// lock screen, scrubbing and remote commands can all be exercised. On a
/// device it could play `MPMediaItem.assetURL` (local, non-DRM files only) if
/// the system engine is ever replaced.
@MainActor
final class AVPlaybackEngine: PlaybackEngine {
  weak var delegate: PlaybackEngineDelegate?
  let managesNowPlaying = false

  private let player = AVPlayer()
  private let url: (Track) -> URL?
  private var current: Track?
  private var upcoming: [Track] = []
  private var observers: [NSObjectProtocol] = []
  private var rateObservation: NSKeyValueObservation?
  /// Whether the user wants audio playing, as opposed to whether it is.
  /// An interruption pauses the player without changing this.
  private var wantsToPlay = false

  init(url: @escaping (Track) -> URL?) {
    self.url = url
    player.automaticallyWaitsToMinimizeStalling = false

    let center = NotificationCenter.default
    observers.append(center.addObserver(
      forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main
    ) { [weak self] note in
      let item = note.object as? AVPlayerItem
      MainActor.assumeIsolated {
        guard let self, item === self.player.currentItem else { return }
        self.trackEnded()
      }
    })
    observers.append(center.addObserver(
      forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
    ) { [weak self] note in
      let info = InterruptionInfo(note)
      MainActor.assumeIsolated { self?.handleInterruption(info) }
    })
    observers.append(center.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] note in
      let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
        .flatMap(AVAudioSession.RouteChangeReason.init)
      MainActor.assumeIsolated {
        // Headphones unplugged: pause, as every music app does.
        if reason == .oldDeviceUnavailable { self?.pause() }
      }
    })
    rateObservation = player.observe(\.timeControlStatus) { [weak self] _, _ in
      Task { @MainActor in
        guard let self else { return }
        self.delegate?.engineStateChanged(self)
      }
    }
  }

  /// Uses the bundled tone for every track.
  static func simulator() -> AVPlaybackEngine {
    let toneURL = Bundle.main.url(forResource: "sim-tone", withExtension: "m4a")
    return AVPlaybackEngine { _ in toneURL }
  }

  var isPlaying: Bool { player.timeControlStatus != .paused }

  var currentTime: TimeInterval {
    let seconds = player.currentTime().seconds
    return seconds.isFinite ? seconds : 0
  }

  var currentTrackID: Track.ID? { current?.id }

  func setQueue(current: Track, upcoming: [Track], startTime: TimeInterval, play: Bool) {
    self.upcoming = upcoming
    load(current, startTime: startTime)
    if play { self.play() } else { delegate?.engineStateChanged(self) }
  }

  func setUpcoming(_ upcoming: [Track]) {
    self.upcoming = upcoming
  }

  func stop() {
    wantsToPlay = false
    player.pause()
    player.replaceCurrentItem(with: nil)
    current = nil
    upcoming = []
  }

  func play() {
    guard current != nil else { return }
    wantsToPlay = true
    activateSession()
    player.play()
  }

  func pause() {
    wantsToPlay = false
    player.pause()
  }

  func seek(to time: TimeInterval) {
    player.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
  }

  // MARK: - Private

  private func load(_ track: Track, startTime: TimeInterval) {
    current = track
    guard let url = url(track) else {
      player.replaceCurrentItem(with: nil)
      return
    }
    let item = AVPlayerItem(url: url)
    item.forwardPlaybackEndTime = CMTime(seconds: track.duration, preferredTimescale: 600)
    player.replaceCurrentItem(with: item)
    if startTime > 0 { seek(to: startTime) }
  }

  private func trackEnded() {
    guard !upcoming.isEmpty else {
      stop()
      delegate?.engine(self, didMoveTo: nil)
      return
    }
    load(upcoming.removeFirst(), startTime: 0)
    player.play()
    delegate?.engine(self, didMoveTo: current?.id)
  }

  private func activateSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default)
      try session.setActive(true)
    } catch {
      print("AVPlaybackEngine: audio session error: \(error)")
    }
  }

  private struct InterruptionInfo: Sendable {
    let began: Bool
    let shouldResume: Bool

    init(_ note: Notification) {
      let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
        .flatMap(AVAudioSession.InterruptionType.init)
      let options = AVAudioSession.InterruptionOptions(
        rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
      began = type == .began
      shouldResume = options.contains(.shouldResume)
    }
  }

  private func handleInterruption(_ info: InterruptionInfo) {
    if !info.began && info.shouldResume && wantsToPlay {
      play()
    }
  }
}
