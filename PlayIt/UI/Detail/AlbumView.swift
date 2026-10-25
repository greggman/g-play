import SwiftUI

struct AlbumView: View {
  let id: Album.ID
  @Environment(AppModel.self) private var model

  var body: some View {
    if let album = model.album(id) {
      List {
        Section {
          VStack(spacing: 12) {
            LargeArtworkView(trackID: album.artworkTrackID)
              .frame(maxWidth: 280)
            Text(album.title)
              .font(.title2.bold())
              .multilineTextAlignment(.center)
              .contextMenu { CopyMenuItems(album: album.title) }
            ArtistLink(name: album.artist)
              .font(.title3)
              .contextMenu { CopyMenuItems(artist: album.artist) }
            PlayButtons(ref: .album(id))
          }
          .frame(maxWidth: .infinity)
          .listRowSeparator(.hidden)
        }

        Section {
          ForEach(Array(model.snapshot.tracks(album.trackIDs).enumerated()), id: \.element.id) { index, track in
            Button { model.play(.album(id), startingAt: track.id) } label: {
              TrackRow(track: track, number: track.trackNumber > 0 ? track.trackNumber : index + 1)
            }
            .buttonStyle(.plain)
            .mediaActions(.track(track.id), playContext: .album(id))
          }
        } footer: {
          Text(summary(album))
        }
      }
      .listStyle(.plain)
      .navigationTitle(album.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem { Menu("More", systemImage: "ellipsis") { MediaMenu(ref: .album(id)) } } }
    } else {
      ContentUnavailableView("Album Not Found", systemImage: "square.stack")
    }
  }

  private func summary(_ album: Album) -> String {
    let seconds = model.snapshot.tracks(album.trackIDs).reduce(0) { $0 + $1.duration }
    let duration = Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    return [String(localized: "\(album.trackIDs.count) songs"), duration].formatted(.list(type: .and, width: .narrow))
  }
}

/// Play / Play Next / Play Later buttons for a detail header.
struct PlayButtons: View {
  let ref: MediaRef
  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    // Stack the buttons when text is too large to fit them side by side.
    let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout())
    layout {
      Button { model.play(ref) } label: {
        Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      Menu {
        QueueActionItems(ref: ref)
      } label: {
        Label("Queue", systemImage: "text.line.first.and.arrowtriangle.forward").frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
    .controlSize(.large)
    .frame(maxWidth: 500)
    .frame(maxWidth: .infinity)
  }
}
