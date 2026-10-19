import Foundation

/// What the interpreter hands back. Structured only: the carried thread and why the person is stuck.
/// Never a rest, a prompt, or advice. AI interprets; `FallowBehaviorResolver` decides.
struct FallowInterpretation: Codable, Equatable, Sendable {
    let distilledThought: String
    let creativeState: CreativeState
    let confidence: Double
    let difficultyDisengaging: Bool

    /// Below this, FALLOW says "Not sure yet" and nothing is preselected. Tune freely.
    static let confidenceThreshold = 0.65

    /// The state to offer as "Suggested", or nil when the guess is too weak to show.
    var suggestedState: CreativeState? {
        confidence >= Self.confidenceThreshold ? creativeState : nil
    }

    /// Keeps a model's answer inside FALLOW's bounds: confidence in 0...1, and a thought that
    /// is never empty and never longer than what the person actually said.
    func validated(against source: String) -> FallowInterpretation {
        let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let thought = distilledThought.trimmingCharacters(in: .whitespacesAndNewlines)
        let keepsSource = thought.isEmpty || thought.count > source.count
        return FallowInterpretation(
            distilledThought: keepsSource ? source : thought,
            creativeState: creativeState,
            confidence: min(1, max(0, confidence.isFinite ? confidence : 0)),
            difficultyDisengaging: difficultyDisengaging
        )
    }
}

/// Distills a capture and classifies the creative state. Callers treat any thrown error as
/// "carry the raw words and let the person choose"; interpretation never blocks the flow.
protocol FallowInterpreting: Sendable {
    func interpret(text: String) async throws -> FallowInterpretation
}

enum InterpretationError: Error {
    case emptyInput
    case badStatus(Int)
    case refused
    case malformedResponse
}

enum FallowInterpreterFactory {
    /// The model when a key is configured; otherwise the on-device stand-in so the prototype still runs.
    static func make(bundle: Bundle = .main) -> any FallowInterpreting {
        if let config = OpenAIInterpreter.Configuration(bundle: bundle) {
            return OpenAIInterpreter(configuration: config)
        }
        return LocalInterpreter()
    }
}

/// Offline stand-in: the extractive distiller plus keyword cues. Used only without an API key.
struct LocalInterpreter: FallowInterpreting {
    func interpret(text: String) async throws -> FallowInterpretation {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw InterpretationError.emptyInput }
        return Self.interpretation(for: text)
    }

    static func interpretation(for text: String) -> FallowInterpretation {
        let lowered = text.lowercased()
        let cues: [(CreativeState, [String])] = [
            (.runningOnEmpty, ["tired", "exhausted", "drained", "no energy", "empty"]),
            (.tooMuchInput, ["too many", "too much", "references", "tried everything", "overwhelm"]),
            (.looping, ["same", "again", "around", "keep ", "over and over", "circling"]),
            (.lostPerspective, ["can’t tell", "can't tell", "whether", "what’s working", "what's working"])
        ]
        let match = cues.first { _, words in words.contains(where: lowered.contains) }?.0
        let stopping = ["should stop", "can’t stop", "can't stop", "one more", "let go"]
        return FallowInterpretation(
            distilledThought: HeuristicDistiller.distill(text) ?? text,
            creativeState: match ?? .lostPerspective,
            confidence: match == nil ? 0 : 0.7,
            difficultyDisengaging: stopping.contains(where: lowered.contains)
        )
    }
}
