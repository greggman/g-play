import SwiftUI

struct NowPlayingView: View {
  @Environment(PlayerController.self) private var player
  @Environment(Router.self) private var router
  @Environment(\.dismiss) private var dismiss

  /// Full screen, pushed onto the current tab like any other screen, so the
  /// back button returns to where the user was. Just the player: the queue
  /// is on its own screen, so nothing here competes with the slider's drag.
  var body: some View {
    Group {
      if let track = player.currentTrack {
        NowPlayingHeader(track: track)
          .padding(.horizontal, 24)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ContentUnavailableView(
          "Nothing Playing", systemImage: "music.note",
          description: Text("Choose something from your library, or Shuffle All."))
      }
    }
    .navigationTitle("Now Playing")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    // Horizontal drags here are for the position slider, not for going
    // back. Hiding the system back button turns off swipe-to-go-back, so
    // put an identical one in its place.
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Back", systemImage: "chevron.backward") { dismiss() }
      }
      ToolbarItem(placement: .primaryAction) {
        Button("Up Next", systemImage: "list.bullet") { router.show(.upNext) }
      }
    }
  }
}

/// The queue: songs queued with Play Next / Play Later (reorderable,
/// deletable), then what's next from the current mode.
struct UpNextView: View {
  @Environment(PlayerController.self) private var player

  var body: some View {
    List {
      UpNextSections()
    }
    .listStyle(.plain)
    .environment(\.editMode, .constant(.active))
    .navigationTitle("Up Next")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !player.queue.topQueue.isEmpty {
        ToolbarItem(placement: .primaryAction) {
          Button("Clear Queued") { player.clearTopQueue() }
        }
      }
    }
    .overlay {
      if player.queue.upcomingTrackIDs.isEmpty {
        ContentUnavailableView("Nothing Up Next", systemImage: "list.bullet")
      }
    }
  }
}

private struct NowPlayingHeader: View {
  let track: Track
  @Environment(AppModel.self) private var model
  @Environment(PlayerController.self) private var player
  @Environment(Router.self) private var router
  @Environment(\.dismiss) private var dismiss
  /// How far the artwork has been dragged left.
  @State private var artworkDrag: CGFloat = 0

  /// Dragging the artwork left this far goes back.
  static let backDragDistance: CGFloat = 80

  var body: some View {
    VStack(spacing: 20) {
      if let mode = player.queue.mode {
        Text("Playing from \(model.title(for: mode))")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      LargeArtworkView(trackID: track.id)
        .frame(maxWidth: 360)
        .contentShape(Rectangle())
        .offset(x: artworkDrag)
        // Drag left to go back, so going back doesn't need a reach to the
        // far side of the screen. Tapping does nothing.
        .gesture(
          DragGesture(minimumDistance: 20)
            .onChanged { value in
              guard abs(value.translation.width) > abs(value.translation.height) else { return }
              artworkDrag = min(0, value.translation.width)
            }
            .onEnded { value in
              if value.translation.width < -Self.backDragDistance
                && abs(value.translation.width) > abs(value.translation.height) {
                dismiss()
              } else {
                withAnimation(.spring(duration: 0.3)) { artworkDrag = 0 }
              }
            })
        .accessibilityElement()
        .accessibilityLabel("Album artwork")
        .accessibilityAction(named: "Go Back") { dismiss() }
        .contextMenu {
          CopyMenuItems(trackTitle: track.title, artist: track.artist, album: track.album)
        }

      VStack(spacing: 4) {
        Text(track.title)
          .font(.title2.bold())
          .multilineTextAlignment(.center)
          .contextMenu { CopyMenuItems(trackTitle: track.title) }
        Button(track.artist) { router.show(.artist(track.artistID)) }
          .font(.title3)
          .accessibilityHint("Shows this artist")
          .accessibilityIdentifier("NowPlayingArtist")
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
///
/// Touch or drag anywhere along the bar to seek. (A system `Slider` only
/// moves if you start right on its small thumb, which at the start of a song
/// sits against the screen edge.) Still a slider to VoiceOver.
struct PositionSlider: View {
  @Environment(PlayerController.self) private var player
  @State private var scrubPosition: TimeInterval?

  /// VoiceOver adjusts by this much.
  static let accessibilityStep: TimeInterval = 10

  var body: some View {
    let duration = max(player.duration, 1)
    let position = scrubPosition ?? min(player.elapsed, duration)
    let isScrubbing = scrubPosition != nil
    VStack(spacing: 4) {
      GeometryReader { geometry in
        let width = geometry.size.width
        ZStack(alignment: .leading) {
          Capsule().fill(.quaternary)
          Capsule().fill(Color.accentColor)
            .frame(width: max(0, min(1, position / duration)) * width)
        }
        .frame(height: isScrubbing ? 12 : 6)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              scrubPosition = max(0, min(1, value.location.x / width)) * duration
            }
            .onEnded { _ in
              if let scrubPosition { player.seek(to: scrubPosition) }
              scrubPosition = nil
            })
        .animation(.easeOut(duration: 0.15), value: isScrubbing)
      }
      .frame(height: 44)
      .accessibilityRepresentation {
        Slider(value: Binding(get: { position }, set: { player.seek(to: $0) }), in: 0...duration,
               step: Self.accessibilityStep)
          .accessibilityLabel("Playback position")
          .accessibilityValue(Self.format(position))
      }
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
      Section("Queued") {
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
