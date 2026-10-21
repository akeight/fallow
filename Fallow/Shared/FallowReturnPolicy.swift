import Foundation

/// The one check-in FALLOW may send for a resting thought.
struct FallowNudge: Equatable {
    let sessionID: UUID
    let fireDate: Date
    let title: String
    let body: String
}

/// What a change to the session means for its check-in.
enum FallowReturnAction: Equatable {
    case schedule(FallowNudge)
    case cancel
    case none
}

/// Why the person stepped away decides how and when FALLOW brings them back. Often the answer is
/// not at all: a breath, an open-ended rest, or a depleted evening gets no same-day nudge.
/// Deterministic on purpose, like `FallowBehaviorResolver`.
enum FallowReturnPolicy {
    static let morningHour = 9
    /// A short rest that would land at or after this hour waits for the morning instead.
    static let lateHour = 21
    /// Released before this hour, "the morning" is the same calendar day.
    static let overnightCutoffHour = 4

    static func returnDate(
        state: CreativeState,
        distance: FallowDistance,
        releasedAt: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let planned = plannedDate(state: state, distance: distance, releasedAt: releasedAt, calendar: calendar)
        #if DEBUG
        // `-fallowReturnDelay 10` brings any planned check-in forward for rehearsal. Silence stays silence.
        let override = UserDefaults.standard.double(forKey: "fallowReturnDelay")
        if planned != nil, override > 0 { return releasedAt.addingTimeInterval(override) }
        #endif
        return planned
    }

    private static func plannedDate(
        state: CreativeState,
        distance: FallowDistance,
        releasedAt: Date,
        calendar: Calendar
    ) -> Date? {
        switch distance {
        case .breath, .openEnded:
            return nil
        case .sleepOnIt:
            return nextMorning(after: releasedAt, calendar: calendar)
        case .someDistance:
            switch state {
            case .looping:
                return releasedAt.addingTimeInterval(20 * 60)
            case .lostPerspective:
                return releasedAt.addingTimeInterval(45 * 60)
            case .tooMuchInput:
                let later = releasedAt.addingTimeInterval(3 * 3_600)
                return isRestingHours(later, releasedAt: releasedAt, calendar: calendar)
                    ? nextMorning(after: releasedAt, calendar: calendar)
                    : later
            case .runningOnEmpty:
                return nextMorning(after: releasedAt, calendar: calendar)
            }
        }
    }

    /// The check-in for a resting session, or nil when FALLOW should stay quiet.
    static func nudge(for session: FallowSession, calendar: Calendar = .current) -> FallowNudge? {
        guard let fireDate = session.returnAt, let state = session.creativeState else { return nil }
        let releasedAt = session.releasedAt ?? fireDate
        let lead = lead(state: state, releasedAt: releasedAt, now: fireDate, calendar: calendar)
        let trail = session.trail.map(sentence)
        let overnight = !calendar.isDate(releasedAt, inSameDayAs: fireDate)

        let title: String
        let body: String
        switch state {
        case .looping:
            title = "Ready for another look?"
            body = trail.map { "\(lead): \($0) See if it feels different now." } ?? "See if it feels different now."
        case .tooMuchInput:
            title = overnight ? "Which one still feels interesting today?" : "Which one still feels interesting?"
            body = trail.map { "\(lead): \($0)" } ?? "\(overnight ? "Yesterday" : "Earlier") you had a few directions."
        case .lostPerspective:
            title = "Anything different now?"
            body = trail.map { "Don’t solve it yet. \(lead): \($0) Notice whether it feels different from a distance." }
                ?? "Don’t solve it yet. Notice whether the problem feels different from a distance."
        case .runningOnEmpty:
            title = "It’s still here."
            body = trail.map { "\(lead): \($0) No need to pick it up until you want to." }
                ?? "No need to pick it up until you want to."
        }
        return FallowNudge(sessionID: session.id, fireDate: fireDate, title: title, body: body)
    }

    /// The first line of re-entry: what the person stepped away from, in their own words when they left a trail.
    static func reentryLine(for session: FallowSession, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let state = session.creativeState, let releasedAt = session.releasedAt else { return DemoCopy.hadSpace }
        let sameDay = calendar.isDate(releasedAt, inSameDayAs: now)
        if let trail = session.trail.map(sentence) {
            if sameDay { return "You stepped away while \(verb(state)): \(trail)" }
            return "\(lead(state: state, releasedAt: releasedAt, now: now, calendar: calendar)): \(trail)"
        }
        if state == .tooMuchInput, !sameDay {
            return "\(calendar.isDateInYesterday(releasedAt) ? "Yesterday" : "Last time") you had a few directions."
        }
        return DemoCopy.hadSpace
    }

    /// Schedules only on a fresh release on this device: a session that arrives already resting from
    /// elsewhere never does. Any way out of rest cancels; leaving a return longer does not reschedule.
    static func action(from old: FallowSession?, to new: FallowSession?, calendar: Calendar = .current) -> FallowReturnAction {
        if let old, let new, old.id == new.id, new.phase == .resting,
           old.phase == .readyToRelease || old.phase == .releasing {
            guard let nudge = nudge(for: new, calendar: calendar) else { return .cancel }
            return .schedule(nudge)
        }
        guard let old, old.phase == .resting else { return .none }
        if let new, new.id == old.id, new.phase == .resting { return .none }
        return .cancel
    }

    // MARK: Private

    private static func verb(_ state: CreativeState) -> String {
        switch state {
        case .looping: "circling"
        case .tooMuchInput: "deciding"
        case .lostPerspective: "trying to see"
        case .runningOnEmpty: "working through"
        }
    }

    private static func lead(state: CreativeState, releasedAt: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(releasedAt, inSameDayAs: now) { return "You were \(verb(state))" }
        let when = calendar.isDate(releasedAt, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
            ? "Yesterday" : "Last time"
        return "\(when) you were \(verb(state))"
    }

    /// The trail as typed, closed with a period so the line after it reads as its own sentence.
    private static func sentence(_ trail: String) -> String {
        guard let last = trail.last, !".?!…".contains(last) else { return trail }
        return trail + "."
    }

    private static func nextMorning(after date: Date, calendar: Calendar) -> Date {
        let hour = calendar.component(.hour, from: date)
        let day = hour < overnightCutoffHour ? date : calendar.date(byAdding: .day, value: 1, to: date) ?? date
        return calendar.date(bySettingHour: morningHour, minute: 0, second: 0, of: day) ?? date
    }

    private static func isRestingHours(_ date: Date, releasedAt: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= lateHour || hour < morningHour || !calendar.isDate(date, inSameDayAs: releasedAt)
    }
}
