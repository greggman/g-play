import Foundation

/// An entry in the top queue. Has its own identity so the same track can be
/// queued more than once and still be moved or removed individually.
struct QueueEntry: Identifiable, Hashable, Sendable, Codable {
  let id: UUID
  let trackID: Track.ID

  init(trackID: Track.ID, id: UUID = UUID()) {
    self.id = id
    self.trackID = trackID
  }
}

/// The play model from DESIGN.md: a mode, with a "top queue" layered on top.
/// If anything is in the top queue it plays first; when the top queue is
/// empty, playback returns to the mode.
///
/// Pure value type with no side effects so it can be tested exhaustively.
struct PlayQueue: Hashable, Sendable, Codable {
  enum Source: Hashable, Sendable, Codable {
    case mode
    case topQueue
    case history
  }

  private(set) var mode: PlayMode?
  private(set) var modeTrackIDs: [Track.ID] = []
  /// Index into `modeTrackIDs` of the next mode track to play.
  private(set) var modeIndex = 0
  private(set) var topQueue: [QueueEntry] = []
  private(set) var current: Track.ID?
  private(set) var currentSource: Source = .mode
  private(set) var history: [Track.ID] = []

  static let maxHistory = 500

  init() {}

  /// Mode tracks that have not been played yet.
  var upcomingModeTrackIDs: ArraySlice<Track.ID> {
    modeTrackIDs[min(modeIndex, modeTrackIDs.count)...]
  }

  /// Everything that will play after `current`, in order.
  var upcomingTrackIDs: [Track.ID] {
    topQueue.map(\.trackID) + upcomingModeTrackIDs
  }

  // MARK: - Queue actions

  /// Make `trackIDs` the new mode, clear the top queue, and start playing at
  /// `startIndex`.
  mutating func play(mode: PlayMode, trackIDs: [Track.ID], startIndex: Int = 0) {
    pushCurrentToHistory()
    self.mode = mode
    modeTrackIDs = trackIDs
    topQueue.removeAll()
    if trackIDs.indices.contains(startIndex) {
      current = trackIDs[startIndex]
      currentSource = .mode
      modeIndex = startIndex + 1
    } else {
      current = nil
      modeIndex = trackIDs.count
    }
  }

  /// Put the tracks at the front of the top queue and start playing them now.
  mutating func playNow(_ trackIDs: [Track.ID]) {
    guard !trackIDs.isEmpty else { return }
    playNext(trackIDs)
    advance()
  }

  /// Put the tracks at the front of the top queue so they play next.
  mutating func playNext(_ trackIDs: [Track.ID]) {
    topQueue.insert(contentsOf: trackIDs.map { QueueEntry(trackID: $0) }, at: 0)
    startIfIdle()
  }

  /// Put the tracks at the end of the top queue.
  mutating func playLater(_ trackIDs: [Track.ID]) {
    topQueue.append(contentsOf: trackIDs.map { QueueEntry(trackID: $0) })
    startIfIdle()
  }

  // MARK: - Transport

  /// Moves to the next track. Returns the new current track, or nil when
  /// everything has been played.
  @discardableResult
  mutating func advance() -> Track.ID? {
    pushCurrentToHistory()
    if !topQueue.isEmpty {
      current = topQueue.removeFirst().trackID
      currentSource = .topQueue
    } else if modeIndex < modeTrackIDs.count {
      current = modeTrackIDs[modeIndex]
      currentSource = .mode
      modeIndex += 1
    } else {
      current = nil
      currentSource = .mode
    }
    return current
  }

  /// Steps back to the previously played track. The current track is put
  /// back so it plays again after the previous one. Returns false if there is
  /// no history.
  @discardableResult
  mutating func goBack() -> Bool {
    guard let previous = history.popLast() else { return false }
    if let current {
      switch currentSource {
      case .mode:
        modeIndex -= 1
      case .topQueue, .history:
        topQueue.insert(QueueEntry(trackID: current), at: 0)
      }
    }
    current = previous
    currentSource = .history
    return true
  }

  // MARK: - Editing the top queue

  mutating func removeFromTopQueue(at offsets: IndexSet) {
    for index in offsets.sorted(by: >) where topQueue.indices.contains(index) {
      topQueue.remove(at: index)
    }
  }

  mutating func moveInTopQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
    let moving = source.sorted().filter { topQueue.indices.contains($0) }.map { topQueue[$0] }
    let insertAt = destination - source.filter { $0 < destination }.count
    removeFromTopQueue(at: source)
    topQueue.insert(contentsOf: moving, at: max(0, min(insertAt, topQueue.count)))
  }

  mutating func clearTopQueue() {
    topQueue.removeAll()
  }

  /// Drops tracks that no longer exist in the library.
  mutating func removeTracks(notIn valid: Set<Track.ID>) {
    let upcoming = Array(upcomingModeTrackIDs).filter(valid.contains)
    let played = modeTrackIDs[..<min(modeIndex, modeTrackIDs.count)].filter(valid.contains)
    modeTrackIDs = played + upcoming
    modeIndex = played.count
    topQueue.removeAll { !valid.contains($0.trackID) }
    history.removeAll { !valid.contains($0) }
    if let current, !valid.contains(current) {
      self.current = nil
      advance()
    }
  }

  // MARK: - Syncing with an engine that advanced on its own

  /// Brings the queue in line with a track the playback engine reports as
  /// playing. The engine may have moved ahead several tracks (or back one)
  /// while the app was suspended. Returns false if `trackID` isn't nearby,
  /// in which case nothing changes.
  @discardableResult
  mutating func sync(toPlaying trackID: Track.ID?) -> Bool {
    guard let trackID else {
      // The engine ran out of tracks.
      while current != nil { advance() }
      return true
    }
    if current == trackID { return true }
    if let steps = upcomingTrackIDs.firstIndex(of: trackID) {
      for _ in 0...steps { advance() }
      return true
    }
    if history.last == trackID {
      goBack()
      return true
    }
    return false
  }

  // MARK: - Private

  private mutating func pushCurrentToHistory() {
    guard let current else { return }
    history.append(current)
    if history.count > Self.maxHistory {
      history.removeFirst(history.count - Self.maxHistory)
    }
  }

  private mutating func startIfIdle() {
    if current == nil { advance() }
  }
}
