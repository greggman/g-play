import XCTest

final class PlayItUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["-resetState", "-fixtureTrackCount", "100"]
    app.launch()
    XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
  }

  private var firstTrackRow: XCUIElement {
    app.descendants(matching: .any).matching(identifier: "TrackRow").firstMatch
  }

  private var miniPlayer: XCUIElement {
    app.descendants(matching: .any).matching(identifier: "MiniPlayer").firstMatch
  }

  private func goBack() {
    app.navigationBars.buttons.element(boundBy: 0).tap()
  }

  private func longPress(_ element: XCUIElement) {
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    element.press(forDuration: 1.0)
  }

  func testBrowseEachSort() {
    XCTAssertTrue(firstTrackRow.waitForExistence(timeout: 5))
    app.buttons["Albums"].tap()
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "AlbumRow").firstMatch.waitForExistence(timeout: 5))
    app.buttons["Artists"].tap()
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'songs'")).firstMatch.waitForExistence(timeout: 5))
    app.buttons["Added"].tap()
    XCTAssertTrue(firstTrackRow.waitForExistence(timeout: 5))
  }

  /// Playing goes straight to a full-screen Now Playing with a back button;
  /// the mini player then returns to it.
  func testShuffleAllShowsNowPlaying() {
    app.buttons["Shuffle All"].tap()
    XCTAssertTrue(app.staticTexts["Playing from Shuffle All"].waitForExistence(timeout: 5))
    XCTAssertFalse(miniPlayer.exists)
    goBack()
    XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
    XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5))
    miniPlayer.tap()
    XCTAssertTrue(app.staticTexts["Playing from Shuffle All"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.sliders["Playback position"].exists)
    let playPause = app.buttons["NowPlayingPlayPause"]
    XCTAssertEqual(playPause.label, "Pause")
    playPause.tap()
    XCTAssertEqual(playPause.label, "Play")
  }

  /// Without background audio the player would pause when the app leaves the
  /// foreground.
  func testKeepsPlayingInBackground() {
    app.buttons["Shuffle All"].tap()
    XCTAssertTrue(app.sliders["Playback position"].waitForExistence(timeout: 5))
    XCUIDevice.shared.press(.home)
    sleep(8)
    app.activate()
    let slider = app.sliders["Playback position"]
    XCTAssertTrue(slider.waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["NowPlayingPlayPause"].label, "Pause")
    // Elapsed time is shown as m:ss; at least 8 seconds have passed.
    let elapsed = (slider.value as? String ?? "").split(separator: ":").compactMap { Int($0) }
    XCTAssertEqual(elapsed.count, 2)
    XCTAssertGreaterThanOrEqual(elapsed[0] * 60 + elapsed[1], 8)
  }

  /// Dragging the position slider must not swipe back out of Now Playing.
  func testDraggingSliderStaysOnNowPlaying() {
    app.buttons["Shuffle All"].tap()
    let slider = app.sliders["Playback position"]
    XCTAssertTrue(slider.waitForExistence(timeout: 5))
    slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
    sleep(1)
    XCTAssertTrue(slider.exists)
    // It seeked: fixture tracks are 2–6 minutes, so 80% is past 1:30.
    let elapsed = (slider.value as? String ?? "").split(separator: ":").compactMap { Int($0) }
    XCTAssertEqual(elapsed.count, 2)
    XCTAssertGreaterThanOrEqual(elapsed[0] * 60 + elapsed[1], 90)
    XCTAssertTrue(app.navigationBars["Now Playing"].exists)
    // Also a drag across an empty part of the screen, below the controls.
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.95))
    start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.95)))
    sleep(1)
    XCTAssertTrue(app.navigationBars["Now Playing"].exists)
  }

  func testDraggingArtworkLeftGoesBack() {
    app.buttons["Shuffle All"].tap()
    let artwork = app.descendants(matching: .any)["Album artwork"]
    XCTAssertTrue(artwork.waitForExistence(timeout: 5))
    // A tap does nothing, and a short drag springs back.
    artwork.tap()
    artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
    sleep(1)
    XCTAssertTrue(app.navigationBars["Now Playing"].exists)
    artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)))
    XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
  }

  func testLongPressAlwaysOffersCopy() {
    longPress(firstTrackRow)
    XCTAssertTrue(app.buttons["Copy Track Name"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Copy Artist Name"].exists)
    XCTAssertTrue(app.buttons["Copy Album Name"].exists)
    XCTAssertTrue(app.buttons["Play Next"].exists)
    XCTAssertTrue(app.buttons["Play Later"].exists)
    XCTAssertTrue(app.buttons["Play Now"].exists)
    app.buttons["Copy Track Name"].tap()

    app.buttons["Albums"].tap()
    let album = app.cells.element(boundBy: 3)
    longPress(album)
    XCTAssertTrue(app.buttons["Copy Album Name"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Copy Artist Name"].exists)
  }

  func testPlayNextAppearsInUpNext() {
    app.buttons["Shuffle All"].tap()
    XCTAssertTrue(app.sliders["Playback position"].waitForExistence(timeout: 5))
    goBack()
    let row = firstTrackRow
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    let title = row.label.components(separatedBy: ",").first ?? ""
    longPress(row)
    app.buttons["Play Next"].tap()

    miniPlayer.tap()
    XCTAssertTrue(app.sliders["Playback position"].waitForExistence(timeout: 5))
    app.buttons["Up Next"].tap()
    XCTAssertTrue(app.staticTexts["Queued"].waitForExistence(timeout: 5))
    // The library screen underneath isn't in the accessibility tree, so a
    // match is the Up Next row. (Rows in an editable list lose their
    // identifier, so match by label.)
    let rows = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", title))
    XCTAssertTrue(rows.firstMatch.exists)
  }

  /// The artist's own page, not a search (which also shows other artists).
  func testArtistNameGoesToArtist() {
    let row = firstTrackRow
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    longPress(row)
    app.buttons["Go to Artist"].tap()
    XCTAssertTrue(app.staticTexts["Albums"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Songs"].exists)
    XCTAssertFalse(app.searchFields.firstMatch.exists)

    // And from Now Playing's artist name.
    goBack()
    app.buttons["Shuffle All"].tap()
    let artist = app.buttons["NowPlayingArtist"]
    XCTAssertTrue(artist.waitForExistence(timeout: 5))
    let name = artist.label
    artist.tap()
    XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Albums"].exists)
  }

  func testCreatePlaylistAndAddSong() {
    longPress(firstTrackRow)
    app.buttons["Add to Playlist"].tap()
    app.buttons["New Playlist…"].tap()
    let field = app.alerts.textFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.typeText("Test List")
    app.alerts.buttons["Create"].tap()

    app.tabBars.buttons["Playlists"].tap()
    let playlist = app.staticTexts["Test List"]
    XCTAssertTrue(playlist.waitForExistence(timeout: 5))
    playlist.tap()
    XCTAssertTrue(firstTrackRow.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Edit"].exists)
  }
}
