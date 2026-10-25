import SwiftUI

struct ArtistView: View {
  let id: Artist.ID
  @Environment(AppModel.self) private var model

  var body: some View {
    if let artist = model.artist(id) {
      List {
        Section {
          PlayButtons(ref: .artist(id))
            .listRowSeparator(.hidden)
        }
        Section("Albums") {
          ForEach(artist.albumIDs.compactMap(model.album)) { album in
            NavigationLink(value: Route.album(album.id)) { AlbumRow(album: album) }
              .mediaActions(.album(album.id))
          }
        }
        Section("Songs") {
          ForEach(model.snapshot.tracks(forArtist: id)) { track in
            Button { model.play(.artist(id), startingAt: track.id) } label: {
              TrackRow(track: track, detail: track.album)
            }
            .buttonStyle(.plain)
            .mediaActions(.track(track.id), playContext: .artist(id))
          }
        }
      }
      .listStyle(.plain)
      .navigationTitle(artist.name)
      .toolbar {
        ToolbarItem {
          Menu("More", systemImage: "ellipsis") { MediaMenu(ref: .artist(id)) }
        }
      }
    } else {
      ContentUnavailableView("Artist Not Found", systemImage: "music.mic")
    }
  }
}
