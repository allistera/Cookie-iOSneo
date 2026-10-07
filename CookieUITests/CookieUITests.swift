import XCTest

/// Exercises native navigation and recovery using synthetic, in-process responses.
@MainActor
final class CookieUITests: XCTestCase {
    private func launch(signedIn: Bool = true, emptyToday: Bool = false, largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        if signedIn { app.launchArguments.append("-ui-testing-signed-in") }
        if emptyToday { app.launchArguments.append("-ui-testing-empty-today") }
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    func testSignInAndSignOutReturnToTheSignInScreen() {
        let app = launch(signedIn: false)
        let signIn = app.buttons["signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        let account = app.buttons["accountMenu"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()
        app.buttons["Sign out"].tap()

        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
    }

    func testClosedDrawerKeepsTabsAndSidebarInteractive() {
        let app = launch()
        let other = app.buttons["mailbox-tab-other"]
        XCTAssertTrue(other.waitForExistence(timeout: 5))
        other.tap()
        XCTAssertTrue(other.isSelected)
        let important = app.buttons["mailbox-tab-important"]
        important.tap()
        XCTAssertTrue(important.isSelected)
        select("Sent", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["message-fixture-sent"].waitForExistence(timeout: 5))
    }

    func testReaderShowsRemoteContentActionAndSendsReply() {
        let app = launch()
        let message = app.descendants(matching: .any)["message-fixture-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()

        let showContent = app.buttons["showRemoteContent"]
        XCTAssertTrue(showContent.waitForExistence(timeout: 5))
        let body = app.webViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        XCTAssertTrue(body.staticTexts["Fixture body visible."].waitForExistence(timeout: 5))
        let reply = app.buttons["toggleReply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        reply.tap()
        let input = app.descendants(matching: .any)["replyText"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("A fixture reply")
        app.buttons["sendReply"].tap()

        XCTAssertTrue(app.staticTexts["Reply sent to Jordan."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["replyText"].exists)
    }

    func testSentMessageReplyNamesTheRecipient() {
        let app = launch()
        select("Sent", in: app)
        let message = app.descendants(matching: .any)["message-fixture-sent"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()
        let reply = app.buttons["toggleReply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        reply.tap()

        XCTAssertTrue(app.descendants(matching: .any)["replyText"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["replyText"].placeholderValue, "Reply to Jordan")
    }

    func testEmptyTodayShowsRateLimitFeedback() {
        let app = launch(emptyToday: true)
        select("AI Today", in: app)
        XCTAssertTrue(app.staticTexts["No triage yet"].waitForExistence(timeout: 5))
        app.buttons["Refresh"].tap()

        XCTAssertTrue(app.staticTexts["Too many refreshes. Try again shortly."].waitForExistence(timeout: 5))
    }

    func testTodayReferenceOpensTheReaderAndReturnsWithNativeBack() {
        let app = launch()
        select("AI Today", in: app)
        let item = app.descendants(matching: .any)["triage-fixture-message"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        XCTAssertTrue(app.buttons["toggleReply"].waitForExistence(timeout: 5))
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(item.waitForExistence(timeout: 5))
    }

    func testLargeTextKeepsReaderActionsAccessible() {
        let app = launch(largeText: true)
        let message = app.descendants(matching: .any)["message-fixture-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()
        let showContent = app.buttons["showRemoteContent"]
        XCTAssertTrue(showContent.waitForExistence(timeout: 5))
        XCTAssertTrue(showContent.isHittable)
        XCTAssertTrue(app.webViews.firstMatch.staticTexts["Fixture body visible."].waitForExistence(timeout: 5))
        let reply = app.buttons["toggleReply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        let reader = app.scrollViews["readerScroll"]
        for _ in 0..<5 {
            let frame = reply.frame
            if frame.minY >= reader.frame.minY, frame.maxY <= reader.frame.maxY { break }
            reader.swipeUp()
        }
        XCTAssertTrue(reply.frame.minY >= reader.frame.minY && reply.frame.maxY <= reader.frame.maxY)
        XCTAssertTrue(reply.isHittable)
    }

    private func select(_ folder: String, in app: XCUIApplication) {
        let sidebar = app.buttons["openSidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        sidebar.tap()
        let destination = app.buttons[folder]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.tap()
    }
}
