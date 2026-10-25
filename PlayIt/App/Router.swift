import Observation
import SwiftUI

enum AppTab: Hashable {
  case library
  case playlists
  case search
}

enum Route: Hashable {
  case album(Album.ID)
  case artist(Artist.ID)
  case playlist(PlaylistID)
  case nowPlaying
}

/// Navigation state for the whole app, so any screen can send the user
/// somewhere.
@MainActor
@Observable
final class Router {
  var selectedTab = AppTab.library
  var libraryPath: [Route] = []
  var playlistsPath: [Route] = []
  var searchPath: [Route] = []
  var searchText = ""
  var isSearchPresented = false

  /// Whether the current tab is showing Now Playing.
  var isShowingNowPlaying: Bool {
    currentPath.last == .nowPlaying
  }

  /// Pushes the full-screen Now Playing view, unless it's already showing.
  func showNowPlaying() {
    if !isShowingNowPlaying { show(.nowPlaying) }
  }

  /// Tapping an artist's name goes to that artist's search results.
  func showSearch(forArtist name: String) {
    selectedTab = .search
    searchPath = []
    searchText = name
    isSearchPresented = true
  }

  /// Pushes `route` onto the current tab.
  func show(_ route: Route) {
    currentPath.append(route)
  }

  private var currentPath: [Route] {
    get {
      switch selectedTab {
      case .library: libraryPath
      case .playlists: playlistsPath
      case .search: searchPath
      }
    }
    set {
      switch selectedTab {
      case .library: libraryPath = newValue
      case .playlists: playlistsPath = newValue
      case .search: searchPath = newValue
      }
    }
  }
}
