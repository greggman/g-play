import SwiftUI

struct NowPlayingView: View {
  @Environment(PlayerController.self) private var player
  @Environment(Router.self) private var router

  /// Full screen, pushed onto the current tab like any other screen, so the
  /// back button returns to where the user was. Swipe right anywhere (but
  /// the position slider) to go back. Just the player: the queue is on its
  /// own screen, so nothing here competes with the slider's drag.
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
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Up Next", systemImage: "list.bullet") { router.show(.upNext) }
      }
    }
  }
}

/// The queue: songs queued with Play Next / Play Later (reorderable,
/// deletable), then the whole mode in play order, scrolled to where it's up
/// to. Tap a song in the mode to carry on from there.
struct UpNextView: View {
  @Environment(PlayerController.self) private var player
  /// Edit mode is only for reordering the queued songs: while it's on, the
  /// mode's rows can't be tapped.
  @State private var editMode = EditMode.inactive

  var body: some View {
    ScrollViewReader { proxy in
      List {
        UpNextSections()
      }
      .onAppear {
        guard !player.queue.modeTrackIDs.isEmpty else { return }
        proxy.scrollTo(UpNextSections.modeRowID(player.queue.modePosition), anchor: .top)
      }
    }
    .listStyle(.plain)
    .environment(\.editMode, $editMode)
    .navigationTitle("Up Next")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !player.queue.topQueue.isEmpty {
        ToolbarItem(placement: .primaryAction) {
          EditButton()
        }
      }
    }
    .onChange(of: player.queue.topQueue.isEmpty) { _, isEmpty in
      if isEmpty { editMode = .inactive }
    }
    .overlay {
      if player.queue.topQueue.isEmpty && player.queue.modeTrackIDs.isEmpty {
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

  var body: some View {
    VStack(spacing: 20) {
      if let mode = player.queue.mode {
        Button("Playing from \(model.title(for: mode))") { router.show(.upNext) }
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .buttonStyle(.borderless)
          .accessibilityHint("Shows the play order")
      }
      LargeArtworkView(trackID: track.id)
        .frame(maxWidth: 360)
        .accessibilityElement()
        .accessibilityLabel("Album artwork")
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
/// sits against the screen edge.) Drags here never start swipe-to-go-back.
/// Still a slider to VoiceOver.
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
        .gesture(BlocksSwipeBack())
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

/// Keeps the navigation controller's swipe-to-go-back from starting on this
/// view, without taking touches from the view's own gestures.
private struct BlocksSwipeBack: UIGestureRecognizerRepresentable {
  func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
    // Recognizes on touch down and holds until the touch ends, and swipe-back
    // waits for it to fail, so swipe-back can't start.
    let recognizer = UILongPressGestureRecognizer()
    recognizer.minimumPressDuration = 0
    recognizer.allowableMovement = .greatestFiniteMagnitude
    recognizer.cancelsTouchesInView = false
    recognizer.delegate = context.coordinator
    return recognizer
  }

  func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
      true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
      var responder: UIResponder? = gestureRecognizer.view
      while let current = responder, !(current is UINavigationController) { responder = current.next }
      guard let navigation = responder as? UINavigationController else { return false }
      if other === navigation.interactivePopGestureRecognizer { return true }
      if #available(iOS 26, *), other === navigation.interactiveContentPopGestureRecognizer { return true }
      return false
    }
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

/// The top queue (reorderable, deletable) followed by the mode in play
/// order, with the tracks already played this time through dimmed.
private struct UpNextSections: View {
  @Environment(AppModel.self) private var model
  @Environment(PlayerController.self) private var player

  /// Mode rows are identified by position (a playlist can repeat a track).
  static func modeRowID(_ index: Int) -> String { "mode-\(index)" }

  var body: some View {
    let topQueue = player.topQueueTracks
    if !topQueue.isEmpty {
      Section {
        ForEach(topQueue, id: \.entry.id) { item in
          TrackRow(track: item.track)
            .compactRowInsets()
            .contextMenu { MediaMenu(ref: .track(item.track.id)) }
        }
        .onMove { player.moveInTopQueue(fromOffsets: $0, toOffset: $1) }
        .onDelete { player.removeFromTopQueue(at: $0) }
      } header: {
        HStack {
          Text("Queued")
          Spacer()
          Button("Clear") { player.clearTopQueue() }
            .font(.subheadline)
            .textCase(nil)
            .accessibilityLabel("Clear Queued")
        }
      }
    }
    let modeTrackIDs = player.queue.modeTrackIDs
    if let mode = player.queue.mode, !modeTrackIDs.isEmpty {
      let position = player.queue.modePosition
      Section {
        ForEach(modeTrackIDs.indices, id: \.self) { index in
          if let track = model.track(modeTrackIDs[index]) {
            Button { player.jump(toModeIndex: index) } label: { TrackRow(track: track) }
              .buttonStyle(.plain)
              .opacity(index < position ? 0.5 : 1)
              .compactRowInsets()
              .contextMenu { MediaMenu(ref: .track(track.id)) }
              .deleteDisabled(true)
              .moveDisabled(true)
              .id(Self.modeRowID(index))
          }
        }
      } header: {
        HStack {
          Text("Playing from \(model.title(for: mode))")
            .lineLimit(1)
          Spacer()
          if player.queue.isShuffled {
            Button("Reshuffle", systemImage: "shuffle") { player.reshuffle() }
              .labelStyle(.titleAndIcon)
              .font(.subheadline)
              .textCase(nil)
              .accessibilityHint("Plays these songs in a new order after this one")
          }
        }
      }
    }
  }
}
