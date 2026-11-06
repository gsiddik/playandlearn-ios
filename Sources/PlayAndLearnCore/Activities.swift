import Foundation

/// Tugas dalam satu level. Padanan `LevelTask` di Android.
public enum LevelTask: Equatable {
    case sort(itemGroups: [String: String])
    case pattern(options: [String], answer: String)
    case count(count: Int, options: [Int])
}

public enum Answer: Equatable {
    case place(itemId: String, groupId: String)
    case choose(String)
}

/// Umpan balik selalu suportif; kesalahan tidak mengurangi skor.
public enum Feedback: Equatable {
    case correct
    case levelCompleted
    case tryAgain(hintLevel: Int)
    case revealed(correct: String)
}

public enum EventType: String {
    case started, attempt, completed, abandoned
    case hint = "hint_shown"
}

public struct GameEvent: Equatable {
    public let id: String
    public let childId: String
    public let activityId: String
    public let contentVersion: Int
    public let type: EventType
    public let payload: [String: Int]
    public let deviceTsMillis: Int64
    public init(id: String, childId: String, activityId: String, contentVersion: Int, type: EventType, payload: [String: Int], deviceTsMillis: Int64) {
        self.id = id; self.childId = childId; self.activityId = activityId; self.contentVersion = contentVersion
        self.type = type; self.payload = payload; self.deviceTsMillis = deviceTsMillis
    }
}

/// Satu permainan satu level; perilakunya identik dengan LevelSession Android.
public final class LevelSession {
    public private(set) var wrongAttempts = 0
    public private(set) var hintsShown = 0
    public private(set) var finished = false
    private var consecutiveWrong = 0
    private var placed = Set<String>()
    private let childId, activityId: String
    private let contentVersion, level: Int
    private let task: LevelTask
    private let now: () -> Int64
    private let newId: () -> String
    private let emit: (GameEvent) -> Void

    public init(childId: String, activityId: String, contentVersion: Int, level: Int, task: LevelTask,
                now: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
                newId: @escaping () -> String = { UUID().uuidString.lowercased() },
                emit: @escaping (GameEvent) -> Void) {
        self.childId = childId; self.activityId = activityId; self.contentVersion = contentVersion
        self.level = level; self.task = task; self.now = now; self.newId = newId; self.emit = emit
        event(.started, ["level": level])
    }

    public func answer(_ a: Answer) -> Feedback {
        precondition(!finished, "level sudah selesai")
        let correct: Bool
        switch (task, a) {
        case let (.sort(groups), .place(item, group)): correct = groups[item] == group
        case let (.pattern(_, ans), .choose(v)): correct = v == ans
        case let (.count(n, _), .choose(v)): correct = v == String(n)
        default: correct = false
        }
        event(.attempt, ["level": level, "correct": correct ? 1 : 0])
        if correct {
            consecutiveWrong = 0
            if case let .sort(groups) = task, case let .place(item, _) = a {
                placed.insert(item)
                if placed.count < groups.count { return .correct }
            }
            return complete(revealed: false)
        }
        wrongAttempts += 1
        consecutiveWrong += 1
        let hint = min(consecutiveWrong, 3)
        hintsShown += 1
        event(.hint, ["level": level, "hintLevel": hint])
        if hint == 3 {
            switch task {
            case let .sort(groups):
                consecutiveWrong = 0
                if case let .place(item, _) = a { return .revealed(correct: groups[item] ?? "") }
                return .revealed(correct: "")
            case let .pattern(_, ans): _ = complete(revealed: true); return .revealed(correct: ans)
            case let .count(n, _): _ = complete(revealed: true); return .revealed(correct: String(n))
            }
        }
        return .tryAgain(hintLevel: hint)
    }

    public func abandon() {
        if !finished { finished = true; event(.abandoned, ["level": level]) }
    }

    private func complete(revealed: Bool) -> Feedback {
        finished = true
        event(.completed, ["level": level, "wrongAttempts": wrongAttempts, "hints": hintsShown, "revealed": revealed ? 1 : 0])
        return .levelCompleted
    }

    private func event(_ t: EventType, _ p: [String: Int]) {
        emit(GameEvent(id: newId(), childId: childId, activityId: activityId, contentVersion: contentVersion, type: t, payload: p, deviceTsMillis: now()))
    }
}

/// Naik level setelah selesai dengan ≤1 salah tanpa jawaban ditunjukkan; tidak pernah menurunkan level.
public enum LevelPolicy {
    public static func nextLevel(current: Int, maxLevel: Int, wrongAttempts: Int, revealed: Bool) -> Int {
        (!revealed && wrongAttempts <= 1) ? min(current + 1, maxLevel) : current
    }
}

public enum SyncBatcher {
    public static let maxBatch = 500
    public static func nextBatch(_ pending: [GameEvent]) -> [GameEvent] {
        Array(pending.sorted { $0.deviceTsMillis < $1.deviceTsMillis }.prefix(maxBatch))
    }
}

/// Jeda sesi tahan restart aplikasi; padanan SessionTracker Android.
public enum SessionTracker {
    public static let defaultResetMs: Int64 = 5 * 60_000
    public struct State: Equatable {
        public var sessionSec: Int
        public var lastEndMs: Int64
        public init(sessionSec: Int = 0, lastEndMs: Int64 = 0) { self.sessionSec = sessionSec; self.lastEndMs = lastEndMs }
    }
    public static func sessionMinutes(_ s: State, nowMs: Int64, resetAfterMs: Int64 = defaultResetMs) -> Int {
        nowMs - s.lastEndMs >= resetAfterMs ? 0 : s.sessionSec / 60
    }
    public static func record(_ s: State, startMs: Int64, endMs: Int64, resetAfterMs: Int64 = defaultResetMs) -> State {
        let base = startMs - s.lastEndMs >= resetAfterMs ? 0 : s.sessionSec
        return State(sessionSec: base + max(0, Int((endMs - startMs) / 1000)), lastEndMs: endMs)
    }
}
