import SwiftUI

struct SearchView: View {
  @Environment(AppModel.self) private var model
  @Environment(Router.self) private var router
  @State private var results = SearchIndex.Results()

  /// Rows shown per section before "Show All".
  static let previewCount = 5

  var body: some View {
    @Bindable var router = router
    List {
      if !results.artists.isEmpty {
        Section("Artists") {
          ForEach(results.artists.prefix(Self.previewCount), id: \.self) { id in
            if let artist = model.artist(id) {
              NavigationLink(value: Route.artist(id)) { ArtistRow(artist: artist) }
                .mediaActions(.artist(id))
            }
          }
        }
      }
      if !results.albums.isEmpty {
        Section("Albums") {
          ForEach(results.albums.prefix(Self.previewCount * 2), id: \.self) { id in
            if let album = model.album(id) {
              NavigationLink(value: Route.album(id)) { AlbumRow(album: album) }
                .mediaActions(.album(id))
            }
          }
        }
      }
      if !results.tracks.isEmpty {
        Section("Songs") {
          ForEach(results.tracks, id: \.self) { id in
            if let track = model.track(id) {
              Button { model.play(.track(id)) } label: { TrackRow(track: track, detail: track.album) }
                .buttonStyle(.plain)
                .mediaActions(.track(id))
            }
          }
        }
      }
    }
    .listStyle(.plain)
    .navigationTitle("Search")
    .searchable(
      text: $router.searchText, isPresented: $router.isSearchPresented,
      prompt: "Songs, Albums, Artists")
    .autocorrectionDisabled()
    .textInputAutocapitalization(.never)
    .overlay {
      if router.searchText.isEmpty {
        ContentUnavailableView(
          "Search Your Library", systemImage: "magnifyingglass",
          description: Text("Find songs by title, artist or album."))
      } else if results.isEmpty {
        ContentUnavailableView.search(text: router.searchText)
      }
    }
    .task(id: router.searchText) {
      // Debounce typing.
      try? await Task.sleep(for: .milliseconds(150))
      guard !Task.isCancelled else { return }
      let index = model.snapshot.searchIndex
      let query = router.searchText
      results = await Task.detached(priority: .userInitiated) { index.search(query) }.value
    }
  }
}
