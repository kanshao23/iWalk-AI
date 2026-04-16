import XCTest
@testable import iWalk_AI

final class AppDeepLinkRouterTests: XCTestCase {
    func testHomeURLRoutesToHome() {
        let url = URL(string: "iwalkai://home")!
        XCTAssertEqual(AppDeepLinkRouter.route(for: url), .home)
    }

    func testActiveWalkURLRoutesToActiveWalk() {
        let url = URL(string: "iwalkai://active-walk")!
        XCTAssertEqual(AppDeepLinkRouter.route(for: url), .activeWalk)
    }
}
