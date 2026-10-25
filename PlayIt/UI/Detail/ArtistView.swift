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
          ForEach(artist.albumIDs, id: \.self) { albumID in
            if let album = model.album(albumID) {
              NavigationLink(value: Route.album(albumID)) { AlbumRow(album: album) }
                .mediaActions(.album(albumID))
            }
          }
        }
        Section("Songs") {
          ForEach(model.snapshot.trackIDs(forArtist: id), id: \.self) { trackID in
            if let track = model.track(trackID) {
              Button { model.play(.artist(id), startingAt: trackID) } label: {
                TrackRow(track: track, detail: track.album)
              }
              .buttonStyle(.plain)
              .mediaActions(.track(trackID), playContext: .artist(id))
            }
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
