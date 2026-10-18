import Foundation

/// The record both devices understand.
/// The Mac keeps its own interaction phases. This is the thread that can later sync.
struct FallowSession: Equatable, Codable, Identifiable {
    var id = UUID()
    var projectName: String
    var unresolvedThought: String
    var creativeState: CreativeState
    var distance: DistanceKind
    var status: SessionStatus
    var origin: SessionOrigin
    var returnedWith: String?
    var date = Date()

    static let demo = FallowSession(
        projectName: "FRAGMENTS",
        unresolvedThought: DemoCopy.unresolved,
        creativeState: .lostPerspective,
        distance: .someDistance,
        status: .resting,
        origin: .mac
    )

    static let demoFromPhone = FallowSession(
        projectName: "FRAGMENTS",
        unresolvedThought: DemoCopy.phoneUnresolved,
        creativeState: .looping,
        distance: .someDistance,
        status: .resting,
        origin: .phone
    )

    static var demoPast: [FallowSession] {
        let day: TimeInterval = 86_400
        return [
            FallowSession(
                projectName: "PORTFOLIO",
                unresolvedThought: "Everything feels over-designed.",
                creativeState: .overwhelmed,
                distance: .sleepOnIt,
                status: .returning,
                origin: .mac,
                returnedWith: "Maybe the problem is that I’m showing too much.",
                date: Date().addingTimeInterval(-day)
            ),
            FallowSession(
                projectName: "FALLOW",
                unresolvedThought: "I can’t tell whether the hierarchy works.",
                creativeState: .lostPerspective,
                distance: .someDistance,
                status: .returning,
                origin: .phone,
                returnedWith: "The title doesn’t need to carry everything.",
                date: Date().addingTimeInterval(-day * 2)
            )
        ]
    }
}

/// Coarse life of a session across devices. Not the Mac interaction sequence.
enum SessionStatus: String, Equatable, Codable {
    case dormant
    case capturing
    case releasing
    case resting
    case returning
}

enum SessionOrigin: String, Equatable, Codable {
    case mac
    case phone
}

/// How the stuck moment feels. A suggestion the person can change, never a diagnosis.
enum CreativeState: String, CaseIterable, Identifiable, Equatable, Codable {
    case looping
    case fatigue
    case lostPerspective
    case overwhelmed
    case troubleStopping
    case uncertain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .looping: "Looping"
        case .fatigue: "Creative fatigue"
        case .lostPerspective: "Lost perspective"
        case .overwhelmed: "Overwhelmed"
        case .troubleStopping: "I know I should stop"
        case .uncertain: "Uncertain"
        }
    }

    var subtitle: String {
        switch self {
        case .looping: "Stuck in a cycle"
        case .fatigue: "Low energy"
        case .lostPerspective: "Can’t see it clearly"
        case .overwhelmed: "Too many thoughts"
        case .troubleStopping: "But I’m having trouble stopping"
        case .uncertain: "Not sure what’s next"
        }
    }

    /// One gentle line for the resting state. Nil means silence is the right response.
    var restLine: String? {
        switch self {
        case .looping: "Notice something that solves the same problem in more than one way."
        case .fatigue: "Leave it here."
        case .lostPerspective: "Look farther away. Notice what your eye goes to first."
        case .overwhelmed: "Let your attention land somewhere that asks nothing from you."
        case .troubleStopping: "I’ll hold it."
        case .uncertain: nil
        }
    }

    /// Demo interpretation. Stands in for a model until one is connected.
    static func suggested(for thought: String) -> CreativeState {
        let text = thought.lowercased()
        let cues: [(CreativeState, [String])] = [
            (.troubleStopping, ["should stop", "can’t stop", "can't stop", "one more"]),
            (.fatigue, ["tired", "exhausted", "drained", "no energy"]),
            (.overwhelmed, ["too many", "too much", "everything at once", "overwhelm"]),
            (.looping, ["same", "again", "around", "keep ", "over and over"]),
            (.uncertain, ["not sure", "don’t know", "don't know", "what’s next"])
        ]
        for (state, words) in cues where words.contains(where: text.contains) {
            return state
        }
        return .lostPerspective
    }
}
