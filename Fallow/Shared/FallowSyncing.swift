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
@MainActor
final class DemoFallowSyncService: FallowSyncing {
    private(set) var activeSession: FallowSession?
    var onRemoteChange: ((FallowSession?) -> Void)?

    init(activeSession: FallowSession? = nil) {
        self.activeSession = activeSession
    }

    func loadActiveSession() async -> FallowSession? {
        activeSession
    }

    func save(_ session: FallowSession) async {
        activeSession = session
    }

    func clear() async {
        activeSession = nil
    }

    #if DEBUG
    /// Places a session as if it had arrived from the other device.
    func stage(_ session: FallowSession?) {
        activeSession = session
        onRemoteChange?(session)
    }
    #endif
}
