import Foundation

/// What's needed to resume where the user left off.
struct PlayerState: Codable, Equatable, Sendable {
  var queue = PlayQueue()
  var currentTime: TimeInterval = 0
  /// Tracks this app played, so a new shuffle doesn't repeat them before the
  /// library's own `lastPlayedDate` catches up.
  var recentlyPlayed: [Track.ID: Date] = [:]
}

struct StoredPlaylist: Codable, Equatable, Sendable {
  var id: UUID
  var name: String
  var trackIDs: [Track.ID]
}

/// Saves app state as JSON files in Application Support.
struct StateStore: Sendable {
  let directory: URL

  static let `default` = StateStore(
    directory: URL.applicationSupportDirectory.appending(path: "PlayIt", directoryHint: .isDirectory))

  func loadPlayerState() -> PlayerState? {
    load(PlayerState.self, from: "player.json")
  }

  func save(_ state: PlayerState) {
    save(state, to: "player.json")
  }

  func loadPlaylists() -> [StoredPlaylist] {
    load([StoredPlaylist].self, from: "playlists.json") ?? []
  }

  func save(_ playlists: [StoredPlaylist]) {
    save(playlists, to: "playlists.json")
  }

  func reset() {
    try? FileManager.default.removeItem(at: directory)
  }

  // MARK: - Private

  private func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
    guard let data = try? Data(contentsOf: directory.appending(path: name)) else { return nil }
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      print("StateStore: couldn't decode \(name): \(error)")
      return nil
    }
  }

  private func save<T: Encodable>(_ value: T, to name: String) {
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try JSONEncoder().encode(value).write(to: directory.appending(path: name), options: .atomic)
    } catch {
      print("StateStore: couldn't save \(name): \(error)")
    }
  }
}
