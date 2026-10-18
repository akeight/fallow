import Foundation

/// What the orb and the surface around it are showing. Presentation only:
/// where the session is in its life lives in `FallowSession.phase`.
/// Hold amount lives in `holding(progress:)`.
enum OrbPhase: Equatable {
    case dormant
    case capture
    case classifyStuck
    case chooseDistance
    case threshold
    case holding(progress: Double)
    case resting
    case returnDoorway
    case reflecting
    case beforeAfter
    case reentering
}
