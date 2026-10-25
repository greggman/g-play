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
  @Environment(Router.self) private var router
  @ScaledMetric(relativeTo: .body) private var artworkSize = 44

  var body: some View {
    HStack(spacing: 12) {
      if let number {
        Text("\(number)")
          .font(.callout.monospacedDigit())
          .foregroundStyle(.secondary)
          .frame(minWidth: 24, alignment: .trailing)
      } else if showsArtwork {
        ArtworkView(trackID: track.id, size: min(artworkSize, 88))
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
    // The artist link isn't reachable inside the combined element.
    .accessibilityAction(named: "Search Artist") { router.showSearch(forArtist: track.artist) }
    .accessibilityIdentifier("TrackRow")
  }

  private var isCurrent: Bool { player.queue.current == track.id }
}

struct AlbumRow: View {
  let album: Album
  @ScaledMetric(relativeTo: .body) private var artworkSize = 56

  var body: some View {
    HStack(spacing: 12) {
      ArtworkView(trackID: album.artworkTrackID, size: min(artworkSize, 112))
      VStack(alignment: .leading, spacing: 2) {
        Text(album.title).lineLimit(1)
        Text(album.artist)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("AlbumRow")
  }
}

struct ArtistRow: View {
  let artist: Artist
  @ScaledMetric(relativeTo: .body) private var artworkSize = 44

  var body: some View {
    HStack(spacing: 12) {
      ArtworkView(trackID: artist.artworkTrackID, size: min(artworkSize, 88), cornerRadius: min(artworkSize, 88) / 2)
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
    [String(localized: "\(artist.albumIDs.count) albums"), String(localized: "\(artist.trackCount) songs")]
      .formatted(.list(type: .and, width: .narrow))
  }
}

struct PlaylistRow: View {
  let playlist: Playlist
  @ScaledMetric(relativeTo: .body) private var artworkSize = 56

  var body: some View {
    HStack(spacing: 12) {
      ArtworkView(trackID: playlist.trackIDs.first, size: min(artworkSize, 112))
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
  /// Tighter vertical padding than the List default.
  func compactRowInsets() -> some View {
    listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
  }
}
