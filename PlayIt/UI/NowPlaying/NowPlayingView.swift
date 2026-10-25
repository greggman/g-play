import SwiftUI

struct NowPlayingView: View {
  @Environment(AppModel.self) private var model
  @Environment(PlayerController.self) private var player
  @Environment(Router.self) private var router
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if let track = player.currentTrack {
          List {
            Section {
              NowPlayingHeader(track: track)
                .listRowSeparator(.hidden)
            }
            UpNextSections()
          }
          .listStyle(.plain)
          .environment(\.editMode, .constant(.active))
        } else {
          ContentUnavailableView(
            "Nothing Playing", systemImage: "music.note",
            description: Text("Choose something from your library, or Shuffle All."))
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "chevron.down") { dismiss() }
        }
        if !player.queue.topQueue.isEmpty {
          ToolbarItem(placement: .primaryAction) {
            Button("Clear Up Next") { player.clearTopQueue() }
          }
        }
      }
    }
  }
}

private struct NowPlayingHeader: View {
  let track: Track
  @Environment(PlayerController.self) private var player
  @Environment(Router.self) private var router

  var body: some View {
    VStack(spacing: 20) {
      Button { router.show(.album(track.albumID)) } label: {
        LargeArtworkView(trackID: track.id)
          .frame(maxWidth: 360)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Album artwork")
      .accessibilityHint("Shows the album")
      .contextMenu {
        CopyMenuItems(trackTitle: track.title, artist: track.artist, album: track.album)
      }

      VStack(spacing: 4) {
        Text(track.title)
          .font(.title2.bold())
          .multilineTextAlignment(.center)
          .contextMenu { CopyMenuItems(trackTitle: track.title) }
        Button(track.artist) { router.showSearch(forArtist: track.artist) }
          .font(.title3)
          .accessibilityHint("Shows search results for this artist")
          .contextMenu { CopyMenuItems(artist: track.artist) }
        Button(track.album) { router.show(.album(track.albumID)) }
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .accessibilityHint("Shows the album")
          .contextMenu { CopyMenuItems(album: track.album) }
      }
      .buttonStyle(.borderless)

      PositionSlider()
      TransportControls()
    }
    .padding(.vertical)
    .frame(maxWidth: .infinity)
  }
}

/// The playback position ("queue slider"), with elapsed and remaining time.
struct PositionSlider: View {
  @Environment(PlayerController.self) private var player
  @State private var scrubPosition: TimeInterval?

  var body: some View {
    let duration = max(player.duration, 1)
    let position = scrubPosition ?? min(player.elapsed, duration)
    VStack(spacing: 4) {
      Slider(
        value: Binding(get: { position }, set: { scrubPosition = $0 }),
        in: 0...duration
      ) { editing in
        if !editing, let scrubPosition {
          player.seek(to: scrubPosition)
          self.scrubPosition = nil
        }
      }
      .accessibilityLabel("Playback position")
      .accessibilityValue(Self.format(position))
      HStack {
        Text(Self.format(position))
        Spacer()
        Text("-" + Self.format(duration - position))
      }
      .font(.caption.monospacedDigit())
      .foregroundStyle(.secondary)
      .accessibilityHidden(true)
    }
  }

  static func format(_ time: TimeInterval) -> String {
    Duration.seconds(max(0, time.rounded())).formatted(.time(pattern: time >= 3600 ? .hourMinuteSecond : .minuteSecond))
  }
}

struct TransportControls: View {
  @Environment(PlayerController.self) private var player

  var body: some View {
    HStack(spacing: 48) {
      Button { player.previous() } label: {
        Image(systemName: "backward.fill").font(.title)
      }
      .accessibilityLabel("Previous Track")
      Button { player.togglePlayPause() } label: {
        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 44))
          .frame(width: 56, height: 56)
          .contentTransition(.symbolEffect(.replace))
      }
      .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
      .accessibilityIdentifier("NowPlayingPlayPause")
      Button { player.next() } label: {
        Image(systemName: "forward.fill").font(.title)
      }
      .accessibilityLabel("Next Track")
    }
    .buttonStyle(.borderless)
    .foregroundStyle(.primary)
  }
}

/// The top queue (reorderable, deletable) followed by what's next from the
/// mode.
private struct UpNextSections: View {
  @Environment(AppModel.self) private var model
  @Environment(PlayerController.self) private var player

  static let modePreviewCount = 50

  var body: some View {
    let topQueue = player.topQueueTracks
    if !topQueue.isEmpty {
      Section("Up Next") {
        ForEach(topQueue, id: \.entry.id) { item in
          TrackRow(track: item.track)
            .compactRowInsets()
            .contextMenu { MediaMenu(ref: .track(item.track.id)) }
        }
        .onMove { player.moveInTopQueue(fromOffsets: $0, toOffset: $1) }
        .onDelete { player.removeFromTopQueue(at: $0) }
      }
    }
    let upcoming = player.upcomingModeTracks(limit: Self.modePreviewCount)
    if let mode = player.queue.mode, !upcoming.isEmpty {
      Section {
        ForEach(Array(upcoming.enumerated()), id: \.offset) { _, track in
          TrackRow(track: track)
            .compactRowInsets()
            .contextMenu { MediaMenu(ref: .track(track.id)) }
            .deleteDisabled(true)
            .moveDisabled(true)
        }
      } header: {
        Text("Playing from \(model.title(for: mode))")
      }
    }
  }
}
