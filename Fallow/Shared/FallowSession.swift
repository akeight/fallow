import Foundation

/// The record both devices understand.
/// The Mac keeps its own interaction phases. This is the thread that can later sync.
struct FallowSession: Equatable, Codable {
    var projectName: String
    var unresolvedThought: String
    var stuckType: StuckKind
    var distance: DistanceKind
    var status: SessionStatus

    static let demo = FallowSession(
        projectName: "FRAGMENTS",
        unresolvedThought: DemoCopy.unresolved,
        stuckType: .lostPerspective,
        distance: .someDistance,
        status: .resting
    )
}

/// Coarse life of a session across devices. Not the Mac interaction sequence.
enum SessionStatus: String, Equatable, Codable {
    case dormant
    case capturing
    case releasing
    case resting
    case returning
}
