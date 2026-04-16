import XCTest
@testable import iWalk_AI

final class CoachAPIClientTests: XCTestCase {
    func testTransientURLErrorIsRetryable() {
        XCTAssertTrue(CoachAPIClient.shouldRetry(error: URLError(.timedOut)))
    }

    func testInvalidPayloadIsNotRetryable() {
        XCTAssertFalse(CoachAPIClient.shouldRetry(error: CoachAPIError.invalidPayload))
    }
}
