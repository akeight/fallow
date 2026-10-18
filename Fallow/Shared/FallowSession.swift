import Foundation

/// The one record both devices understand, and the thing that will later sync.
/// Screens write to it through the transitions below rather than keeping their own copies.
struct FallowSession: Equatable, Codable, Identifiable {
    let id: UUID

    var projectName: String?
    var unresolvedThought: String

    /// Nil until chosen. A low-confidence interpretation also leaves it nil.
    var creativeState: CreativeState?
    /// A modifier on tone, never a separate workflow.
    var difficultyDisengaging: Bool

    var distance: FallowDistance?
    /// Resolved once state and distance are both known. Silence is a valid answer.
    var intervention: FallowIntervention?

    var originDevice: OriginDevice
    var phase: SessionPhase

    var startedAt: Date
    var releasedAt: Date?
    var returnRequestedAt: Date?
    var returnedAt: Date?
    var completedAt: Date?

    var returnOutcome: ReturnOutcome?
    /// What feels different now, when something shifted.
    var returnedThought: String?
    /// What feels unresolved now, when the break changed the shape of the problem instead.
    var reframedThought: String?

    init(
        id: UUID = UUID(),
        projectName: String? = nil,
        unresolvedThought: String = "",
        creativeState: CreativeState? = nil,
        difficultyDisengaging: Bool = false,
        distance: FallowDistance? = nil,
        intervention: FallowIntervention? = nil,
        originDevice: OriginDevice,
        phase: SessionPhase = .capturing,
        startedAt: Date = Date(),
        releasedAt: Date? = nil,
        returnRequestedAt: Date? = nil,
        returnedAt: Date? = nil,
        completedAt: Date? = nil,
        returnOutcome: ReturnOutcome? = nil,
        returnedThought: String? = nil,
        reframedThought: String? = nil
    ) {
        self.id = id
        self.projectName = projectName
        self.unresolvedThought = unresolvedThought
        self.creativeState = creativeState
        self.difficultyDisengaging = difficultyDisengaging
        self.distance = distance
        self.intervention = intervention
        self.originDevice = originDevice
        self.phase = phase
        self.startedAt = startedAt
        self.releasedAt = releasedAt
        self.returnRequestedAt = returnRequestedAt
        self.returnedAt = returnedAt
        self.completedAt = completedAt
        self.returnOutcome = returnOutcome
        self.returnedThought = returnedThought
        self.reframedThought = reframedThought
    }

    /// Resting, or waiting to be picked back up. Home shows these.
    var isAway: Bool {
        switch phase {
        case .resting, .returnRequested, .reflecting: true
        default: false
        }
    }

    /// The latest thing the person said about it, for Past.
    var latestThought: String? {
        reframedThought ?? returnedThought
    }

    var lastTouched: Date {
        completedAt ?? returnedAt ?? releasedAt ?? startedAt
    }
}

// MARK: - Transitions

extension FallowSession {
    mutating func capture(_ thought: String) {
        unresolvedThought = thought
        phase = .interpreting
    }

    mutating func choose(_ state: CreativeState) {
        creativeState = state
        phase = .choosingDistance
        resolveIntervention()
    }

    mutating func setDifficultyDisengaging(_ value: Bool) {
        difficultyDisengaging = value
        resolveIntervention()
    }

    mutating func choose(_ distance: FallowDistance) {
        self.distance = distance
        phase = .readyToRelease
        resolveIntervention()
    }

    mutating func beginRelease() {
        guard phase == .readyToRelease else { return }
        phase = .releasing
    }

    mutating func cancelRelease() {
        guard phase == .releasing else { return }
        phase = .readyToRelease
    }

    /// The hold completed. The thought is resting.
    mutating func markReleased(at date: Date = Date()) {
        resolveIntervention()
        phase = .resting
        releasedAt = date
    }

    mutating func requestReturn(at date: Date = Date()) {
        phase = .returnRequested
        returnRequestedAt = date
    }

    /// Something shifted. The person says what feels different now.
    mutating func recordShift(_ thought: String, at date: Date = Date()) {
        returnOutcome = .somethingShifted
        returnedThought = thought
        returnedAt = date
        phase = .reflecting
    }

    /// The break did not resolve it. Not a failure; the next step stays small.
    mutating func markStillStuck(at date: Date = Date()) {
        returnOutcome = .stillStuck
        returnedAt = date
        phase = .reflecting
    }

    /// One lightweight recapture. State, distance, and setup are kept as they were.
    mutating func recordReframe(_ thought: String) {
        reframedThought = thought
        phase = .reflecting
    }

    /// Back to resting without restarting anything.
    mutating func leaveLonger() {
        phase = .resting
        returnRequestedAt = nil
    }

    mutating func beginReentry() {
        phase = .reentering
    }

    mutating func complete(at date: Date = Date()) {
        phase = .complete
        completedAt = date
    }

    private mutating func resolveIntervention() {
        guard let creativeState, let distance else { return }
        intervention = FallowBehaviorResolver.resolve(
            state: creativeState,
            distance: distance,
            difficultyDisengaging: difficultyDisengaging
        )
    }
}

// MARK: - Supporting types

/// The product lifecycle, shared by both devices. Not the on-screen orb pose; see `OrbPhase`.
enum SessionPhase: String, Equatable, Codable {
    case dormant
    case capturing
    /// The creative state is being suggested or chosen.
    case interpreting
    case choosingDistance
    case readyToRelease
    case releasing
    case resting
    case returnRequested
    case reflecting
    case reentering
    case complete
}

/// Release where you are. Return where the work is.
enum OriginDevice: String, Equatable, Codable {
    case mac
    case iPhone
}

/// The return does not assume the break worked.
enum ReturnOutcome: String, Equatable, Codable {
    case somethingShifted
    case stillStuck
}

/// Why the person is stuck. A suggestion they can change, never a diagnosis.
/// Difficulty disengaging is a modifier on the session; uncertainty is a nil state.
enum CreativeState: String, CaseIterable, Identifiable, Equatable, Codable {
    case looping
    case tooMuchInput
    case lostPerspective
    case runningOnEmpty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .looping: "Looping"
        case .tooMuchInput: "Too much input"
        case .lostPerspective: "Lost perspective"
        case .runningOnEmpty: "Running on empty"
        }
    }

    var meaning: String {
        switch self {
        case .looping: "I keep circling the same thing."
        case .tooMuchInput: "I’ve looked at or tried too much."
        case .lostPerspective: "I can’t tell what’s working anymore."
        case .runningOnEmpty: "I don’t have much left to give this."
        }
    }
}

/// How far away the person needs to get. Distance and rest mode are the same choice.
enum FallowDistance: String, CaseIterable, Identifiable, Equatable, Codable {
    case breath
    case someDistance
    case sleepOnIt
    case openEnded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breath: "A breath"
        case .someDistance: "Some distance"
        case .sleepOnIt: "Sleep on it"
        case .openEnded: "I don't know yet"
        }
    }
}

// MARK: - Demo data

extension FallowSession {
    static let demo = FallowSession(
        projectName: "FRAGMENTS",
        unresolvedThought: DemoCopy.unresolved,
        creativeState: .lostPerspective,
        difficultyDisengaging: false,
        distance: .someDistance,
        intervention: .perceptualPrompt("Look farther away."),
        originDevice: .mac,
        phase: .resting,
        startedAt: Date().addingTimeInterval(-3_600),
        releasedAt: Date().addingTimeInterval(-3_300)
    )

    static let demoFromPhone = FallowSession(
        projectName: "FRAGMENTS",
        unresolvedThought: DemoCopy.phoneUnresolved,
        creativeState: .looping,
        distance: .someDistance,
        intervention: FallowBehaviorResolver.resolve(state: .looping, distance: .someDistance, difficultyDisengaging: false),
        originDevice: .iPhone,
        phase: .resting,
        startedAt: Date().addingTimeInterval(-2_400),
        releasedAt: Date().addingTimeInterval(-2_200)
    )

    static var demoPast: [FallowSession] {
        let day: TimeInterval = 86_400
        return [
            FallowSession(
                projectName: "PORTFOLIO",
                unresolvedThought: "Everything feels over-designed.",
                creativeState: .tooMuchInput,
                distance: .sleepOnIt,
                intervention: .silence,
                originDevice: .mac,
                phase: .complete,
                startedAt: Date().addingTimeInterval(-day * 1.4),
                completedAt: Date().addingTimeInterval(-day),
                returnOutcome: .somethingShifted,
                returnedThought: "Maybe the problem is that I’m showing too much."
            ),
            FallowSession(
                projectName: "FALLOW",
                unresolvedThought: "I can’t tell whether the hierarchy works.",
                creativeState: .lostPerspective,
                distance: .someDistance,
                intervention: .perceptualPrompt("Look farther away. Notice what your eye goes to first."),
                originDevice: .iPhone,
                phase: .complete,
                startedAt: Date().addingTimeInterval(-day * 2.1),
                completedAt: Date().addingTimeInterval(-day * 2),
                returnOutcome: .stillStuck,
                reframedThought: "The title doesn’t need to carry everything."
            )
        ]
    }
}
