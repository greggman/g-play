import XCTest

/// Scrolling the big library lists, with a 20,000-track library, or with the
/// device's real library when PERF_REAL_LIBRARY is set (pass it as
/// TEST_RUNNER_PERF_REAL_LIBRARY=1 to xcodebuild).
final class PerformanceTests: XCTestCase {
  private func launch(sort: String) -> XCUIApplication {
    let app = XCUIApplication()
    let realLibrary = ProcessInfo.processInfo.environment["PERF_REAL_LIBRARY"] != nil
    app.launchArguments = realLibrary ? [] : ["-fixtureTrackCount", "20000"]
    app.launch()
    XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 20))
    app.buttons[sort].tap()
    return app
  }

  private func measureScrolling(_ app: XCUIApplication) {
    let list = app.collectionViews.firstMatch
    let options = XCTMeasureOptions()
    options.invocationOptions = [.manuallyStop]
    // Each iteration scrolls further down, into rows whose artwork isn't
    // loaded yet.
    measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
      list.swipeUp(velocity: .fast)
      list.swipeUp(velocity: .fast)
      list.swipeUp(velocity: .fast)
      stopMeasuring()
    }
  }

  func testScrollSongs() {
    measureScrolling(launch(sort: "Songs"))
  }

  func testScrollAlbums() {
    measureScrolling(launch(sort: "Albums"))
  }
}
