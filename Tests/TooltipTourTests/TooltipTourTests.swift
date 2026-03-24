import XCTest
@testable import TooltipTour

final class TooltipTourTests: XCTestCase {

    func testTTStylesHexParsing() {
        let styles = TTStyles(primaryColor: "#1925AA", buttonRadius: nil, cardRadius: nil)
        let color = styles.resolvedPrimaryColor
        XCTAssertNotNil(color)
    }

    func testTTStepDecoding() throws {
        let json = """
        {"title":"Hello","text":"World","selector":"loginButton"}
        """.data(using: .utf8)!
        let step = try JSONDecoder().decode(TTStep.self, from: json)
        XCTAssertEqual(step.selector, "loginButton")
    }
}
