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
    // Scroll a little, past the artwork and controls, to Up Next.
    let list = app.collectionViews.firstMatch
    list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
      .press(forDuration: 0.1, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
    XCTAssertTrue(app.staticTexts["Up Next"].waitForExistence(timeout: 5))
    // The library screen underneath isn't in the accessibility tree, so a
    // match is the Up Next row. (Rows in an editable list lose their
    // identifier, so match by label.)
    let rows = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", title))
    XCTAssertTrue(rows.firstMatch.exists)
  }

  func testArtistNameGoesToSearch() {
    let row = firstTrackRow
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    longPress(row)
    app.buttons["Search Artist"].tap()
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    XCTAssertFalse((field.value as? String ?? "").isEmpty)
    XCTAssertTrue(app.staticTexts["Artists"].waitForExistence(timeout: 5))
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
