import Foundation

/// The one session both devices stage for the presentation. Edit these values before filming;
/// the Mac and the iPhone read the same fields, so they cannot disagree.
/// Keep `unresolvedThought` identical to the line spoken on the Mac.
enum DemoSessionFactory {
    static let projectName: String? = "FRAGMENTS"
    static let unresolvedThought = DemoCopy.unresolved
    static let rawTranscript: String? = nil
    static let creativeState: CreativeState = .lostPerspective
    static let difficultyDisengaging = false
    static let distance: FallowDistance = .someDistance
    static let originDevice: OriginDevice = .mac

    private static let id = UUID(uuidString: "F4110000-0000-4000-8000-000000000001")!

    /// Released on the Mac a little while ago, and resting.
    static var fragments: FallowSession {
        let now = Date()
        var session = FallowSession(
            id: id,
            projectName: projectName,
            unresolvedThought: unresolvedThought,
            rawTranscript: rawTranscript,
            captureMethod: rawTranscript == nil ? .text : .voice,
            difficultyDisengaging: difficultyDisengaging,
            originDevice: originDevice,
            phase: .interpreting,
            startedAt: now.addingTimeInterval(-1_500)
        )
        session.choose(creativeState)
        session.choose(distance)
        session.markReleased(at: now.addingTimeInterval(-1_200))
        return session
    }
}
