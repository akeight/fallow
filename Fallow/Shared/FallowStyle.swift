import SwiftUI

/// The action color: the frosted sunset haze from the Mac landscape, so actions
/// read as a piece of that glass rather than paint. Stone carries it; dawn is the glow.
enum Haze {
    static let stone = Color(hex: 0xD9D3D0)
    static let dawn = Color(hex: 0xF2D6BD)
    static let sand = Color(hex: 0xBFA393)
    static let dusk = Color(hex: 0xA69485)
}

extension View {
    /// Frosted stone with a faint sunset along the top edge. `strength` softens it for selections.
    func hazeSurface<S: InsettableShape>(_ shape: S, strength: Double = 1) -> some View {
        background {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(Haze.stone.opacity(0.88 * strength)))
                .overlay(shape.fill(LinearGradient(
                    colors: [Haze.dawn.opacity(0.55 * strength), Haze.dawn.opacity(0)],
                    startPoint: .top, endPoint: .center)))
        }
        .overlay(shape.strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
        .shadow(color: Haze.dusk.opacity(0.22 * strength), radius: 14, y: 5)
    }
}

extension Theme {
    /// Secondary text over the garden on Home and Past, which thickens to 0.5 toward the bottom.
    static let muteOnScene = Color(hex: 0x37352F)
    /// Secondary text in the return, where the garden thickens to 0.6 toward the bottom.
    static let muteOnDense = Color(hex: 0x2E2C28)
    /// Primary and secondary text over the deepened garden in Pause and the return.
    /// Both keep 4.5:1 over the brightest bokeh under `Atmosphere`'s scrim.
    static let inkOnDeep = Color(hex: 0xF4F1EA)
    static let muteOnDeep = Color(hex: 0xE3DCCF)
}

extension FallowDistance {
    /// The open scene shown while resting, shared by the phone and the Mac veil.
    var sceneName: String {
        switch self {
        case .breath: "SceneWall"
        case .someDistance: "SceneValley"
        case .sleepOnIt: "SceneWater"
        case .openEnded: "SceneMeadow"
        }
    }
}

/// A small give under the finger. Nothing bounces.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FallowType.button)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .hazeSurface(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// A secondary text link, underlined so it reads as tappable.
struct QuietButton: View {
    var title: String
    var color: Color = Theme.mute
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FallowType.quietButton)
                .underline()
                .foregroundStyle(color)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Inputs and cards. System Liquid Glass where available, following the color scheme;
/// `lit` warms it while listening or selected.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 20
    var lit = false

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        #if os(macOS)
        // Over an arbitrary desk. System glass flips dark over dark windows, so the Mac keeps
        // a behind-window frost pinned to the light appearance, which holds ink at 4.5:1.
        content
            .background {
                ZStack {
                    FrostedGlass(cornerRadius: radius)
                    shape.fill(LinearGradient(
                        colors: lit
                            ? [Haze.dawn.opacity(0.75), Haze.dawn.opacity(0.5)]
                            : [Theme.paper.opacity(0.62), Theme.paper.opacity(0.42)],
                        startPoint: .top, endPoint: .bottom))
                }
            }
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1))
            .shadow(color: Color(hex: 0x5C4A32).opacity(0.12), radius: 14, y: 6)
        #else
        if #available(iOS 26, *) {
            content.glassEffect(lit ? .regular.tint(Haze.dawn.opacity(0.3)) : .regular, in: shape)
        } else {
            let dark = scheme == .dark
            content
                .background {
                    shape
                        .fill(.ultraThinMaterial)
                        .overlay(shape.fill(lit ? Haze.dawn.opacity(dark ? 0.2 : 0.5) : Color.white.opacity(dark ? 0.06 : 0.5)))
                }
                .overlay(shape.strokeBorder(Color.white.opacity(dark ? 0.18 : 0.85), lineWidth: 1))
        }
        #endif
    }
}

extension View {
    func glass(radius: CGFloat = 20, lit: Bool = false) -> some View {
        modifier(GlassSurface(radius: radius, lit: lit))
    }
}

private struct BlurAmount: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

extension AnyTransition {
    /// Text arrives from slightly below and out of focus, and leaves upward into softness.
    static var fallowText: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: 10))
                .combined(with: .modifier(active: BlurAmount(radius: 6), identity: BlurAmount(radius: 0))),
            removal: .opacity
                .combined(with: .offset(y: -6))
                .combined(with: .modifier(active: BlurAmount(radius: 8), identity: BlurAmount(radius: 0)))
        )
    }
}

/// The unresolved thought, in the person's own words.
struct ThoughtText: View {
    var text: String
    var color: Color = Theme.ink
    var alignment: TextAlignment = .leading
    var size: CGFloat = 16

    var body: some View {
        Text("“\(text)”")
            .font(FallowType.words(size))
            .foregroundStyle(color)
            .lineSpacing(size < 16 ? 4 : 5)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One answer in a short list. Tapping it is the answer; there is no separate Continue.
struct ChoiceRow: View {
    var title: String
    var subtitle: String? = nil
    var note: String? = nil
    var selected: Bool
    var action: () -> Void

    /// Dark glass over the deepened garden, light glass in the return.
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let deep = scheme == .dark
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(selected ? Haze.sand : Theme.rim)
                    .frame(width: 8, height: 8)
                    .shadow(color: Haze.dawn.opacity(selected ? 0.9 : 0), radius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: selected ? .semibold : .regular))
                        .foregroundStyle(deep ? Theme.inkOnDeep : Theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(FallowType.caption)
                            .foregroundStyle(deep ? Theme.muteOnDeep : Theme.muteOnDense)
                    }
                }
                Spacer(minLength: 0)
                if let note {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(deep ? Theme.muteOnDeep : Theme.muteOnDense)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: subtitle == nil ? 52 : 58)
            .glass(radius: 16, lit: selected)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(.easeInOut(duration: 0.35), value: selected)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One place to put a thought: type into it, or speak it. The arrow appears once there is something to send.
struct ThoughtComposer: View {
    @Binding var text: String
    var placeholder: String
    var isRecording: Bool
    var isGathering = false
    /// Light type and dark glass over the deepened garden.
    var deep = false
    /// Off when a separate button below confirms the thought.
    var showsSend = true
    var onMic: () -> Void
    var onSubmit: () -> Void

    @FocusState private var focused: Bool

    private var ink: Color { deep ? Theme.inkOnDeep : Theme.ink }
    private var secondary: Color { deep ? Theme.muteOnDeep : Theme.muteOnDense }
    private var busy: Bool { isRecording || isGathering }
    private var canSend: Bool {
        !busy && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Group {
                if busy {
                    Text(isRecording ? DemoCopy.listening : DemoCopy.gathering)
                        .foregroundStyle(ink)
                        .transition(.opacity)
                } else {
                    field
                }
            }
            .font(FallowType.secondary)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)

            circleButton(
                symbol: isRecording ? "stop.fill" : "mic",
                filled: isRecording,
                label: isRecording ? "Stop listening" : "Speak it"
            ) {
                focused = false
                onMic()
            }
            .disabled(isGathering)
            .accessibilityValue(isRecording ? "Recording" : "")

            if canSend && showsSend {
                circleButton(symbol: "arrow.up", filled: true, label: "Send") {
                    focused = false
                    onSubmit()
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .frame(minHeight: 52)
        .glass(radius: 26, lit: isRecording)
        .animation(.easeInOut(duration: 0.25), value: canSend)
        .animation(.easeInOut(duration: 0.25), value: busy)
    }

    private var field: some View {
        let field = TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(secondary), axis: .vertical)
            .lineLimit(1...5)
            .foregroundStyle(ink)
            .tint(ink)
            .focused($focused)
            .accessibilityLabel(placeholder)
        #if os(macOS)
        // Return sends on the Mac; Option-Return adds a line.
        return field
            .textFieldStyle(.plain)
            .onSubmit { if canSend { onSubmit() } }
        #else
        return field
        #endif
    }

    private func circleButton(symbol: String, filled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: filled ? 13 : 16, weight: .semibold))
                .foregroundStyle(filled && !deep ? Theme.canvas : Theme.ink)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 38, height: 38)
                .background(Circle().fill(filled ? ink.opacity(0.85) : Haze.dawn.opacity(0.7)))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}
