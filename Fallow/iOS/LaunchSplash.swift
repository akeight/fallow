import SwiftUI

/// The orb swelling into its own light. At growth 0 it is the orb as placed; at light 1 the light covers the screen.
/// Shared by the launch and the end of a return, so the app opens and closes a session the same way.
struct OrbBloom: View {
    var orb: SessionModel
    var config: OrbTuningConfig
    var placement: OrbPlacement
    /// The orb's drawn size at scale 1, for how far it must grow to pass every corner.
    var diameter: Double
    var growth: Double
    var light: Double
    var arrival: Double = 1
    var attention: Double? = nil
    var holdsShape = false

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * placement.y)
            let size = max(1, diameter * placement.scale)
            let cover: Double = 2.4 * hypot(geo.size.width, geo.size.height) / size
            let settle: Double = 0.92 + 0.08 * arrival
            let swell: Double = 1 + (cover - 1) * growth
            let scale: Double = placement.scale * settle * swell

            ZStack {
                halo(size: size)
                    .position(center)

                OrbView(session: orb, config: config, attention: attention, holdsShape: holdsShape)
                    .allowsHitTesting(false)
                    .scaleEffect(scale)
                    .brightness(0.5 * growth)
                    .blur(radius: 70 * growth)
                    .opacity(arrival)
                    .position(center)

                // Inside the glow: warm white at the orb's heart, dawn toward the edges.
                RadialGradient(
                    colors: [Color(hex: 0xFFFBF3), Color(hex: 0xFBEBD8), Haze.dawn],
                    center: UnitPoint(x: 0.5, y: placement.y),
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * 0.9
                )
                .opacity(light)
                .ignoresSafeArea()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        // Measured like the root's orb layer, so the orb sits exactly where the screen's does.
        .ignoresSafeArea(.keyboard)
        .allowsHitTesting(false)
    }

    /// Soft light behind the orb that blooms as it grows, so the swell reads as glowing, not zooming.
    private func halo(size: Double) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [Color(hex: 0xFFF6E6).opacity(0.85), Haze.dawn.opacity(0.35), .clear],
                center: .center,
                startRadius: 0,
                endRadius: size * 1.1
            ))
            .frame(width: size * 2.2, height: size * 2.2)
            .scaleEffect(1 + 9 * growth)
            .opacity(0.4 * growth)
    }
}

/// Slow to start, then gathering: the orb comes alive and its light takes the screen.
private let bloomCurve = { (duration: Double) in Animation.timingCurve(0.55, 0, 0.75, 0.4, duration: duration) }

/// False when cancelled, so a skipped sequence stops where it is.
private func pause(_ seconds: Double) async -> Bool {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    return !Task.isCancelled
}

/// Opening moment over the "I don't know yet" meadow. The orb arrives where Home keeps it, turns attentive
/// as it does under the Mac pointer, listens with its ripples, then swells into its own light.
/// Home is put in place under the light, which then clears.
/// A tap skips ahead to the light. Under Reduce Motion the orb is shown still and the screen crossfades.
struct LaunchSplash: View {
    var store: PhoneStore
    /// The light covers everything, so Home can appear underneath without being seen arriving.
    var onCovered: () -> Void
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Its own orb, so the attentive and listening poses never touch Home's.
    @State private var orb = SessionModel(interpreter: LocalInterpreter())
    @State private var attention = 0.0
    @State private var arrival = 0.0
    @State private var growth = 0.0
    @State private var light = 0.0
    @State private var clearing = 1.0
    @State private var task: Task<Void, Never>?
    @State private var skipped = false

    var body: some View {
        ZStack {
            Atmosphere(openness: 1, restScene: .openEnded, drifting: true)
                .ignoresSafeArea()

            OrbBloom(
                orb: orb,
                config: store.orbConfig,
                placement: store.orbPlacement,
                diameter: store.orbConfig.idleSize,
                growth: growth,
                light: light,
                arrival: arrival,
                attention: attention,
                // The nudge and the listening change what surrounds the orb, never its outline.
                holdsShape: true
            )

            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture(perform: skip)
        }
        .opacity(clearing)
        .accessibilityElement()
        .accessibilityLabel("FALLOW")
        .accessibilityAddTraits(.isImage)
        .onAppear(perform: start)
        .onDisappear { task?.cancel() }
    }

    private func start() {
        orb.showPreview(.dormant)
        task = Task { @MainActor in
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.4)) { arrival = 1 }
                guard await pause(1.4) else { return }
                onCovered()
                withAnimation(.easeInOut(duration: 0.6)) { clearing = 0 }
                guard await pause(0.6) else { return }
                onFinished()
                return
            }

            withAnimation(.easeOut(duration: 0.6)) { arrival = 1 }
            guard await pause(0.5) else { return }

            // Noticed: the lift and side arc the Mac orb gives under the pointer. The orb eases into it itself.
            attention = 1
            guard await pause(1.2) else { return }

            // Listening: the ripples, with a gentle made-up voice so the light gathers and breathes.
            attention = 0
            orb.showPreview(.capture)
            orb.isListening = true
            let started = Date()
            while Date().timeIntervalSince(started) < 1.6 {
                let t = Date().timeIntervalSince(started)
                orb.voiceLevel = 0.3 + 0.22 * sin(t * 5.2) + 0.1 * sin(t * 11.3)
                guard await pause(1.0 / 30.0) else { return }
            }
            orb.voiceLevel = 0

            await bloom(duration: 1.25)
        }
    }

    private func bloom(duration: Double) async {
        withAnimation(bloomCurve(duration)) { growth = 1 }
        withAnimation(.easeIn(duration: duration * 0.75).delay(duration * 0.25)) { light = 1 }
        guard await pause(duration + 0.2) else { return }
        orb.isListening = false
        onCovered()
        withAnimation(.easeOut(duration: 1.1)) { clearing = 0 }
        guard await pause(1.1) else { return }
        onFinished()
    }

    private func skip() {
        guard !skipped, light < 1 else { return }
        skipped = true
        task?.cancel()
        task = Task { @MainActor in
            arrival = 1
            orb.voiceLevel = 0
            if reduceMotion {
                onCovered()
                withAnimation(.easeInOut(duration: 0.4)) { clearing = 0 }
                guard await pause(0.4) else { return }
                onFinished()
                return
            }
            await bloom(duration: 0.55)
        }
    }
}

/// The end of a return: the orb that was held swells into its light, Home is put in place under it,
/// and the light clears. Under Reduce Motion the light simply fades in and out.
struct ReturnBloom: View {
    var store: PhoneStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Fixed when the bloom starts; Home's placement takes over underneath.
    @State private var placement: OrbPlacement?
    @State private var growth = 0.0
    @State private var light = 0.0
    @State private var clearing = 1.0
    @State private var task: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let placement {
                OrbBloom(
                    orb: store.orb,
                    config: store.orbConfig,
                    placement: placement,
                    diameter: store.orbConfig.returnSize,
                    growth: growth,
                    light: light
                )
            }
            // Nothing underneath can be pressed while the light carries the person home.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
        }
        .opacity(clearing)
        .accessibilityHidden(true)
        .onAppear(perform: start)
        .onDisappear { task?.cancel() }
    }

    private func start() {
        let held = store.orbPlacement
        // Starts at the size the hold left it.
        placement = OrbPlacement(y: held.y, scale: held.scale * 1.12)
        task = Task { @MainActor in
            let duration = reduceMotion ? 0.5 : 1.15
            if !reduceMotion {
                withAnimation(bloomCurve(duration)) { growth = 1 }
            }
            withAnimation(.easeIn(duration: duration * 0.75).delay(reduceMotion ? 0 : duration * 0.25)) { light = 1 }
            guard await pause(duration + 0.2) else { return }
            store.finishReturn()
            // Home and its orb settle under the light before it clears.
            guard await pause(reduceMotion ? 0.35 : 1.0) else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.5 : 1.1)) { clearing = 0 }
            guard await pause(reduceMotion ? 0.5 : 1.1) else { return }
            store.bloomFinished()
        }
    }
}
