import Foundation
import NaturalLanguage

/// Turns a spoken note into the one thread FALLOW carries. Nil means "carry the note as it is".
///
/// This is one half of a future model's structured output: `distilledThought` comes here,
/// while `creativeState`, `confidence`, and `difficultyDisengaging` go to `FallowInterpretation`.
/// Summarizing what someone is carrying and reading why they are stuck stay separate.
protocol ThoughtDistilling: Sendable {
    func distill(_ raw: String) async -> String?
}

/// Prototype distiller until a model is connected. Extractive only: it keeps the person's own words,
/// drops filler, and never adds advice, interpretation, or anything that was not said.
struct HeuristicDistiller: ThoughtDistilling {
    /// Roughly one or two short sentences. Tunable; nothing in the interface depends on it.
    var wordBudget = 28

    func distill(_ raw: String) async -> String? {
        Self.distill(raw, wordBudget: wordBudget)
    }

    static func distill(_ raw: String, wordBudget: Int = 28) -> String? {
        let text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !text.isEmpty else { return nil }

        let spoken = sentences(in: text)
        // Already short and clear: use it exactly as said.
        if spoken.count <= 2, wordCount(text) <= wordBudget {
            return text
        }

        // Speakers usually land on the actual problem at the end, so read backwards.
        let units = spoken
            .map(removeFiller)
            .flatMap { wordCount($0) > wordBudget / 2 ? clauses(in: $0) : [$0] }
            .filter { wordCount($0) > 2 }

        var picked: [String] = []
        var words = 0
        for unit in units.reversed() {
            let count = wordCount(unit)
            if picked.count == 2 || (!picked.isEmpty && words + count > wordBudget) { break }
            picked.insert(unit, at: 0)
            words += count
        }
        if picked.count == 1, words > wordBudget * 2 {
            picked = [picked[0].split(separator: " ").suffix(wordBudget).joined(separator: " ")]
        }

        let result = picked.map(finish).joined(separator: " ")
        return result.isEmpty ? nil : result
    }

    // MARK: Pieces

    private static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        let found = tokenizer.tokens(for: text.startIndex..<text.endIndex).map {
            text[$0].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return found.isEmpty ? [text] : found
    }

    /// Splits run-on speech at the joins people use when they keep going.
    private static func clauses(in sentence: String) -> [String] {
        let joins: [(String, String)] = [
            (", and ", "|"), (", then ", "|"), (", but ", "|"), (", so ", "|"),
            (" and now ", "|now "), (" and then ", "|then "),
            (" and I ", "|I "), (" but I ", "|I "), (" so I ", "|I ")
        ]
        var marked = sentence
        for (join, mark) in joins {
            marked = marked.replacingOccurrences(of: join, with: mark, options: .caseInsensitive)
        }
        return marked.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func removeFiller(_ text: String) -> String {
        let pattern = #"(?i)\b(um+|uh+|you know)\b,?\s*"#
        let stripped = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return stripped.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func finish(_ clause: String) -> String {
        var text = clause.trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
        for lead in ["and ", "so ", "but ", "then "] where text.lowercased().hasPrefix(lead) {
            text = String(text.dropFirst(lead.count))
        }
        guard let first = text.first else { return "" }
        return first.uppercased() + text.dropFirst() + "."
    }

    private static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
