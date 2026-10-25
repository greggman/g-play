import Observation
import os
import SwiftUI

/// Something a queue action can apply to: any search result or list row, or
/// a whole list that a song was picked from.
enum MediaRef: Hashable {
  case track(Track.ID)
  case album(Album.ID)
  case artist(Artist.ID)
  case playlist(PlaylistID)
  case songs
  case recentlyAdded
  case searchResults(String)
}

/// App-wide state: the library, playlists, player and navigation.
@MainActor
@Observable
final class AppModel {
  enum LoadState {
    case loading
    case loaded
    case needsAuthorization(LibraryAuthorization)
  }

  private(set) var loadState = LoadState.loading
  private(set) var snapshot = LibrarySnapshot.empty
  private(set) var appPlaylists: [Playlist] = []
  let player: PlayerController
  let router = Router()

  /// Set to ask the user for a name for a new playlist containing these tracks.
  var pendingNewPlaylist: [Track.ID]?

  @ObservationIgnored let library: MusicLibrary
  @ObservationIgnored private let store: StateStore?

  init(library: MusicLibrary, engine: PlaybackEngine, store: StateStore?) {
    self.library = library
    self.store = store
    player = PlayerController(engine: engine, store: store) { [weak library] id, size in
      await library?.artwork(for: id, size: size)
    }
    appPlaylists = (store?.loadPlaylists() ?? []).map {
      Playlist(id: .app($0.id), name: $0.name, trackIDs: $0.trackIDs)
    }
  }

  /// Builds the app for the current environment: the real library and system
  /// player on a device, a generated library and `AVPlayer` on the Simulator.
  static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppModel {
    let store = StateStore.default
    if arguments.contains("-resetState") {
      store.reset()
      if let domain = Bundle.main.bundleIdentifier {
        UserDefaults.standard.removePersistentDomain(forName: domain)
      }
    }
    #if targetEnvironment(simulator)
      let useFixture = !arguments.contains("-systemLibrary")
    #else
      let useFixture = arguments.contains("-fixtureLibrary")
    #endif
    if useFixture {
      let count = arguments.firstIndex(of: "-fixtureTrackCount")
        .flatMap { arguments.indices.contains($0 + 1) ? Int(arguments[$0 + 1]) : nil } ?? 400
      return AppModel(
        library: FixtureMusicLibrary(trackCount: count), engine: AVPlaybackEngine.simulator(), store: store)
    }
    let library = SystemMusicLibrary()
    return AppModel(library: library, engine: SystemPlaybackEngine(library: library), store: store)
  }

  // MARK: - Loading

  func start() async {
    var status = library.authorization
    if status == .notDetermined {
      status = await library.requestAuthorization()
    }
    guard status == .authorized else {
      loadState = .needsAuthorization(status)
      return
    }
    await reload()
    loadState = .loaded
    for await _ in library.changes() {
      await reload()
    }
  }

  private func reload() async {
    let start = ContinuousClock.now
    snapshot = await library.loadSnapshot()
    player.libraryDidLoad(snapshot)
    Self.log.info("Loaded \(self.snapshot.tracks.count) tracks in \(ContinuousClock.now - start)")
  }

  private static let log = Logger(subsystem: "com.greggman.playit", category: "library")

  // MARK: - Resolving

  func track(_ id: Track.ID) -> Track? { snapshot.tracks[id] }
  func album(_ id: Album.ID) -> Album? { snapshot.albums[id] }
  func artist(_ id: Artist.ID) -> Artist? { snapshot.artists[id] }

  func playlist(_ id: PlaylistID) -> Playlist? {
    switch id {
    case .system: snapshot.systemPlaylists.first { $0.id == id }
    case .app: appPlaylists.first { $0.id == id }
    }
  }

  func trackIDs(for ref: MediaRef) -> [Track.ID] {
    switch ref {
    case .track(let id): snapshot.tracks[id] == nil ? [] : [id]
    case .album(let id): snapshot.albums[id]?.trackIDs ?? []
    case .artist(let id): snapshot.trackIDs(forArtist: id)
    case .playlist(let id): (playlist(id)?.trackIDs ?? []).filter { snapshot.tracks[$0] != nil }
    case .songs: snapshot.tracksByTitle.map(\.id)
    case .recentlyAdded: snapshot.tracksByDateAdded.map(\.id)
    case .searchResults(let query): snapshot.searchIndex.search(query).tracks
    }
  }

  func mode(for ref: MediaRef) -> PlayMode {
    switch ref {
    case .track(let id): .track(id)
    case .album(let id): .album(id)
    case .artist(let id): .artist(id)
    case .playlist(let id): .playlist(id)
    case .songs: .songs
    case .recentlyAdded: .recentlyAdded
    case .searchResults(let query): .searchResults(query)
    }
  }

  /// A title for the current mode, e.g. for "Playing from …".
  func title(for mode: PlayMode) -> String {
    switch mode {
    case .allTracks: String(localized: "Shuffle All")
    case .album(let id): snapshot.albums[id]?.title ?? ""
    case .artist(let id): snapshot.artists[id]?.name ?? ""
    case .playlist(let id): playlist(id)?.name ?? ""
    case .track(let id): snapshot.tracks[id]?.title ?? ""
    case .songs: String(localized: "Songs")
    case .recentlyAdded: String(localized: "Recently Added")
    case .searchResults(let query): String(localized: "Search “\(query)”")
    }
  }

  // MARK: - Queue actions

  /// Makes `ref` the new mode, optionally starting at one of its tracks.
  func play(_ ref: MediaRef, startingAt trackID: Track.ID? = nil) {
    let ids = trackIDs(for: ref)
    guard !ids.isEmpty else { return }
    let start = trackID.flatMap { ids.firstIndex(of: $0) } ?? 0
    player.play(mode: mode(for: ref), trackIDs: ids, startIndex: start)
    router.showNowPlaying()
  }

  func playNow(_ ref: MediaRef) {
    player.playNow(trackIDs(for: ref))
    router.showNowPlaying()
  }

  func playNext(_ ref: MediaRef) { player.playNext(trackIDs(for: ref)) }
  func playLater(_ ref: MediaRef) { player.playLater(trackIDs(for: ref)) }
  func shuffleAll() {
    player.shuffleAll()
    router.showNowPlaying()
  }

  // MARK: - Playlists

  @discardableResult
  func createPlaylist(named name: String, trackIDs: [Track.ID] = []) -> PlaylistID {
    let id = PlaylistID.app(UUID())
    appPlaylists.append(Playlist(id: id, name: Self.cleanName(name), trackIDs: trackIDs))
    saveAppPlaylists()
    return id
  }

  func duplicate(_ id: PlaylistID) -> PlaylistID? {
    guard let source = playlist(id) else { return nil }
    return createPlaylist(named: source.name, trackIDs: source.trackIDs)
  }

  func rename(_ id: PlaylistID, to name: String) {
    editPlaylist(id) { $0.name = Self.cleanName(name) }
  }

  func delete(_ id: PlaylistID) {
    appPlaylists.removeAll { $0.id == id }
    saveAppPlaylists()
  }

  func add(_ trackIDs: [Track.ID], to id: PlaylistID) {
    editPlaylist(id) { $0.trackIDs.append(contentsOf: trackIDs) }
  }

  func removeTracks(at offsets: IndexSet, from id: PlaylistID) {
    editPlaylist(id) { playlist in
      for index in offsets.sorted(by: >) { playlist.trackIDs.remove(at: index) }
    }
  }

  func moveTracks(in id: PlaylistID, fromOffsets source: IndexSet, toOffset destination: Int) {
    editPlaylist(id) { $0.trackIDs.move(fromOffsets: source, toOffset: destination) }
  }

  private func editPlaylist(_ id: PlaylistID, _ change: (inout Playlist) -> Void) {
    guard let index = appPlaylists.firstIndex(where: { $0.id == id }) else { return }
    change(&appPlaylists[index])
    saveAppPlaylists()
  }

  private func saveAppPlaylists() {
    store?.save(appPlaylists.compactMap { playlist in
      guard case .app(let uuid) = playlist.id else { return nil }
      return StoredPlaylist(id: uuid, name: playlist.name, trackIDs: playlist.trackIDs)
    })
  }

  private static func cleanName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? String(localized: "Untitled Playlist") : trimmed
  }
}
