import XCTest
@testable import PlayAndLearnCore

final class ScreenTimeGuardTests: XCTestCase {
    let policy = ScreenTimePolicy(dailyMinutes: 30, sessionMinutes: 10,
                                  allowedFromMinute: 7 * 60, allowedToMinute: 19 * 60, version: 1)

    func testAllowedWithinLimits() {
        XCTAssertEqual(ScreenTimeGuard.decide(policy: policy, minutesOfDay: 9 * 60, playedToday: 5, playedThisSession: 3), .allowed)
    }
    func testSessionBreak() {
        XCTAssertEqual(ScreenTimeGuard.decide(policy: policy, minutesOfDay: 9 * 60, playedToday: 12, playedThisSession: 10), .sessionBreak)
    }
    func testDailyLimitWinsOverSession() {
        XCTAssertEqual(ScreenTimeGuard.decide(policy: policy, minutesOfDay: 9 * 60, playedToday: 30, playedThisSession: 10), .dailyLimitReached)
    }
    func testOutsideAllowedHours() {
        XCTAssertEqual(ScreenTimeGuard.decide(policy: policy, minutesOfDay: 20 * 60, playedToday: 0, playedThisSession: 0), .outsideAllowedHours)
    }
    func testWindowCrossingMidnight() {
        var night = policy
        night.allowedFromMinute = 22 * 60
        night.allowedToMinute = 6 * 60
        XCTAssertEqual(ScreenTimeGuard.decide(policy: night, minutesOfDay: 23 * 60, playedToday: 0, playedThisSession: 0), .allowed)
        XCTAssertEqual(ScreenTimeGuard.decide(policy: night, minutesOfDay: 12 * 60, playedToday: 0, playedThisSession: 0), .outsideAllowedHours)
    }
}
