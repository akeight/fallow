import Foundation

enum StuckKind: String, CaseIterable, Identifiable, Equatable, Codable {
    case looping
    case saturated
    case lostPerspective
    case depleted
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .looping: "Looping"
        case .saturated: "Saturated"
        case .lostPerspective: "Lost perspective"
        case .depleted: "Depleted"
        case .unknown: "I don't know"
        }
    }
}

enum DistanceKind: String, CaseIterable, Identifiable, Equatable, Codable {
    case breath
    case someDistance
    case sleepOnIt
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breath: "A breath"
        case .someDistance: "Some distance"
        case .sleepOnIt: "Sleep on it"
        case .unknown: "I don't know yet"
        }
    }
}

/// The Mac session. Hold amount lives in `holding(progress:)`.
enum SessionPhase: Equatable {
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
