import Foundation

/// Where the active session lives beyond this device. Stores save to it and apply what it reports;
/// views only ever see `FallowSession`.
@MainActor
protocol FallowSyncing: AnyObject {
    var activeSession: FallowSession? { get }
    /// Called when the session changed somewhere other than this device's own `save`.
    var onRemoteChange: ((FallowSession?) -> Void)? { get set }

    func loadActiveSession() async -> FallowSession?
    func save(_ session: FallowSession) async
    func clear() async
}

/// Keeps the active session in memory on this device only. Nothing travels between devices;
/// a matching session is staged on the other device instead.
///
/// Production replaces this with `CloudKitFallowSyncService`, or another backend-backed
/// `FallowSyncing`. `FallowSession` and the views do not change.
///
/// Given `defaults`, the session is also kept on this device so a pause survives the app quitting.
@MainActor
final class DemoFallowSyncService: FallowSyncing {
    private(set) var activeSession: FallowSession?
    var onRemoteChange: ((FallowSession?) -> Void)?

    private let defaults: UserDefaults?
    static let storageKey = "fallow.activeSession"

    init(activeSession: FallowSession? = nil, defaults: UserDefaults? = nil) {
        self.defaults = Self.persistenceAllowed ? defaults : nil
        self.activeSession = activeSession ?? self.defaults.flatMap { Self.load(from: $0) }
    }

    func loadActiveSession() async -> FallowSession? {
        activeSession
    }

    func save(_ session: FallowSession) async {
        activeSession = session
        store(session)
    }

    func clear() async {
        activeSession = nil
        store(nil)
    }

    #if DEBUG
    /// Places a session as if it had arrived from the other device.
    func stage(_ session: FallowSession?) {
        activeSession = session
        store(session)
        onRemoteChange?(session)
    }
    #endif

    /// What a relaunch picks back up: only a thought that is away. Setup is never restored, and a
    /// return that was interrupted mid-reflection opens again at its welcome back.
    nonisolated static func restorable(_ session: FallowSession) -> FallowSession? {
        switch session.phase {
        case .resting, .returnRequested:
            return session
        case .reflecting:
            var reopened = session
            reopened.requestReturn(at: session.returnRequestedAt ?? Date())
            return reopened
        default:
            return nil
        }
    }

    private static func load(from defaults: UserDefaults) -> FallowSession? {
        guard let data = defaults.data(forKey: storageKey),
              let session = try? JSONDecoder().decode(FallowSession.self, from: data) else { return nil }
        return restorable(session)
    }

    private func store(_ session: FallowSession?) {
        guard let defaults else { return }
        if let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: Self.storageKey)
        } else {
            defaults.removeObject(forKey: Self.storageKey)
        }
    }

    /// Screens opened for previews and staged demo takes stay in memory, so they never outlive the launch.
    private static var persistenceAllowed: Bool {
        #if DEBUG
        let defaults = UserDefaults.standard
        return defaults.string(forKey: "fallowScreen") == nil && defaults.string(forKey: "fallowDemo") == nil
        #else
        return true
        #endif
    }
}
