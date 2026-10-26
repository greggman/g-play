import SwiftUI

enum Pasteboard {
  static func copy(_ text: String) {
    UIPasteboard.general.string = text
  }
}

/// Copy items for a long-press menu. DESIGN.md: "copy" is always offered.
struct CopyMenuItems: View {
  var trackTitle: String?
  var artist: String?
  var album: String?
  var playlist: String?

  var body: some View {
    Section {
      if let trackTitle {
        Button("Copy Track Name", systemImage: "doc.on.doc") { Pasteboard.copy(trackTitle) }
      }
      if let album {
        Button("Copy Album Name", systemImage: "doc.on.doc") { Pasteboard.copy(album) }
      }
      if let artist {
        Button("Copy Artist Name", systemImage: "doc.on.doc") { Pasteboard.copy(artist) }
      }
      if let playlist {
        Button("Copy Playlist Name", systemImage: "doc.on.doc") { Pasteboard.copy(playlist) }
      }
    }
  }
}

/// Play / Play Now / Play Next / Play Later.
struct QueueActionItems: View {
  let ref: MediaRef
  /// For a track inside an album or playlist: what "Play" makes the new mode.
  var playContext: MediaRef?
  @Environment(AppModel.self) private var model

  var body: some View {
    Section {
      Button("Play", systemImage: "play") {
        if let playContext, case .track(let id) = ref {
          model.play(playContext, startingAt: id)
        } else {
          model.play(ref)
        }
      }
      if case .track = ref {} else {
        Button("Shuffle", systemImage: "shuffle") { model.shuffle(ref) }
      }
      Button("Play Now", systemImage: "play.circle") { model.playNow(ref) }
      Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") { model.playNext(ref) }
      Button("Play Later", systemImage: "text.line.last.and.arrowtriangle.forward") { model.playLater(ref) }
    }
  }
}

/// "Add to Playlist" submenu listing Play-It playlists plus "New Playlist…".
struct AddToPlaylistMenu: View {
  let ref: MediaRef
  @Environment(AppModel.self) private var model

  var body: some View {
    Menu("Add to Playlist", systemImage: "text.badge.plus") {
      Button("New Playlist…", systemImage: "plus") {
        model.pendingNewPlaylist = model.trackIDs(for: ref)
      }
      ForEach(model.appPlaylists) { playlist in
        Button(playlist.name) { model.add(model.trackIDs(for: ref), to: playlist.id) }
      }
    }
  }
}

/// The full long-press menu for any result.
struct MediaMenu: View {
  let ref: MediaRef
  var playContext: MediaRef?
  @Environment(AppModel.self) private var model
  @Environment(Router.self) private var router

  var body: some View {
    QueueActionItems(ref: ref, playContext: playContext)
    Section {
      AddToPlaylistMenu(ref: ref)
      switch ref {
      case .track(let id):
        if let track = model.track(id) {
          Button("Go to Album", systemImage: "square.stack") { router.show(.album(track.albumID)) }
          Button("Search Artist", systemImage: "magnifyingglass") { router.showSearch(forArtist: track.artist) }
        }
      case .album(let id):
        if let album = model.album(id) {
          Button("Search Artist", systemImage: "magnifyingglass") { router.showSearch(forArtist: album.artist) }
        }
      case .artist, .playlist, .songs, .recentlyAdded, .searchResults:
        EmptyView()
      }
    }
    copyItems
  }

  @ViewBuilder
  private var copyItems: some View {
    switch ref {
    case .track(let id):
      let track = model.track(id)
      CopyMenuItems(trackTitle: track?.title, artist: track?.artist, album: track?.album)
    case .album(let id):
      let album = model.album(id)
      CopyMenuItems(artist: album?.artist, album: album?.title)
    case .artist(let id):
      CopyMenuItems(artist: model.artist(id)?.name)
    case .playlist(let id):
      CopyMenuItems(playlist: model.playlist(id)?.name)
    case .songs, .recentlyAdded, .searchResults:
      EmptyView()
    }
  }
}

extension View {
  /// Long-press menu with queue actions and copy, plus swipe actions for
  /// Play Next (leading) and Play Later (trailing).
  func mediaActions(_ ref: MediaRef, playContext: MediaRef? = nil) -> some View {
    modifier(MediaActionsModifier(ref: ref, playContext: playContext))
  }
}

private struct MediaActionsModifier: ViewModifier {
  let ref: MediaRef
  let playContext: MediaRef?
  @Environment(AppModel.self) private var model

  func body(content: Content) -> some View {
    content
      .compactRowInsets()
      .contextMenu { MediaMenu(ref: ref, playContext: playContext) }
      .swipeActions(edge: .leading) {
        Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") { model.playNext(ref) }
          .tint(.orange)
      }
      .swipeActions(edge: .trailing) {
        Button("Play Later", systemImage: "text.line.last.and.arrowtriangle.forward") { model.playLater(ref) }
          .tint(.purple)
      }
      .accessibilityAction(named: "Play Next") { model.playNext(ref) }
      .accessibilityAction(named: "Play Later") { model.playLater(ref) }
  }
}
