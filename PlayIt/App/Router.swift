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
}

/// Navigation state for the whole app, so any screen (including the Now
/// Playing sheet) can send the user somewhere.
@MainActor
@Observable
final class Router {
  var selectedTab = AppTab.library
  var libraryPath: [Route] = []
  var playlistsPath: [Route] = []
  var searchPath: [Route] = []
  var searchText = ""
  var isSearchPresented = false
  var isNowPlayingPresented = false

  /// Tapping an artist's name goes to that artist's search results.
  func showSearch(forArtist name: String) {
    isNowPlayingPresented = false
    selectedTab = .search
    searchPath = []
    searchText = name
    isSearchPresented = true
  }

  /// Pushes `route` onto the current tab.
  func show(_ route: Route) {
    isNowPlayingPresented = false
    switch selectedTab {
    case .library: libraryPath.append(route)
    case .playlists: playlistsPath.append(route)
    case .search: searchPath.append(route)
    }
  }
}
