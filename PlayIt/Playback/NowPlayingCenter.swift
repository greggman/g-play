import MediaPlayer
import UIKit

/// Lock screen / Control Center integration for engines that play in-process.
/// (The system music player publishes this itself.) Lives as long as the app.
@MainActor
final class NowPlayingCenter {
  struct Handlers {
    var play: () -> Void
    var pause: () -> Void
    var togglePlayPause: () -> Void
    var next: () -> Void
    var previous: () -> Void
    var seek: (TimeInterval) -> Void
  }

  private let commandCenter = MPRemoteCommandCenter.shared()
  private var targets: [(MPRemoteCommand, Any)] = []

  init(handlers: Handlers) {
    add(commandCenter.playCommand) { handlers.play() }
    add(commandCenter.pauseCommand) { handlers.pause() }
    add(commandCenter.togglePlayPauseCommand) { handlers.togglePlayPause() }
    add(commandCenter.nextTrackCommand) { handlers.next() }
    add(commandCenter.previousTrackCommand) { handlers.previous() }
    let seek = commandCenter.changePlaybackPositionCommand
    seek.isEnabled = true
    targets.append((seek, seek.addTarget { event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
      let time = event.positionTime
      MainActor.assumeIsolated { handlers.seek(time) }
      return .success
    }))
  }

  func update(track: Track?, artwork: UIImage?, elapsed: TimeInterval, isPlaying: Bool) {
    let center = MPNowPlayingInfoCenter.default()
    guard let track else {
      center.nowPlayingInfo = nil
      center.playbackState = .stopped
      return
    }
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: track.title,
      MPMediaItemPropertyArtist: track.artist,
      MPMediaItemPropertyAlbumTitle: track.album,
      MPMediaItemPropertyPlaybackDuration: track.duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
      MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
    ]
    if let artwork {
      // Called on a background queue, so must not inherit main-actor isolation.
      info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { @Sendable _ in artwork }
    }
    center.nowPlayingInfo = info
    center.playbackState = isPlaying ? .playing : .paused
  }

  private func add(_ command: MPRemoteCommand, _ action: @escaping @MainActor () -> Void) {
    command.isEnabled = true
    targets.append((command, command.addTarget { _ in
      MainActor.assumeIsolated { action() }
      return .success
    }))
  }
}
