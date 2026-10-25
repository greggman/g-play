import XCTest

/// Scrolling the big library lists, with a 20,000-track library.
final class PerformanceTests: XCTestCase {
  private func launch(sort: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-resetState", "-fixtureTrackCount", "20000"]
    app.launch()
    XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 20))
    app.buttons[sort].tap()
    return app
  }

  private func measureScrolling(_ app: XCUIApplication) {
    let list = app.collectionViews.firstMatch
    let options = XCTMeasureOptions()
    options.invocationOptions = [.manuallyStop]
    measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
      list.swipeUp(velocity: .fast)
      stopMeasuring()
      list.swipeDown(velocity: .fast)
    }
  }

  func testScrollSongs() {
    measureScrolling(launch(sort: "Songs"))
  }

  func testScrollAlbums() {
    measureScrolling(launch(sort: "Albums"))
  }
}
