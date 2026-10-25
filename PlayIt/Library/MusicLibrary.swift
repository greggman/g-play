import UIKit

enum LibraryAuthorization: Sendable {
  case notDetermined
  case authorized
  case denied
  case restricted
}

/// Source of tracks and artwork. `SystemMusicLibrary` reads the device's
/// Music library; `FixtureMusicLibrary` generates one for the Simulator, which
/// has no music library.
@MainActor
protocol MusicLibrary: AnyObject {
  var authorization: LibraryAuthorization { get }
  func requestAuthorization() async -> LibraryAuthorization

  /// Reads the whole library and indexes it. Heavy work happens off the
  /// main actor.
  func loadSnapshot() async -> LibrarySnapshot

  /// Artwork for a track, roughly `size` points square.
  func artwork(for trackID: Track.ID, size: CGFloat) async -> UIImage?

  /// Yields whenever the underlying library changes.
  func changes() -> AsyncStream<Void>
}
