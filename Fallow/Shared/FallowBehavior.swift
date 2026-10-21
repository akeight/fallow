import Foundation

/// At most one small thing FALLOW offers while a thought rests.
enum FallowIntervention: Equatable, Codable {
    case silence
    case perceptualPrompt(String)
    case fullStop(String)
    case gentleRedirection(String)

    /// The words to show, or nil when the right response is to say nothing.
    var line: String? {
        switch self {
        case .silence: nil
        case .perceptualPrompt(let text), .fullStop(let text), .gentleRedirection(let text): text
        }
    }
}

/// AI classifies. FALLOW decides.
/// Creative state says why the person is stuck; distance says how far away they need to get.
/// Together they choose zero or one resting intervention. Deterministic on purpose.
enum FallowBehaviorResolver {
    static func resolve(
        state: CreativeState,
        distance: FallowDistance,
        difficultyDisengaging: Bool
    ) -> FallowIntervention {
        let base = baseIntervention(state: state, distance: distance)
        guard difficultyDisengaging else { return base }
        switch base {
        case .silence:
            return .fullStop(Line.hold)
        case .fullStop(let text) where state == .runningOnEmpty:
            return .fullStop("\(text) \(Line.hold)")
        default:
            return base
        }
    }

    /// A softer line for people who know they should stop but are having trouble letting go.
    /// Tone only: no guilt, no productivity framing.
    static func reassurance(difficultyDisengaging: Bool) -> String? {
        difficultyDisengaging ? Line.notCarrying : nil
    }

    /// A breath is tiny. Some distance allows one gentle intervention.
    /// Sleep on it leans fully on silence. Open-ended keeps it light and never completes.
    private static func baseIntervention(state: CreativeState, distance: FallowDistance) -> FallowIntervention {
        switch (distance, state) {
        case (.sleepOnIt, _):
            return .silence

        case (.breath, .looping), (.openEnded, .looping):
            return .gentleRedirection(Line.changeAttention)
        case (.breath, .lostPerspective), (.openEnded, .lostPerspective):
            return .perceptualPrompt(Line.lookFarther)
        case (.openEnded, .tooMuchInput):
            return .fullStop(Line.noMoreInput)
        case (.breath, .tooMuchInput), (.breath, .runningOnEmpty), (.openEnded, .runningOnEmpty):
            return .silence

        case (.someDistance, .looping):
            return .gentleRedirection("\(Line.changeAttention) \(Line.sameProblem)")
        case (.someDistance, .tooMuchInput):
            return .fullStop("\(Line.noMoreInput) \(Line.asksNothing)")
        case (.someDistance, .lostPerspective):
            return .perceptualPrompt("\(Line.seeFarther) \(Line.unrelated)")
        case (.someDistance, .runningOnEmpty):
            return .fullStop(Line.leaveIt)
        }
    }

    private enum Line {
        static let changeAttention = "Change what has your attention."
        static let sameProblem = "Notice something that solves the same problem in more than one way."
        static let noMoreInput = "No more input for now."
        static let asksNothing = "Let your attention land somewhere that asks nothing from you."
        static let lookFarther = "Look farther away."
        static let seeFarther = "Go somewhere you can see farther than your screen."
        static let unrelated = "Notice one thing that has nothing to do with the project."
        static let leaveIt = "Leave it here."
        static let hold = "I’ll hold it."
        static let notCarrying = "You don’t need to keep carrying this."
    }
}
