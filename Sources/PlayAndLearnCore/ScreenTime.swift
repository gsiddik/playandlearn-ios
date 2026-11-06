/// Aturan screen time dari server (server authority). Menit sejak tengah malam untuk jendela waktu.
public struct ScreenTimePolicy: Equatable {
    public var dailyMinutes: Int
    public var sessionMinutes: Int
    public var allowedFromMinute: Int?
    public var allowedToMinute: Int?
    public var version: Int

    public init(dailyMinutes: Int, sessionMinutes: Int, allowedFromMinute: Int? = nil,
                allowedToMinute: Int? = nil, version: Int) {
        self.dailyMinutes = dailyMinutes
        self.sessionMinutes = sessionMinutes
        self.allowedFromMinute = allowedFromMinute
        self.allowedToMinute = allowedToMinute
        self.version = version
    }
}

public enum PlayDecision: Equatable {
    case allowed, sessionBreak, dailyLimitReached, outsideAllowedHours
}

public enum ScreenTimeGuard {
    /// Identik secara perilaku dengan ScreenTimeGuard di Android; dievaluasi di perangkat agar jalan offline.
    public static func decide(policy: ScreenTimePolicy, minutesOfDay: Int,
                              playedToday: Int, playedThisSession: Int) -> PlayDecision {
        if let from = policy.allowedFromMinute, let to = policy.allowedToMinute {
            let inside = from <= to ? (minutesOfDay >= from && minutesOfDay < to)
                                    : (minutesOfDay >= from || minutesOfDay < to)
            if !inside { return .outsideAllowedHours }
        }
        if playedToday >= policy.dailyMinutes { return .dailyLimitReached }
        if playedThisSession >= policy.sessionMinutes { return .sessionBreak }
        return .allowed
    }
}
