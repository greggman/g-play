import SwiftUI

struct RootView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    switch model.loadState {
    case .loading:
      ProgressView("Loading Library…")
    case .needsAuthorization(let status):
      AuthorizationView(status: status)
    case .loaded:
      MainTabView()
    }
  }
}

private struct MainTabView: View {
  @Environment(AppModel.self) private var model
  @Environment(Router.self) private var router

  var body: some View {
    @Bindable var router = router
    @Bindable var model = model
    TabView(selection: $router.selectedTab) {
      Tab("Library", systemImage: "music.note.list", value: AppTab.library) {
        NavigationStack(path: $router.libraryPath) {
          LibraryView().routeDestinations()
        }
        .miniPlayerInset()
      }
      Tab("Playlists", systemImage: "music.note.square.stack", value: AppTab.playlists) {
        NavigationStack(path: $router.playlistsPath) {
          PlaylistsView().routeDestinations()
        }
        .miniPlayerInset()
      }
      Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
        NavigationStack(path: $router.searchPath) {
          SearchView().routeDestinations()
        }
        .miniPlayerInset()
      }
    }
    .miniPlayerAccessory()
    .sheet(isPresented: $router.isNowPlayingPresented) {
      NowPlayingView()
    }
    .newPlaylistAlert(trackIDs: $model.pendingNewPlaylist)
  }
}

extension View {
  func routeDestinations() -> some View {
    navigationDestination(for: Route.self) { route in
      switch route {
      case .album(let id): AlbumView(id: id)
      case .artist(let id): ArtistView(id: id)
      case .playlist(let id): PlaylistView(id: id)
      }
    }
  }

  /// Asks for a name and creates a Play-It playlist with `trackIDs`.
  func newPlaylistAlert(trackIDs: Binding<[Track.ID]?>) -> some View {
    modifier(NewPlaylistAlert(trackIDs: trackIDs))
  }
}

private struct NewPlaylistAlert: ViewModifier {
  @Binding var trackIDs: [Track.ID]?
  @State private var name = ""
  @Environment(AppModel.self) private var model

  func body(content: Content) -> some View {
    content.alert(
      "New Playlist",
      isPresented: Binding(get: { trackIDs != nil }, set: { if !$0 { trackIDs = nil } })
    ) {
      TextField("Name", text: $name)
      Button("Cancel", role: .cancel) { name = "" }
      Button("Create") {
        model.createPlaylist(named: name, trackIDs: trackIDs ?? [])
        name = ""
      }
    }
  }
}
