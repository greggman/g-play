import SwiftUI

enum LibrarySort: String, CaseIterable, Identifiable {
  case songs
  case albums
  case artists
  case recentlyAdded

  var id: Self { self }

  var title: LocalizedStringKey {
    switch self {
    case .songs: "Songs"
    case .albums: "Albums"
    case .artists: "Artists"
    case .recentlyAdded: "Added"
    }
  }
}

struct LibraryView: View {
  @Environment(AppModel.self) private var model
  @AppStorage("librarySort") private var sort = LibrarySort.songs

  var body: some View {
    List {
      Section {
        Picker("Sort", selection: $sort) {
          ForEach(LibrarySort.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

        Button {
          model.shuffleAll()
        } label: {
          Label("Shuffle All", systemImage: "shuffle")
            .font(.headline)
        }
        .accessibilityHint("Plays every song in a shuffled order, favoring ones you haven't heard recently. Picks up where it left off.")
        .contextMenu {
          Button("Reshuffle All", systemImage: "shuffle") { model.reshuffleAll() }
        }
      }

      switch sort {
      case .songs: SongList(tracks: model.snapshot.tracksByTitle)
      case .albums: AlbumList(albums: model.snapshot.albumsByTitle)
      case .artists: ArtistList(artists: model.snapshot.artistsByName)
      case .recentlyAdded: RecentlyAddedSection(tracks: model.snapshot.tracksByDateAdded)
      }
    }
    .listStyle(.plain)
    .navigationTitle("Library")
    .overlay {
      if model.snapshot.isEmpty {
        ContentUnavailableView(
          "No Music", systemImage: "music.note",
          description: Text("Songs you add to the Music app appear here."))
      }
    }
  }
}

private struct SongList: View {
  let tracks: [Track]
  @Environment(AppModel.self) private var model

  var body: some View {
    Section {
      ForEach(tracks) { track in
        Button { model.play(.songs, startingAt: track.id) } label: { TrackRow(track: track) }
          .buttonStyle(.plain)
          .mediaActions(.track(track.id), playContext: .songs)
      }
    }
  }
}

private struct AlbumList: View {
  let albums: [Album]

  var body: some View {
    Section {
      ForEach(albums) { album in
        NavigationLink(value: Route.album(album.id)) { AlbumRow(album: album) }
          .mediaActions(.album(album.id))
      }
    }
  }
}

private struct ArtistList: View {
  let artists: [Artist]

  var body: some View {
    Section {
      ForEach(artists) { artist in
        NavigationLink(value: Route.artist(artist.id)) { ArtistRow(artist: artist) }
          .mediaActions(.artist(artist.id))
      }
    }
  }
}

private struct RecentlyAddedSection: View {
  let tracks: [Track]
  @Environment(AppModel.self) private var model

  var body: some View {
    Section {
      ForEach(tracks) { track in
        Button { model.play(.recentlyAdded, startingAt: track.id) } label: {
          TrackRow(track: track, detail: track.dateAdded.formatted(date: .abbreviated, time: .omitted))
        }
        .buttonStyle(.plain)
        .mediaActions(.track(track.id), playContext: .recentlyAdded)
      }
    }
  }
}
