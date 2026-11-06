import XCTest
@testable import PlayAndLearnCore

final class ActivitiesTests: XCTestCase {
    var events: [GameEvent] = []
    var n = 0
    func session(_ task: Task, level: Int = 1) -> LevelSession {
        LevelSession(childId: "child", activityId: "act", contentVersion: 1, level: level, task: task,
                     now: { Int64(1000 + self.n) }, newId: { self.n += 1; return "id-\(self.n)" }, emit: { self.events.append($0) })
    }

    func testCountCorrectFirstTryCompletes() {
        let s = session(.count(count: 3, options: [2, 3, 4]))
        XCTAssertEqual(s.answer(.choose("3")), .levelCompleted)
        XCTAssertEqual(events.map(\.type), [.started, .attempt, .completed])
        XCTAssertTrue(s.finished)
    }

    func testProgressiveHintsThenRevealWithoutPenalty() {
        let s = session(.pattern(options: ["A", "B", "C"], answer: "A"))
        XCTAssertEqual(s.answer(.choose("B")), .tryAgain(hintLevel: 1))
        XCTAssertEqual(s.answer(.choose("C")), .tryAgain(hintLevel: 2))
        XCTAssertEqual(s.answer(.choose("B")), .revealed(correct: "A"))
        XCTAssertTrue(s.finished)
        XCTAssertEqual(events.last { $0.type == .completed }?.payload["revealed"], 1)
    }

    func testSortNeedsAllItems() {
        let s = session(.sort(itemGroups: ["a": "red", "b": "blue"]))
        XCTAssertEqual(s.answer(.place(itemId: "a", groupId: "blue")), .tryAgain(hintLevel: 1))
        XCTAssertEqual(s.answer(.place(itemId: "a", groupId: "red")), .correct)
        XCTAssertFalse(s.finished)
        XCTAssertEqual(s.answer(.place(itemId: "b", groupId: "blue")), .levelCompleted)
    }

    func testAbandonEmitsOnce() {
        let s = session(.count(count: 1, options: [1, 2]))
        s.abandon(); s.abandon()
        XCTAssertEqual(events.filter { $0.type == .abandoned }.count, 1)
    }

    func testLevelPolicyNeverDemotes() {
        XCTAssertEqual(LevelPolicy.nextLevel(current: 1, maxLevel: 3, wrongAttempts: 0, revealed: false), 2)
        XCTAssertEqual(LevelPolicy.nextLevel(current: 1, maxLevel: 3, wrongAttempts: 2, revealed: false), 1)
        XCTAssertEqual(LevelPolicy.nextLevel(current: 1, maxLevel: 3, wrongAttempts: 0, revealed: true), 1)
        XCTAssertEqual(LevelPolicy.nextLevel(current: 3, maxLevel: 3, wrongAttempts: 0, revealed: false), 3)
    }

    func testBatchChronologicalAndCapped() {
        let many = (1...600).map { GameEvent(id: "e\($0)", childId: "c", activityId: "a", contentVersion: 1, type: .attempt, payload: [:], deviceTsMillis: Int64(600 - $0)) }
        let b = SyncBatcher.nextBatch(many)
        XCTAssertEqual(b.count, 500)
        XCTAssertTrue(zip(b, b.dropFirst()).allSatisfy { $0.deviceTsMillis <= $1.deviceTsMillis })
    }

    func testSessionTracker() {
        let min: Int64 = 60_000
        var s = SessionTracker.record(SessionTracker.State(), startMs: 0, endMs: 10 * min)
        XCTAssertEqual(SessionTracker.sessionMinutes(s, nowMs: 10 * min + 30_000), 10)
        XCTAssertEqual(SessionTracker.sessionMinutes(s, nowMs: 16 * min), 0)
        s = SessionTracker.record(s, startMs: 20 * min, endMs: 23 * min)
        XCTAssertEqual(SessionTracker.sessionMinutes(s, nowMs: 24 * min), 3)
    }
}
