import SwiftUI

/// A button showing an artist's name. Tapping it goes to that artist's
/// search results.
struct ArtistLink: View {
  let name: String
  @Environment(Router.self) private var router

  var body: some View {
    Button(name) { router.showSearch(forArtist: name) }
      .buttonStyle(.borderless)
      .foregroundStyle(.secondary)
      .accessibilityHint("Shows search results for this artist")
  }
}

struct TrackRow: View {
  let track: Track
  var showsArtwork = true
  /// Shown instead of artwork, e.g. in an album.
  var number: Int?
  var detail: String?

  @Environment(PlayerController.self) private var player

  var body: some View {
    HStack(spacing: 12) {
      if let number {
        Text("\(number)")
          .font(.callout.monospacedDigit())
          .foregroundStyle(.secondary)
          .frame(minWidth: 24, alignment: .trailing)
      } else if showsArtwork {
        ArtworkView(trackID: track.id, size: 44)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(track.title)
          .foregroundStyle(isCurrent ? Color.accentColor : .primary)
          .lineLimit(1)
        HStack(spacing: 4) {
          ArtistLink(name: track.artist)
            .lineLimit(1)
          if let detail {
            Text("· \(detail)")
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        .font(.subheadline)
      }
      Spacer(minLength: 0)
      if isCurrent {
        Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
          .foregroundStyle(Color.accentColor)
          .accessibilityLabel("Now Playing")
      }
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("TrackRow")
  }

  private var isCurrent: Bool { player.queue.current == track.id }
}

struct AlbumRow: View {
  let album: Album

  var body: some View {
    HStack(spacing: 12) {
      ArtworkView(trackID: album.artworkTrackID, size: 56)
      VStack(alignment: .leading, spacing: 2) {
        Text(album.title).lineLimit(1)
        Text(album.artist)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

struct ArtistRow: View {
  let artist: Artist

  var body: some View {
    HStack(spacing: 12) {
      ArtworkView(trackID: artist.artworkTrackID, size: 44, cornerRadius: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text(artist.name).lineLimit(1)
        Text(summary)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var summary: String {
    let albums = artist.albumIDs.count
    return String(localized: "\(albums) albums, \(artist.trackCount) songs")
  }
}

struct PlaylistRow: View {
  let playlist: Playlist

  var body: some View {
    HStack(spacing: 12) {
      ArtworkView(trackID: playlist.trackIDs.first, size: 56)
      VStack(alignment: .leading, spacing: 2) {
        Text(playlist.name).lineLimit(1)
        Text("\(playlist.trackIDs.count) songs")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

extension View {
  /// Adds a section index letter where the OS supports it.
  @ViewBuilder
  func sectionIndex(_ letter: String) -> some View {
    if #available(iOS 26.0, *) {
      sectionIndexLabel(letter)
    } else {
      self
    }
  }

  @ViewBuilder
  func showsSectionIndex() -> some View {
    if #available(iOS 26.0, *) {
      listSectionIndexVisibility(.visible)
    } else {
      self
    }
  }
}
