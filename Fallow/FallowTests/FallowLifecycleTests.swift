import UserNotifications
import XCTest

// Hostless: the shared sources are compiled into this bundle directly, so no app launches.

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return calendar
}()

private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}

/// A session set up through the real transitions, up to the moment before the hold completes.
private func readySession(
    _ state: CreativeState,
    _ distance: FallowDistance,
    trail: String? = nil,
    origin: OriginDevice = .iPhone
) -> FallowSession {
    var session = FallowSession(originDevice: origin)
    session.captureText("I keep moving the same elements around.")
    session.choose(state)
    session.choose(distance)
    if let trail { session.setTrail(trail) }
    session.beginRelease()
    return session
}

private func released(
    _ state: CreativeState,
    _ distance: FallowDistance,
    trail: String? = nil,
    at time: Date = date(19, 14),
    origin: OriginDevice = .iPhone
) -> FallowSession {
    var session = readySession(state, distance, trail: trail, origin: origin)
    session.markReleased(at: time, calendar: calendar)
    return session
}

// MARK: - Return timing

final class FallowReturnPolicyTests: XCTestCase {
    private func returnDate(_ state: CreativeState, _ distance: FallowDistance, at time: Date) -> Date? {
        FallowReturnPolicy.returnDate(state: state, distance: distance, releasedAt: time, calendar: calendar)
    }

    func testLoopingShortPauseChecksInAfterTwentyMinutes() {
        XCTAssertEqual(returnDate(.looping, .someDistance, at: date(19, 14)), date(19, 14, 20))
    }

    func testCreativeBlockChecksInLater() {
        XCTAssertEqual(returnDate(.lostPerspective, .someDistance, at: date(19, 14)), date(19, 14, 45))
    }

    func testDecisionFatigueGivesItAFewHours() {
        XCTAssertEqual(returnDate(.tooMuchInput, .someDistance, at: date(19, 14)), date(19, 17))
    }

    func testDecisionFatigueThatWouldLandLateWaitsForMorning() {
        XCTAssertEqual(returnDate(.tooMuchInput, .someDistance, at: date(19, 19)), date(20, 9))
        XCTAssertEqual(returnDate(.tooMuchInput, .someDistance, at: date(19, 1)), date(19, 9))
    }

    func testSleepOnItIsNextMorning() {
        XCTAssertEqual(returnDate(.tooMuchInput, .sleepOnIt, at: date(19, 22)), date(20, 9))
        XCTAssertEqual(returnDate(.looping, .sleepOnIt, at: date(19, 10)), date(20, 9))
    }

    func testSleepOnItAfterMidnightIsTheSameMorning() {
        XCTAssertEqual(returnDate(.tooMuchInput, .sleepOnIt, at: date(19, 2)), date(19, 9))
        XCTAssertEqual(returnDate(.tooMuchInput, .sleepOnIt, at: date(19, 4)), date(20, 9))
    }

    func testRunningOnEmptyNeverChecksInTheSameDay() {
        for distance in [FallowDistance.someDistance, .sleepOnIt] {
            XCTAssertEqual(returnDate(.runningOnEmpty, distance, at: date(19, 15)), date(20, 9))
        }
    }

    func testBreathAndOpenEndedStayQuiet() {
        for state in CreativeState.allCases {
            XCTAssertNil(returnDate(state, .breath, at: date(19, 14)))
            XCTAssertNil(returnDate(state, .openEnded, at: date(19, 14)))
        }
    }

    func testReleaseRecordsThePlannedReturn() {
        XCTAssertEqual(released(.looping, .someDistance).returnAt, date(19, 14, 20))
        XCTAssertNil(released(.looping, .breath).returnAt)
    }
}

// MARK: - Copy

final class FallowReturnCopyTests: XCTestCase {
    func testLoopingNudgeUsesTheTrail() throws {
        let session = released(.looping, .someDistance, trail: "Whether the orb should stay the primary navigation")
        let nudge = try XCTUnwrap(FallowReturnPolicy.nudge(for: session, calendar: calendar))
        XCTAssertEqual(nudge.title, "Ready for another look?")
        XCTAssertEqual(nudge.body, "You were circling: Whether the orb should stay the primary navigation. See if it feels different now.")
        XCTAssertEqual(nudge.sessionID, session.id)
        XCTAssertEqual(nudge.fireDate, date(19, 14, 20))
    }

    func testOvernightDecisionNudgeSpeaksOfYesterday() throws {
        let session = released(.tooMuchInput, .sleepOnIt, trail: "Cards, list, or map?", at: date(19, 22))
        let nudge = try XCTUnwrap(FallowReturnPolicy.nudge(for: session, calendar: calendar))
        XCTAssertEqual(nudge.title, "Which one still feels interesting today?")
        XCTAssertEqual(nudge.body, "Yesterday you were deciding: Cards, list, or map?")
    }

    func testNudgeWithoutATrailStaysGeneral() throws {
        let nudge = try XCTUnwrap(FallowReturnPolicy.nudge(for: released(.lostPerspective, .someDistance), calendar: calendar))
        XCTAssertEqual(nudge.title, "Anything different now?")
        XCTAssertFalse(nudge.body.contains("You were"))
    }

    func testReentryLine() {
        let session = released(.tooMuchInput, .sleepOnIt, trail: "Cards, list, or map?", at: date(19, 22))
        XCTAssertEqual(
            FallowReturnPolicy.reentryLine(for: session, now: date(19, 22, 30), calendar: calendar),
            "You stepped away while deciding: Cards, list, or map?"
        )
        XCTAssertEqual(
            FallowReturnPolicy.reentryLine(for: session, now: date(20, 9), calendar: calendar),
            "Yesterday you were deciding: Cards, list, or map?"
        )
        XCTAssertEqual(
            FallowReturnPolicy.reentryLine(for: released(.looping, .someDistance), now: date(19, 15), calendar: calendar),
            DemoCopy.hadSpace
        )
    }

    func testDistanceLabelsFollowTheState() {
        XCTAssertEqual(FallowDistance.someDistance.title(for: .looping), "Take 20 minutes")
        XCTAssertEqual(FallowDistance.someDistance.title(for: .tooMuchInput), "Give it a few hours")
        XCTAssertEqual(FallowDistance.breath.title(for: .looping), FallowDistance.breath.title)
        XCTAssertEqual(FallowDistance.openEnded.title(for: nil), FallowDistance.openEnded.title)
    }
}

// MARK: - Session transitions

final class FallowSessionTransitionTests: XCTestCase {
    func testTrailIsOneOptionalLine() {
        var session = FallowSession(originDevice: .iPhone)
        session.setTrail("  the orb\nas navigation  ")
        XCTAssertEqual(session.trail, "the orb as navigation")
        session.setTrail("   ")
        XCTAssertNil(session.trail)
    }

    func testReleaseTidiesATrailTypedAsIs() {
        var session = readySession(.looping, .someDistance)
        session.trail = "  the orb  "
        session.markReleased(at: date(19, 14), calendar: calendar)
        XCTAssertEqual(session.trail, "the orb")
    }

    func testSkippingReentryRecordsNoOutcome() {
        var session = released(.looping, .someDistance)
        session.requestReturn(at: date(19, 15))
        session.returnedThought = "half typed"
        session.skipReentry(at: date(19, 16))
        XCTAssertEqual(session.phase, .complete)
        XCTAssertNil(session.returnOutcome)
        XCTAssertNil(session.returnedThought)
        XCTAssertEqual(session.returnedAt, date(19, 16))
        XCTAssertEqual(session.completedAt, date(19, 16))
    }

    func testLeavingAReturnLongerDropsThePlannedCheckIn() {
        var session = released(.looping, .someDistance)
        session.requestReturn()
        session.leaveLonger()
        XCTAssertEqual(session.phase, .resting)
        XCTAssertNil(session.returnAt)
    }

    func testLeavingARestLongerKeepsThePlan() {
        var session = released(.looping, .someDistance)
        session.leaveLonger()
        XCTAssertEqual(session.returnAt, date(19, 14, 20))
    }
}

// MARK: - Schedule or cancel

final class FallowReturnActionTests: XCTestCase {
    private func action(_ old: FallowSession?, _ new: FallowSession?) -> FallowReturnAction {
        FallowReturnPolicy.action(from: old, to: new, calendar: calendar)
    }

    func testFreshReleaseSchedules() throws {
        let before = readySession(.looping, .someDistance)
        var after = before
        after.markReleased(at: date(19, 14), calendar: calendar)
        guard case .schedule(let nudge) = action(before, after) else { return XCTFail("expected a schedule") }
        XCTAssertEqual(nudge.fireDate, date(19, 14, 20))
    }

    func testReleaseWithoutHoldAlsoSchedules() {
        var before = FallowSession(originDevice: .iPhone)
        before.captureText("x")
        before.choose(.looping)
        before.choose(.someDistance)
        var after = before
        after.markReleased(at: date(19, 14), calendar: calendar)
        XCTAssertEqual(before.phase, .readyToRelease)
        if case .schedule = action(before, after) {} else { XCTFail("expected a schedule") }
    }

    func testQuietReleaseCancelsAnythingLeftOver() {
        let before = readySession(.looping, .breath)
        var after = before
        after.markReleased(at: date(19, 14), calendar: calendar)
        XCTAssertEqual(action(before, after), .cancel)
    }

    func testReturningCancels() {
        let resting = released(.looping, .someDistance)
        var returning = resting
        returning.requestReturn()
        XCTAssertEqual(action(resting, returning), .cancel)
    }

    func testLeavingLongerDoesNotReschedule() {
        var returning = released(.looping, .someDistance)
        returning.requestReturn()
        var resting = returning
        resting.leaveLonger()
        XCTAssertEqual(action(returning, resting), .none)
    }

    func testSessionArrivingFromTheOtherDeviceNeverSchedules() {
        let remote = released(.looping, .someDistance, origin: .mac)
        XCTAssertEqual(action(nil, remote), .none)
        XCTAssertEqual(action(FallowSession(originDevice: .iPhone, phase: .dormant), remote), .none)
    }

    func testLeavingOrReplacingARestCancels() {
        let resting = released(.looping, .someDistance)
        XCTAssertEqual(action(resting, nil), .cancel)
        XCTAssertEqual(action(resting, FallowSession(originDevice: .mac, phase: .dormant)), .cancel)
    }

    func testEditsWhileRestingChangeNothing() {
        let resting = released(.looping, .someDistance)
        var edited = resting
        edited.unresolvedThought = "changed"
        XCTAssertEqual(action(resting, edited), .none)
    }
}

// MARK: - Notification scheduling

private final class FakeCenter: NotificationCentering {
    var status: UNAuthorizationStatus = .authorized
    var grants = true
    var onRequestAuthorization: (@MainActor () -> Void)?
    private(set) var pending: [String: UNNotificationRequest] = [:]
    private(set) var addCount = 0
    private(set) var removedPending: [String] = []
    private(set) var removedDelivered: [String] = []

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        await onRequestAuthorization?()
        status = grants ? .authorized : .denied
        return grants
    }

    func add(_ request: UNNotificationRequest) async throws {
        addCount += 1
        pending[request.identifier] = request
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPending += identifiers
        identifiers.forEach { pending[$0] = nil }
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDelivered += identifiers
    }
}

private let orbURL = Bundle(for: FallowNotificationTests.self).url(forResource: "NotificationOrb", withExtension: "png")
private let returnID = FallowNotificationService.Kind.returnNudge.identifier

@MainActor
final class FallowNotificationTests: XCTestCase {
    private var center: FakeCenter!
    private var service: FallowNotificationService!

    override func setUp() async throws {
        center = FakeCenter()
        service = FallowNotificationService(center: center, orbURL: orbURL)
    }

    private func nudge(in seconds: TimeInterval, now: Date) -> FallowNudge {
        FallowNudge(sessionID: UUID(), fireDate: now.addingTimeInterval(seconds), title: "Ready for another look?", body: "body")
    }

    func testSchedulesOneReturnNudgeWithTheOrb() async throws {
        let now = Date()
        await service.scheduleReturn(nudge(in: 1_200, now: now), now: now)
        let request = try XCTUnwrap(center.pending[returnID])
        XCTAssertEqual(request.content.title, "Ready for another look?")
        XCTAssertEqual((request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval ?? 0, 1_200, accuracy: 0.5)
        XCTAssertEqual(request.content.userInfo["fallowKind"] as? String, "returnNudge")
        XCTAssertNotNil(orbURL, "the test bundle should carry the orb")
        XCTAssertEqual(request.content.attachments.map(\.identifier), ["orb"])
    }

    func testSchedulingAgainReplacesRatherThanDuplicates() async {
        let now = Date()
        await service.scheduleReturn(nudge(in: 600, now: now), now: now)
        await service.scheduleReturn(nudge(in: 900, now: now), now: now)
        XCTAssertEqual(center.addCount, 2)
        XCTAssertEqual(center.pending.count, 1)
    }

    func testCancelRemovesPendingAndDelivered() async {
        let now = Date()
        await service.scheduleReturn(nudge(in: 600, now: now), now: now)
        service.cancelReturn()
        XCTAssertNil(center.pending[returnID])
        XCTAssertTrue(center.removedDelivered.contains(returnID))
    }

    func testNothingWithoutPermission() async {
        center.status = .denied
        let now = Date()
        await service.scheduleReturn(nudge(in: 600, now: now), now: now)
        XCTAssertEqual(center.addCount, 0)
    }

    func testAsksOnceWhenNeverAsked() async {
        center.status = .notDetermined
        let now = Date()
        await service.scheduleReturn(nudge(in: 600, now: now), now: now)
        XCTAssertNotNil(center.pending[returnID])
    }

    func testATimeAlreadyPassedSendsNothing() async {
        let now = Date()
        await service.scheduleReturn(nudge(in: -5, now: now), now: now)
        XCTAssertEqual(center.addCount, 0)
    }

    func testReturningWhilePermissionIsAskedNeverLandsLate() async {
        center.status = .notDetermined
        center.onRequestAuthorization = { [service] in service?.cancelReturn() }
        let now = Date()
        await service.scheduleReturn(nudge(in: 600, now: now), now: now)
        XCTAssertEqual(center.addCount, 0)
    }

    func testMissingOrbStillDelivers() async throws {
        service = FallowNotificationService(center: center, orbURL: nil)
        let now = Date()
        await service.scheduleReturn(nudge(in: 600, now: now), now: now)
        XCTAssertEqual(try XCTUnwrap(center.pending[returnID]).content.attachments.count, 0)
    }

    func testStaleNudgeWithoutARestingThoughtIsCancelled() {
        service.cancelStaleReturn(restored: nil)
        XCTAssertTrue(center.removedPending.contains(returnID))
    }

    func testRestoredRestKeepsItsNudge() {
        service.cancelStaleReturn(restored: released(.looping, .someDistance))
        XCTAssertTrue(center.removedPending.isEmpty)
    }
}

// MARK: - The Mac session, end to end

@MainActor
final class SessionModelReturnTests: XCTestCase {
    private func waitForAdd(_ center: FakeCenter) async {
        for _ in 0..<100 where center.addCount == 0 {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func releaseOnMac(_ model: SessionModel, _ state: CreativeState, _ distance: FallowDistance) {
        model.tapOrb()
        model.captureText("Every layout ends up as the first one.")
        model.chooseState(state)
        model.chooseDistance(distance)
        model.finishHold()
    }

    func testReleaseSchedulesAndNotificationReturnCancels() async throws {
        let center = FakeCenter()
        let model = SessionModel(notifications: FallowNotificationService(center: center, orbURL: nil), interpreter: LocalInterpreter())
        releaseOnMac(model, .looping, .someDistance)
        await waitForAdd(center)
        XCTAssertNotNil(center.pending[returnID])

        model.openReturn(sessionID: model.current.id)
        XCTAssertEqual(model.phase, .returnDoorway)
        XCTAssertEqual(model.current.phase, .returnRequested)
        XCTAssertNil(center.pending[returnID])
    }

    func testOrbOnlyModelNeverSchedules() async {
        let model = SessionModel(interpreter: LocalInterpreter())
        releaseOnMac(model, .looping, .someDistance)
        XCTAssertEqual(model.current.phase, .resting)
    }

    func testRestArrivingFromThePhoneDoesNotScheduleHere() async {
        let center = FakeCenter()
        let model = SessionModel(notifications: FallowNotificationService(center: center, orbURL: nil), interpreter: LocalInterpreter())
        model.receive(released(.looping, .someDistance, origin: .iPhone))
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.current.phase, .resting)
        XCTAssertEqual(center.addCount, 0)
    }

    func testANudgeForAnotherThoughtOpensNothing() {
        let model = SessionModel(interpreter: LocalInterpreter())
        releaseOnMac(model, .looping, .someDistance)
        model.openReturn(sessionID: UUID())
        XCTAssertEqual(model.phase, .resting)
    }

    func testEscapeFromRestCancels() async {
        let center = FakeCenter()
        let model = SessionModel(notifications: FallowNotificationService(center: center, orbURL: nil), interpreter: LocalInterpreter())
        releaseOnMac(model, .looping, .someDistance)
        await waitForAdd(center)
        model.leave()
        XCTAssertNil(center.pending[returnID])
    }

    func testSkippingFromTheDoorwayRecordsNoOutcome() async throws {
        let model = SessionModel(interpreter: LocalInterpreter())
        model.reentryDuration = 0.2
        releaseOnMac(model, .lostPerspective, .someDistance)
        model.openReturn(sessionID: model.current.id)
        model.skipReentry()
        for _ in 0..<100 where model.phase != .dormant {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(model.phase, .dormant)
        XCTAssertEqual(model.current.phase, .complete)
        XCTAssertNil(model.current.returnOutcome)
        XCTAssertNotNil(model.current.returnedAt)
    }
}

// MARK: - Relaunch

@MainActor
final class FallowPersistenceTests: XCTestCase {
    func testOnlyAwaySessionsAreRestored() {
        XCTAssertNotNil(DemoFallowSyncService.restorable(released(.looping, .someDistance)))
        XCTAssertNil(DemoFallowSyncService.restorable(readySession(.looping, .someDistance)))
        var complete = released(.looping, .someDistance)
        complete.complete()
        XCTAssertNil(DemoFallowSyncService.restorable(complete))
    }

    func testInterruptedReflectionReopensAtWelcomeBack() throws {
        var session = released(.looping, .someDistance)
        session.requestReturn()
        session.recordShift("maybe fewer things")
        let restored = try XCTUnwrap(DemoFallowSyncService.restorable(session))
        XCTAssertEqual(restored.phase, .returnRequested)
    }

    func testRestSurvivesRelaunch() async throws {
        let suite = "fallow.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let session = released(.tooMuchInput, .sleepOnIt, trail: "Cards, list, or map?")
        await DemoFallowSyncService(defaults: defaults).save(session)

        let relaunched = await DemoFallowSyncService(defaults: defaults).loadActiveSession()
        XCTAssertEqual(relaunched, session)

        await DemoFallowSyncService(defaults: defaults).clear()
        let cleared = await DemoFallowSyncService(defaults: defaults).loadActiveSession()
        XCTAssertNil(cleared)
    }
}
