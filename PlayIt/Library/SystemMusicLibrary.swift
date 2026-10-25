import MediaPlayer
import UIKit

/// The device's Music library via `MPMediaQuery`.
@MainActor
final class SystemMusicLibrary: MusicLibrary {
  /// `MPMediaItem`s by persistent ID, for artwork and for handing to the
  /// system player.
  private var items: [Track.ID: MPMediaItem] = [:]

  var authorization: LibraryAuthorization {
    Self.map(MPMediaLibrary.authorizationStatus())
  }

  func requestAuthorization() async -> LibraryAuthorization {
    let status = await withCheckedContinuation { continuation in
      MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
    }
    return Self.map(status)
  }

  func loadSnapshot() async -> LibrarySnapshot {
    let loaded = await Task.detached(priority: .userInitiated) { () -> Loaded in
      let mediaItems = MPMediaQuery.songs().items ?? []
      let tracks = Track.groupAlbums(mediaItems.map(Self.track))
      let playlists = (MPMediaQuery.playlists().collections as? [MPMediaPlaylist] ?? []).map {
        Playlist(id: .system($0.persistentID), name: $0.name ?? "", trackIDs: $0.items.map(\.persistentID))
      }
      let snapshot = LibrarySnapshot(tracks: tracks, systemPlaylists: playlists)
      return Loaded(snapshot: snapshot, items: mediaItems)
    }.value
    items = Dictionary(loaded.items.map { ($0.persistentID, $0) }, uniquingKeysWith: { a, _ in a })
    return loaded.snapshot
  }

  func mediaItem(for id: Track.ID) -> MPMediaItem? {
    items[id]
  }

  func artwork(for trackID: Track.ID, size: CGFloat) async -> UIImage? {
    guard let artwork = items[trackID]?.artwork else { return nil }
    let box = ArtworkBox(artwork: artwork)
    // Fetching and decoding artwork is slow; keep it off the main thread so
    // scrolling doesn't stall.
    return await Task.detached(priority: .userInitiated) {
      let size = CGSize(width: size, height: size)
      let image = box.artwork.image(at: size)
      return image?.preparingThumbnail(of: size) ?? image
    }.value
  }

  private struct ArtworkBox: @unchecked Sendable {
    let artwork: MPMediaItemArtwork
  }

  func changes() -> AsyncStream<Void> {
    AsyncStream { continuation in
      MPMediaLibrary.default().beginGeneratingLibraryChangeNotifications()
      let task = Task { @MainActor in
        for await _ in NotificationCenter.default.notifications(named: .MPMediaLibraryDidChange) {
          continuation.yield()
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  // MARK: - Private

  /// `MPMediaItem` isn't `Sendable`, but the items are only read.
  private struct Loaded: @unchecked Sendable {
    let snapshot: LibrarySnapshot
    let items: [MPMediaItem]
  }

  nonisolated private static func track(_ item: MPMediaItem) -> Track {
    Track.fromLibrary(
      id: item.persistentID,
      title: item.title,
      artist: item.artist,
      artistID: item.artistPersistentID,
      album: item.albumTitle,
      albumArtist: item.albumArtist,
      isCompilation: item.isCompilation,
      trackNumber: item.albumTrackNumber,
      discNumber: item.discNumber,
      duration: item.playbackDuration,
      dateAdded: item.dateAdded,
      lastPlayedDate: item.lastPlayedDate,
      playCount: item.playCount)
  }

  private static func map(_ status: MPMediaLibraryAuthorizationStatus) -> LibraryAuthorization {
    switch status {
    case .authorized: .authorized
    case .denied: .denied
    case .restricted: .restricted
    case .notDetermined: .notDetermined
    @unknown default: .denied
    }
  }
}
