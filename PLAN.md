# Play-It — Implementation Plan

This plan implements [DESIGN.md](DESIGN.md). It is ordered so that each phase
produces something runnable and testable on the Simulator.

## Key technical decisions

### Stack

* Swift 6, SwiftUI, Observation (`@Observable`), iOS 18+ deployment target.
* UIKit escape hatch: the big library lists (tens of thousands of rows,
  section index) are where SwiftUI is weakest. Build them in SwiftUI first and
  profile with the 20k-track fixture; if scrolling or the index isn't good
  enough, swap that one list for a `UICollectionView` behind
  `UIViewControllerRepresentable`. Row views stay SwiftUI either way
  (`UIHostingConfiguration`).
* `MediaPlayer` framework for library access and playback.
* Swift Testing for unit tests, XCUITest for a few UI smoke tests.
* Project defined with XcodeGen (`project.yml`) so the `.xcodeproj` is
  reproducible and diffs stay readable. Build/test via `xcodebuild` against an
  iPhone Simulator.

### Playback engine

Two options:

| | `MPMusicPlayerController.applicationQueuePlayer` | `AVQueuePlayer` + `MPMediaItem.assetURL` |
|---|---|---|
| Apple Music / DRM / cloud-only tracks | Plays them | `assetURL` is `nil` — can't play |
| Background + lock screen | Handled by the system | We implement (audio background mode, `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`) |
| Custom queue control | Indirect (queue descriptors, `perform(queueTransaction:)`) | Full |

**Decision:** use `applicationQueuePlayer`, because most real libraries contain
Apple Music / iCloud tracks that `AVPlayer` can't play. Our own `PlayQueue`
model is the source of truth for what plays next; we feed the system player a
short window (current track + next few) and rewrite that window whenever the
queue changes. Possible audible gaps when rewriting the window are not
addressed until the app is feature complete; because the engine sits behind
`PlaybackEngine`, it can be swapped for an `AVQueuePlayer` implementation
later without touching the rest of the app.

### The Simulator has no music library

`MPMediaQuery` returns nothing on the Simulator and the system music player
does not play there. So everything goes behind protocols:

```swift
protocol MusicLibrary {           // MPMediaQuery-backed, or fixture-backed
  func allTracks() async -> [Track]
  ...
}

protocol PlaybackEngine {         // applicationQueuePlayer, or a fake
  func play(_ tracks: [Track]) ...
  var events: AsyncStream<PlaybackEvent> { get }
}
```

* `SystemMusicLibrary` / `SystemPlaybackEngine` — real device.
* `FixtureMusicLibrary` — a few hundred generated tracks with artists, albums,
  bundled placeholder artwork, varied `lastPlayedDate` / `playCount` /
  `dateAdded`.
* `SimulatedPlaybackEngine` — an `AVPlayer` playing a bundled short silent (or
  tone) audio file per track, so background audio, lock screen, scrubbing and
  remote commands can all be exercised on the Simulator.

The implementation is chosen at launch (`#if targetEnvironment(simulator)`,
overridable with a launch argument for UI tests).

`Track` is our own value type (persistent ID, title, artist, album, album
persistent ID, artist persistent ID, duration, dateAdded, lastPlayedDate,
playCount, artwork provider) so the rest of the app never touches `MPMediaItem`.

## Architecture

```
PlayIt/
  App/              PlayItApp, dependency setup, deep-link routing
  Model/            Track, Album, Artist, PlayMode, PlayQueue, WeightedShuffle
  Library/          MusicLibrary protocol, SystemMusicLibrary, FixtureMusicLibrary, SearchIndex
  Playback/         PlaybackEngine protocol, SystemPlaybackEngine, SimulatedPlaybackEngine,
                    PlayerController (owns PlayQueue + engine), NowPlaying/RemoteCommands
  UI/
    Library/        sorted lists (track / album / artist / date added)
    Search/
    Detail/         AlbumView, ArtistView, PlaylistView
    NowPlaying/     mini player bar, full-screen player
    Components/     TrackRow, ArtworkView, QueueActionsMenu, CopyMenuItems
  Persistence/      saves mode + top queue + position
PlayItTests/
PlayItUITests/
```

### Play model (from DESIGN.md "Play Design")

```swift
enum PlayMode {
  case allTracks            // weighted shuffle of the whole library
  case playlist(ID)
  case album(ID)
  case artist(ID)
  case track(ID)
}
```

`PlayQueue` holds:

* `mode` and the ordered list of tracks it generates, plus a cursor.
* `topQueue: [Track]` — always played before resuming the mode.
* `history` for "previous".

Operations on any result (track, album, artist, playlist, search result):

| Action | Effect |
|---|---|
| **Play** | Replace the mode with this result and clear the top queue; start playing. |
| **Play Now** | Insert result at the front of the top queue; skip to it. |
| **Play Next** | Insert result at the front of the top queue. |
| **Play Later** | Append result to the end of the top queue. |

`next()` pops from the top queue if non-empty, otherwise advances the mode's
cursor. `previous()` restarts the current track if > 3 s in, otherwise steps
back through history. These are pure, synchronous and fully unit-tested.

### Weighted shuffle

Goal: get through the whole library, preferring tracks not heard recently.

* Weight depends only on `lastPlayedDate` (not play count):
  `w = min(days since last played, 365) + 1`; never played gets the maximum
  weight. Constants live in one place so they're easy to tune.
* Order produced by weighted random sampling without replacement
  (Efraimidis–Spirakis: key = `u^(1/w)`, sort descending). O(n log n), done
  once when the mode starts, on a background task.
* Tracks played during the session are recorded so a regenerated shuffle
  (e.g. after relaunch) doesn't immediately repeat them, even before the system
  updates `lastPlayedDate`.
* Tests: deterministic with an injected RNG; statistical test that
  long-unplayed tracks land earlier on average; every track appears exactly once.

### Search

In-memory `SearchIndex` built on library load: case- and
diacritic-insensitive prefix/substring match over track, artist and album
names. Results grouped into Tracks / Albums / Artists sections. Rebuilt on
`MPMediaLibraryDidChange`.

## Phases

### Phase 0 — Project setup

* XcodeGen project, app + unit test + UI test targets, `NSAppleMusicUsageDescription`,
  `UIBackgroundModes: audio`.
* `MPMediaLibrary.requestAuthorization` flow with a clear denied/restricted
  screen that links to Settings.

**Done when:** app builds and launches on the Simulator.

### Phase 1 — Library model and browsing

* `Track`/`Album`/`Artist`, `MusicLibrary` protocol, both implementations.
* Library tab with a segmented sort: Track name, Album, Artist, Date Added
  (newest first). Use sort keys that ignore leading "The"/"A" like the Music
  app, with section index for the name sorts.
* Album detail and artist detail screens.
* `ArtworkView` with caching and a placeholder.
* Long press on every track/album/artist row: context menu that always
  includes **Copy Track Name / Copy Artist Name / Copy Album Name** (whichever
  apply), via a shared `CopyMenuItems` component so it can't be forgotten.
* Tapping an artist name anywhere navigates to that artist's search results.

**Done when:** fixture library browsable in all four sorts on the Simulator;
copy works from every row type.

### Phase 2 — Play model

* `PlayMode`, `PlayQueue`, `WeightedShuffle` as pure Swift with thorough unit
  tests (all four queue actions, top-queue drains back to mode, end of mode,
  previous/history, removing a track that's in the queue).
* `QueueActionsMenu` (Play / Play Now / Play Next / Play Later) added to the
  same context menu as Copy, plus swipe actions for Play Next / Play Later.
* "Shuffle All" entry point at the top of the library.

**Done when:** unit tests green; actions are reachable from every result type.

### Phase 3 — Playback and Now Playing UI

* `PlayerController` connecting `PlayQueue` to a `PlaybackEngine`;
  `SimulatedPlaybackEngine` first, then `SystemPlaybackEngine`.
* Mini player bar (artwork, title, play/pause, next) above the tab bar.
* Full-screen Now Playing: large artwork, title / artist / album (artist and
  album tappable), scrub slider with elapsed/remaining time, prev / play-pause /
  next, and an "Up Next" list showing the top queue (reorder, swipe-to-delete)
  followed by upcoming mode tracks.
* Handle interruptions (calls, Siri) and route changes (headphones unplugged →
  pause).

**Done when:** on the Simulator you can shuffle all, queue things, scrub,
skip, and see Up Next update correctly.

### Phase 4 — Background, lock screen, deep links

* Background playback (system player handles it on device; `AVAudioSession`
  `.playback` category for the simulated engine).
* `MPNowPlayingInfoCenter` (title, artist, album, artwork, duration, elapsed)
  and `MPRemoteCommandCenter` (play, pause, toggle, next, previous,
  change playback position) — needed for the simulated engine and verified
  for the system engine.
* Lock-screen artwork tap: iOS opens the app without saying why, so the app
  can't tell this apart from a normal launch. The app returns to whatever
  screen the user was on; it does not jump to the album. (DESIGN.md's
  "lock-screen tap goes to the album" isn't possible with public API. The
  Now Playing screen's album name still goes to the album.)
* Persist and restore mode, top queue, current track and position across
  launches (store persistent IDs; drop any that no longer exist).

**Done when:** on the Simulator, audio continues with the app backgrounded,
lock screen shows artwork and controls that work, and relaunch restores state.

### Phase 5 — Search and playlists

* Search tab using `.searchable`, grouped results, debounced.
* Playlists list and detail (needed for the "play playlist" mode).
* Creating and editing playlists. `MediaPlayer` can only *create* system
  playlists and *append* to them: there's no public API to remove, reorder,
  rename or delete. So:
  * Play-It playlists are stored by the app (persistent IDs, SwiftData) and
    support full editing: create, rename, add, remove, reorder, delete.
  * System (Music app) playlists are shown read-only, with a "Duplicate as
    Play-It playlist" action to make an editable copy.
  * "Add to Playlist…" joins Play / Play Now / Play Next / Play Later in every
    result's menu.
* All results support Play / Play Now / Play Next / Play Later / Copy.

### Phase 6 — Polish and best practices

* Accessibility: VoiceOver labels on all controls, Dynamic Type, sufficient
  contrast, accessibility actions for queue operations.
* Dark mode, landscape. iPhone only (no iPad target).
* Large-library performance: test fixture with 20k tracks; lazy lists, index
  built off the main actor, artwork loaded on demand.
* Library change notifications refresh views without losing the queue.
* Empty states (no library, no results, nothing playing).
* Localizable strings (String Catalog) even if only English ships.

## Testing strategy

* **Unit (Swift Testing):** `PlayQueue`, `WeightedShuffle`, `SearchIndex`,
  sort-key logic, persistence round-trip, `PlayerController` with a fake engine.
* **UI (XCUITest on the Simulator)** with the fixture library: browse each
  sort, search, long-press copy (check `UIPasteboard`), queue actions reflected
  in Up Next, artist-name tap navigation.
* **Manual on Simulator:** background audio, lock screen
  (Device → Lock), remote commands.
* **Manual on device** (Simulator can't cover it): real library access,
  Apple Music/cloud tracks, system player behavior, lock-screen tap → album.

## Resolved decisions

1. "Queue slider" means the playback position scrubber.
2. Opening the app from the lock screen returns to the user's previous
   screen; no auto-navigation.
3. Shuffle weighting uses only time since last played.
4. **Play** (new mode) clears the top queue.
5. Playlists can be created and edited (app-owned; see Phase 5).
6. Minimum iOS version is 18.
7. Possible playback gaps are deferred until feature complete; the engine can
   be swapped for `AVQueuePlayer` later.
