import SwiftUI

struct PlaylistsView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    List {
      Section {
        Button("New Playlist", systemImage: "plus") { model.pendingNewPlaylist = [] }
        ForEach(model.appPlaylists) { playlist in
          NavigationLink(value: Route.playlist(playlist.id)) { PlaylistRow(playlist: playlist) }
            .mediaActions(.playlist(playlist.id))
        }
        .onDelete { offsets in
          for index in offsets { model.delete(model.appPlaylists[index].id) }
        }
      } header: {
        Text("g-play Playlists")
      }
      if !model.snapshot.systemPlaylists.isEmpty {
        Section {
          ForEach(model.snapshot.systemPlaylists) { playlist in
            NavigationLink(value: Route.playlist(playlist.id)) { PlaylistRow(playlist: playlist) }
              .mediaActions(.playlist(playlist.id))
          }
        } header: {
          Text("Music Playlists")
        } footer: {
          Text("Playlists from the Music app can't be edited here. Duplicate one to make an editable copy.")
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Playlists")
  }
}

struct PlaylistView: View {
  let id: PlaylistID
  @Environment(AppModel.self) private var model
  @Environment(Router.self) private var router
  @Environment(\.dismiss) private var dismiss
  @State private var isRenaming = false
  @State private var newName = ""
  @State private var isConfirmingDelete = false

  var body: some View {
    if let playlist = model.playlist(id) {
      List {
        Section {
          PlayButtons(ref: .playlist(id))
            .listRowSeparator(.hidden)
        }
        Section {
          ForEach(Array(playlist.trackIDs.enumerated()), id: \.offset) { index, trackID in
            if let track = model.track(trackID) {
              Button { play(playlist, at: index) } label: { TrackRow(track: track, detail: track.album) }
                .buttonStyle(.plain)
                .mediaActions(.track(trackID), playContext: .playlist(id))
            }
          }
          .onMove(perform: playlist.isEditable ? { model.moveTracks(in: id, fromOffsets: $0, toOffset: $1) } : nil)
          .onDelete(perform: playlist.isEditable ? { model.removeTracks(at: $0, from: id) } : nil)
        } footer: {
          if playlist.trackIDs.isEmpty {
            Text("Add songs with “Add to Playlist” from any song, album or artist's menu.")
          }
        }
      }
      .listStyle(.plain)
      .navigationTitle(playlist.name)
      .toolbar {
        if playlist.isEditable {
          ToolbarItem { EditButton() }
        }
        ToolbarItem {
          Menu("More", systemImage: "ellipsis") {
            if playlist.isEditable {
              Button("Rename", systemImage: "pencil") {
                newName = playlist.name
                isRenaming = true
              }
              Button("Delete Playlist", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
            } else {
              Button("Duplicate as g-play Playlist", systemImage: "plus.square.on.square") {
                if let copy = model.duplicate(id) { router.show(.playlist(copy)) }
              }
            }
            MediaMenu(ref: .playlist(id))
          }
        }
      }
      .alert("Rename Playlist", isPresented: $isRenaming) {
        TextField("Name", text: $newName)
        Button("Cancel", role: .cancel) {}
        Button("Rename") { model.rename(id, to: newName) }
      }
      .confirmationDialog("Delete “\(playlist.name)”?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
        Button("Delete Playlist", role: .destructive) {
          dismiss()
          model.delete(id)
        }
      }
    } else {
      ContentUnavailableView("Playlist Not Found", systemImage: "music.note.list")
    }
  }

  /// Plays the playlist from a row. Duplicate tracks are allowed in a
  /// playlist, so start by position rather than track ID.
  private func play(_ playlist: Playlist, at index: Int) {
    let ids = model.trackIDs(for: .playlist(id))
    let valid = playlist.trackIDs.prefix(index).filter { model.track($0) != nil }.count
    model.player.play(mode: .playlist(id), trackIDs: ids, startIndex: valid)
    router.showNowPlaying()
  }
}
