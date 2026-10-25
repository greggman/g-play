import SwiftUI

/// The bar above the tab bar showing what's playing. Tap to open Now Playing.
struct MiniPlayer: View {
  @Environment(PlayerController.self) private var player
  @Environment(Router.self) private var router

  var body: some View {
    if let track = player.currentTrack {
      HStack(spacing: 12) {
        ArtworkView(trackID: track.id, size: 36)
        VStack(alignment: .leading, spacing: 0) {
          Text(track.title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
          Text(track.artist)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        Button {
          player.previous()
        } label: {
          Image(systemName: "backward.fill")
            .font(.title3)
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Previous Track")
        Button {
          player.togglePlayPause()
        } label: {
          Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
            .font(.title3)
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
        Button {
          player.next()
        } label: {
          Image(systemName: "forward.fill")
            .font(.title3)
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Next Track")
      }
      .buttonStyle(.plain)
      .padding(.leading, 12)
      .padding(.trailing, 4)
      .contentShape(Rectangle())
      .onTapGesture { router.showNowPlaying() }
      .accessibilityAction(named: "Open Now Playing") { router.showNowPlaying() }
      .accessibilityIdentifier("MiniPlayer")
      .contextMenu {
        CopyMenuItems(trackTitle: track.title, artist: track.artist, album: track.album)
      }
    }
  }
}

extension View {
  /// On iOS 26.1+ the mini player lives in the tab view's bottom accessory.
  @ViewBuilder
  func miniPlayerAccessory() -> some View {
    if #available(iOS 26.1, *) {
      modifier(MiniPlayerAccessory())
    } else {
      self
    }
  }

  /// Before iOS 26.1, the mini player is inset above each tab's content.
  @ViewBuilder
  func miniPlayerInset() -> some View {
    if #available(iOS 26.1, *) {
      self
    } else {
      modifier(MiniPlayerInset())
    }
  }
}

@available(iOS 26.1, *)
private struct MiniPlayerAccessory: ViewModifier {
  @Environment(PlayerController.self) private var player
  @Environment(Router.self) private var router

  func body(content: Content) -> some View {
    content.tabViewBottomAccessory(isEnabled: player.currentTrack != nil && !router.isShowingNowPlaying) {
      MiniPlayer()
    }
  }
}

private struct MiniPlayerInset: ViewModifier {
  @Environment(PlayerController.self) private var player
  @Environment(Router.self) private var router

  func body(content: Content) -> some View {
    content.safeAreaInset(edge: .bottom, spacing: 0) {
      if player.currentTrack != nil && !router.isShowingNowPlaying {
        MiniPlayer()
          .padding(.vertical, 6)
          .background(.bar)
          .overlay(alignment: .top) { Divider() }
      }
    }
  }
}
