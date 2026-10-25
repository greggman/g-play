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
        .accessibilityHint("Plays every song, favoring ones you haven't heard recently")
      }

      switch sort {
      case .songs: SongSections(sections: model.snapshot.tracksByTitle)
      case .albums: AlbumSections(sections: model.snapshot.albumsByTitle)
      case .artists: ArtistSections(sections: model.snapshot.artistsByName)
      case .recentlyAdded: RecentlyAddedSection(trackIDs: model.snapshot.tracksByDateAdded)
      }
    }
    .listStyle(.plain)
    .showsSectionIndex()
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

private struct SongSections: View {
  let sections: [IndexedSection<Track.ID>]
  @Environment(AppModel.self) private var model

  var body: some View {
    ForEach(sections) { section in
      Section(section.letter) {
        ForEach(section.ids, id: \.self) { id in
          if let track = model.track(id) {
            Button { model.play(.track(id)) } label: { TrackRow(track: track) }
              .buttonStyle(.plain)
              .mediaActions(.track(id))
          }
        }
      }
      .sectionIndex(section.letter)
    }
  }
}

private struct AlbumSections: View {
  let sections: [IndexedSection<Album.ID>]
  @Environment(AppModel.self) private var model

  var body: some View {
    ForEach(sections) { section in
      Section(section.letter) {
        ForEach(section.ids, id: \.self) { id in
          if let album = model.album(id) {
            NavigationLink(value: Route.album(id)) { AlbumRow(album: album) }
              .mediaActions(.album(id))
          }
        }
      }
      .sectionIndex(section.letter)
    }
  }
}

private struct ArtistSections: View {
  let sections: [IndexedSection<Artist.ID>]
  @Environment(AppModel.self) private var model

  var body: some View {
    ForEach(sections) { section in
      Section(section.letter) {
        ForEach(section.ids, id: \.self) { id in
          if let artist = model.artist(id) {
            NavigationLink(value: Route.artist(id)) { ArtistRow(artist: artist) }
              .mediaActions(.artist(id))
          }
        }
      }
      .sectionIndex(section.letter)
    }
  }
}

private struct RecentlyAddedSection: View {
  let trackIDs: [Track.ID]
  @Environment(AppModel.self) private var model

  var body: some View {
    Section {
      ForEach(trackIDs, id: \.self) { id in
        if let track = model.track(id) {
          Button { model.play(.track(id)) } label: {
            TrackRow(track: track, detail: track.dateAdded.formatted(date: .abbreviated, time: .omitted))
          }
          .buttonStyle(.plain)
          .mediaActions(.track(id))
        }
      }
    }
  }
}
