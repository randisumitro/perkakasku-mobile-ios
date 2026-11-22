// xcode: set sdk=iOS

import XCTest

@MainActor
final class PerkakaskuUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testGuestModeLaunchSplashToHomeWithoutLogin() {
        let app = XCUIApplication()
        app.launch()

        // Splash animates automatically into Home without blocking on authentication
        let exploreButton = app.buttons["home_explore_tools_button"]
        XCTAssertTrue(
            exploreButton.waitForExistence(timeout: 8),
            "Home screen should appear after splash without showing a login screen"
        )
        XCTAssertFalse(app.textFields["Email"].exists, "Login email field must not be displayed")
        XCTAssertFalse(app.secureTextFields["Password"].exists, "Login password field must not be displayed")
        capture("01_HomeScreen")
    }

    func testTabNavigationAndSettingsGuestMode() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["home_explore_tools_button"].waitForExistence(timeout: 8))

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)

        tabBar.buttons["Tools"].tap()
        XCTAssertTrue(app.navigationBars["Tool Directory"].waitForExistence(timeout: 3))
        capture("02_ToolDirectory")

        tabBar.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
        capture("07_HistoryTab")

        tabBar.buttons["Favorites"].tap()
        XCTAssertTrue(app.navigationBars["Favorites"].waitForExistence(timeout: 3))

        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Open Access"].waitForExistence(timeout: 3))
        capture("08_SettingsGuestMode")
    }

    func testSearchAndInteractiveLocalToolsWorkflow() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["home_explore_tools_button"].waitForExistence(timeout: 8))

        // Navigate into Tool Directory
        app.buttons["home_explore_tools_button"].tap()
        let catalogSearch = app.textFields["catalog_search_field"]
        XCTAssertTrue(catalogSearch.waitForExistence(timeout: 4))

        // Filter and open JSON Formatter & Validator
        catalogSearch.tap()
        catalogSearch.typeText("JSON")

        let jsonCard = app.buttons["tool_card_json-format"]
        XCTAssertTrue(jsonCard.waitForExistence(timeout: 4))
        jsonCard.tap()

        XCTAssertTrue(app.navigationBars["JSON Formatter & Validator"].waitForExistence(timeout: 4))
        app.buttons["Load Sample"].tap()
        app.buttons["json_beautify_button"].tap()
        XCTAssertTrue(app.staticTexts["VALID JSON"].waitForExistence(timeout: 3))
        capture("03_JSONFormatter")
    }

    func testQRCodeGeneratorLiveFlow() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["home_explore_tools_button"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Tools"].tap()

        let docsChip = app.buttons["catalog_filter_document"]
        XCTAssertTrue(docsChip.waitForExistence(timeout: 4))
        docsChip.tap()

        let qrCard = app.buttons["tool_card_qr-code"]
        XCTAssertTrue(qrCard.waitForExistence(timeout: 4))
        qrCard.tap()

        XCTAssertTrue(app.navigationBars["QR Code Generator"].waitForExistence(timeout: 4))
        let exportBtn = app.buttons["qr_export_button"]
        XCTAssertTrue(exportBtn.waitForExistence(timeout: 4))
        exportBtn.tap()
        XCTAssertTrue(app.staticTexts["QR PNG Saved"].waitForExistence(timeout: 4))
        capture("04_QRCodeStudio")
    }

    func testWordCounterLiveMetricsAndFavoritesPinning() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["home_explore_tools_button"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Tools"].tap()

        let searchField = app.textFields["catalog_search_field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 4))
        searchField.tap()
        searchField.typeText("Word Counter")

        let wcCard = app.buttons["tool_card_word-counter"]
        XCTAssertTrue(wcCard.waitForExistence(timeout: 4))
        wcCard.tap()

        XCTAssertTrue(app.navigationBars["Word Counter"].waitForExistence(timeout: 4))
        app.buttons["Sample Text"].tap()
        XCTAssertTrue(app.staticTexts["31"].waitForExistence(timeout: 4))
        capture("09_WordCounter")

        let favBtn = app.buttons["tool_favorite_button"]
        XCTAssertTrue(favBtn.waitForExistence(timeout: 3))
        if favBtn.label == "Add to favorites" {
            favBtn.tap()
        }
        app.tabBars.buttons["Favorites"].tap()
        let favCard = app.buttons["tool_card_word-counter"]
        XCTAssertTrue(favCard.waitForExistence(timeout: 4))
        // Unfavorite to restore clean state
        favCard.tap()
        if app.buttons["tool_favorite_button"].waitForExistence(timeout: 3) {
            if app.buttons["tool_favorite_button"].label == "Remove from favorites" {
                app.buttons["tool_favorite_button"].tap()
            }
        }
    }

    func testOpeningPDFCompressAndServerPlansSheet() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["home_explore_tools_button"].waitForExistence(timeout: 8))
        let pdfCat = app.buttons["home_category_pdf"]
        for _ in 0..<4 where !pdfCat.exists || !pdfCat.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        pdfCat.tap()

        let compressCard = app.buttons["tool_card_pdf-compress"]
        XCTAssertTrue(compressCard.waitForExistence(timeout: 4))
        compressCard.tap()

        XCTAssertTrue(app.navigationBars["Compress PDF"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["fileImportButton"].waitForExistence(timeout: 4))
        capture("05_PDFCompressStudio")

        app.tabBars.buttons["Home"].tap()
        let premiumBtn = app.buttons["home_premium_button"]
        for _ in 0..<6 where !premiumBtn.exists || !premiumBtn.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        if premiumBtn.waitForExistence(timeout: 3) {
            premiumBtn.tap()
            XCTAssertTrue(app.navigationBars["Plans & Quotas"].waitForExistence(timeout: 4))
            capture("06_PlansAndQuotas")
        }
    }
}
