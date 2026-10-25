import XCTest

/// Walks the main screens and saves screenshots for review. Skipped unless
/// SCREENSHOT_DIR is set, e.g.
/// `TEST_RUNNER_SCREENSHOT_DIR=/tmp/shots xcodebuild test -only-testing:PlayItUITests/ScreenshotTour`
final class ScreenshotTour: XCTestCase {
  func testTour() throws {
    guard let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
      throw XCTSkip("Set SCREENSHOT_DIR to run")
    }
    let dir = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let app = XCUIApplication()
    app.launchArguments = ["-resetState", "-fixtureTrackCount", "400"] + (ProcessInfo.processInfo.environment["TOUR_ARGS"]?.split(separator: " ").map(String.init) ?? [])
    app.launch()
    func shot(_ name: String) {
      sleep(1)
      try? app.screenshot().pngRepresentation.write(to: dir.appending(path: "\(name).png"))
    }
    XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
    shot("01-songs")
    app.buttons["Albums"].tap()
    shot("02-albums")
    app.cells.element(boundBy: 3).tap()
    shot("03-album")
    // Tap the right side of the row: the artist name is its own link.
    app.descendants(matching: .any).matching(identifier: "TrackRow").element(boundBy: 0)
      .coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.buttons["Artists"].tap()
    shot("04-artists")
    app.cells.element(boundBy: 3).tap()
    shot("05-artist")
    app.swipeUp()
    let row = app.descendants(matching: .any).matching(identifier: "TrackRow").element(boundBy: 2)
    row.press(forDuration: 1)
    shot("06-menu")
    app.buttons["Play Later"].tap()
    app.descendants(matching: .any).matching(identifier: "MiniPlayer").firstMatch.tap()
    shot("07-now-playing")
    app.swipeUp()
    shot("08-up-next")
    app.buttons["Close"].tap()
    app.buttons["Playlists"].firstMatch.tap()
    shot("09-playlists")
    app.buttons["Search"].firstMatch.tap()
    app.searchFields.firstMatch.tap()
    app.searchFields.firstMatch.typeText("gold")
    shot("10-search")
  }
}
