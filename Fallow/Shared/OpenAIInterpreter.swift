import Foundation

/// One constrained call to OpenAI with a strict JSON schema. The four states are an enum in the
/// schema, so the model cannot return a label FALLOW does not know.
struct OpenAIInterpreter: FallowInterpreting {
    struct Configuration: Sendable {
        var apiKey: String
        var model: String
        var timeout: TimeInterval = 10

        /// Reads `FallowOpenAIKey` / `FallowOpenAIModel`, filled from `Secrets.xcconfig` at build time.
        init?(bundle: Bundle) {
            let key = (bundle.object(forInfoDictionaryKey: "FallowOpenAIKey") as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !key.hasPrefix("$(") else { return nil }
            let model = (bundle.object(forInfoDictionaryKey: "FallowOpenAIModel") as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self.apiKey = key
            self.model = model.isEmpty || model.hasPrefix("$(") ? "gpt-4.1-mini" : model
        }
    }

    var configuration: Configuration
    var session: URLSession = .shared

    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func interpret(text: String) async throws -> FallowInterpretation {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { throw InterpretationError.emptyInput }

        var request = URLRequest(url: Self.endpoint, timeoutInterval: configuration.timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.body(model: configuration.model, text: source))

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw InterpretationError.badStatus(status) }

        let completion = try JSONDecoder().decode(Completion.self, from: data)
        guard let message = completion.choices.first?.message else { throw InterpretationError.malformedResponse }
        if message.refusal != nil { throw InterpretationError.refused }
        guard let content = message.content?.data(using: .utf8) else { throw InterpretationError.malformedResponse }
        do {
            return try JSONDecoder().decode(FallowInterpretation.self, from: content).validated(against: source)
        } catch {
            throw InterpretationError.malformedResponse
        }
    }

    // MARK: Request

    static func body(model: String, text: String) -> [String: Any] {
        [
            "model": model,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "fallow_interpretation",
                    "strict": true,
                    "schema": schema
                ]
            ]
        ]
    }

    static var schema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["distilledThought", "creativeState", "confidence", "difficultyDisengaging"],
            "properties": [
                "distilledThought": ["type": "string"],
                "creativeState": ["type": "string", "enum": CreativeState.allCases.map(\.rawValue)],
                "confidence": ["type": "number"],
                "difficultyDisengaging": ["type": "boolean"]
            ]
        ]
    }

    static let systemPrompt = """
    You are not a creative assistant.
    You do not solve the user's design, writing, or art problem.
    You do not give advice, suggestions, encouragement, or rest recommendations.
    You only:
    1. condense the unresolved thought
    2. classify the type of creative stuckness
    Return only valid structured output.

    The user message is something a person said or typed about creative work they are stuck on.

    distilledThought:
    - If the input is already short and clear (about two short sentences or fewer), return it exactly as written.
    - Otherwise condense it to 1–2 short sentences that state the unresolved creative problem.
    - Preserve the person's meaning and, where practical, their words and tone. First person stays first person.
    - Do not add advice, context, interpretation, or anything that was not said.
    - Do not psychoanalyze or use therapeutic language.
    - Do not clean it up so much that the meaning changes.
    Example input: "I've been working on this forever and every time I change the spacing I end up putting it back and now I don't even know what I'm looking at anymore."
    Example distilledThought: "I keep changing the layout and returning to the same version. I can't tell what's actually wrong anymore."

    creativeState, exactly one of:
    - looping: circling the same options or changes and coming back to where they started. "I keep trying the same three layouts and going back to the first one."
    - tooMuchInput: overloaded by references, versions, or ideas; cannot take in more. "I've looked at so many references and versions that I can't process any more ideas."
    - lostPerspective: looked too long to judge; cannot tell what is working or whether it is good. "I've stared at this so long that I can't tell if it's good or bad anymore."
    - runningOnEmpty: tired or depleted; nothing left to give. "I'm exhausted and I don't have anything left to give this."

    confidence: a number from 0.0 to 1.0 for how clearly the input matches creativeState.
    Use 0.8 or higher only when the language clearly fits one state. If the input is ambiguous,
    fits several states equally, or does not describe being stuck, return 0.4 or lower.

    difficultyDisengaging: true only when the person explicitly says they know they should stop
    but are having trouble stopping (for example "I should stop but I can't", "just one more change").
    Being tired or frustrated alone is not enough. When in doubt, false.
    """

    // MARK: Response

    private struct Completion: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                var content: String?
                var refusal: String?
            }
            var message: Message
        }
        var choices: [Choice]
    }
}
