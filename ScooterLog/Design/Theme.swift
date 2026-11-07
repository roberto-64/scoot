import SwiftUI
import UIKit

// MARK: - Tokens (see DESIGN.md). Never hard-code colours, sizes or radii in views.

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

enum Theme {
    static let bg = Color(hex: 0xF8F1E4)
    static let surface = Color(hex: 0xFFFDF8)
    static let ink = Color(hex: 0x4A2F20)
    static let muted = Color(hex: 0x7A634F)
    /// Derived: ink at 14%.
    static let line = Color(hex: 0x4A2F20).opacity(0.14)
}

enum Radius {
    static let base: CGFloat = 24
}

enum Space {
    static let s1: CGFloat = 8
    static let s2: CGFloat = 16
    static let s3: CGFloat = 24
    static let s4: CGFloat = 32
    static let s5: CGFloat = 40
    static let s6: CGFloat = 48
    static let s7: CGFloat = 56
    static let s8: CGFloat = 64
}

// MARK: - Accent (the one user-changeable token)

struct AccentPreset: Identifiable {
    let id: String
    let name: String
    let hex: UInt32
    var color: Color { Color(hex: hex) }
}

enum Accents {
    static let all: [AccentPreset] = [
        AccentPreset(id: "amber", name: "Ambra", hex: 0xB85C10),
        AccentPreset(id: "terracotta", name: "Terracotta", hex: 0xC8452C),
        AccentPreset(id: "forest", name: "Bosco", hex: 0x2F7A55),
        AccentPreset(id: "sea", name: "Mare", hex: 0x2F6DB5),
        AccentPreset(id: "plum", name: "Prugna", hex: 0x8E3F7B),
        AccentPreset(id: "graphite", name: "Grafite", hex: 0x4F5560)
    ]
    static func preset(_ id: String) -> AccentPreset {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

private struct AppAccentKey: EnvironmentKey {
    static let defaultValue: Color = Color(hex: 0xB85C10)
}

extension EnvironmentValues {
    var appAccent: Color {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
}

// MARK: - Fonts: New York (serif) and SF Pro (sans). Sizes: 11, 13, 15, 17, 22, 28, 32, 40, 56.

enum AppFont {
    static func serif(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Motion and haptics

enum Motion {
    static var enabled: Bool {
        let d = UserDefaults.standard
        let on = d.object(forKey: "animations") == nil ? true : d.bool(forKey: "animations")
        return on && !UIAccessibility.isReduceMotionEnabled
    }
    /// Everyday spring: quick, with a small visible bounce.
    static var spring: Animation? {
        enabled ? .spring(response: 0.32, dampingFraction: 0.68) : nil
    }
    /// Playful spring for pops: new entries, save, toggle knob.
    static var bounce: Animation? {
        enabled ? .spring(response: 0.4, dampingFraction: 0.52) : nil
    }
    /// Settling after a swipe: lively, with a visible overshoot.
    static var snap: Animation? {
        enabled ? .spring(response: 0.36, dampingFraction: 0.6) : nil
    }
    /// The original calm spring. Kept for the tab content fade, which stays as it was.
    static var fade: Animation? {
        enabled ? .spring(response: 0.35, dampingFraction: 0.85) : nil
    }
    /// Switching tabs: the new screen fades in over the old one, calm, no bounce.
    static var tabIn: Animation? {
        enabled ? .easeInOut(duration: 0.3) : nil
    }
    /// The old screen is switched off only after the new one has covered it (no dip in the middle).
    static var tabOut: Animation? {
        enabled ? Animation.linear(duration: 0.01).delay(0.3) : nil
    }
    /// Quick spring for press-down.
    static var press: Animation? {
        enabled ? .spring(response: 0.26, dampingFraction: 0.55) : nil
    }
}

enum Haptics {
    private static var enabled: Bool {
        let d = UserDefaults.standard
        return d.object(forKey: "haptics") == nil ? true : d.bool(forKey: "haptics")
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func tick() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Effects (the only three allowed: header glow, frosted pills, card shadow)

struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Theme.ink.opacity(0.12), radius: 12, x: 0, y: 8)
    }
}

struct HeaderGlow: View {
    @Environment(\.appAccent) private var accent
    var body: some View {
        RadialGradient(colors: [accent.opacity(0.24), accent.opacity(0)],
                       center: .topLeading, startRadius: 0, endRadius: 320)
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
    }
}

/// Stronger two-layer shadow for the floating menu bar and its + button.
struct BarShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Theme.ink.opacity(0.30), radius: 18, x: 0, y: 14)
            .shadow(color: Theme.ink.opacity(0.18), radius: 4, x: 0, y: 3)
    }
}

struct FrostedBackground: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        content
            .background(.ultraThinMaterial, in: shape)
            .background(Theme.surface.opacity(0.55), in: shape)
            .overlay(shape.stroke(Theme.surface.opacity(0.7), lineWidth: 1))
            .modifier(BarShadow())
    }
}

struct ScreenBackground: ViewModifier {
    var glow: Bool
    func body(content: Content) -> some View {
        content.background(alignment: .top) {
            ZStack(alignment: .top) {
                Theme.bg
                if glow { HeaderGlow() }
            }
            .ignoresSafeArea()
        }
    }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: shape)
            .overlay(shape.stroke(Theme.line, lineWidth: 1))
            .modifier(CardShadow())
    }
}

struct EyebrowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFont.sans(13))
            .tracking(0.5)
            .foregroundStyle(Theme.muted)
    }
}

extension View {
    func cardShadow() -> some View { modifier(CardShadow()) }
    func barShadow() -> some View { modifier(BarShadow()) }
    func frosted() -> some View { modifier(FrostedBackground()) }
    func screenBackground(glow: Bool = false) -> some View { modifier(ScreenBackground(glow: glow)) }
    func card(padding: CGFloat = Space.s2) -> some View { modifier(CardStyle(padding: padding)) }
    func eyebrow() -> some View { modifier(EyebrowStyle()) }
}

// MARK: - Components

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Theme.line).frame(height: 1) }
}

struct PrimaryButton: View {
    @Environment(\.appAccent) private var accent
    let title: LocalizedStringKey
    var enabled: Bool = true
    let action: () -> Void
    @State private var pop = false

    var body: some View {
        Button {
            guard !pop else { return }
            withAnimation(Motion.bounce) { pop = true }
            // A short beat so the pop is seen before the screen closes.
            DispatchQueue.main.asyncAfter(deadline: .now() + (Motion.enabled ? 0.16 : 0)) {
                action()
                pop = false
            }
        } label: {
            Text(title)
                .font(AppFont.sans(17, .semibold))
                .foregroundStyle(Theme.surface)
                .frame(maxWidth: .infinity)
                .frame(height: Space.s7)
                .background(accent.opacity(enabled ? 1 : 0.4),
                            in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                .cardShadow()
                .scaleEffect(pop ? 1.05 : 1)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s1) {
                if let s = systemImage { Image(systemName: s) }
                Text(title)
            }
            .font(AppFont.sans(15, .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Space.s2)
            .frame(height: Space.s5)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

/// 40 pt icon square. Filled uses the accent (Garage "+" only).
struct IconSquare: View {
    @Environment(\.appAccent) private var accent
    let systemName: String
    var filled: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(filled ? Theme.surface : Theme.ink)
            .frame(width: Space.s5, height: Space.s5)
            .background(filled ? accent : Theme.surface, in: shape)
            .overlay(shape.stroke(filled ? accent : Theme.line, lineWidth: 1))
            .cardShadow()
    }
}

struct BackHeader: View {
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    var eyebrow: LocalizedStringKey? = nil
    /// True when the form is shown as a sheet: the button closes it and shows a cross.
    var modal: Bool = false

    var body: some View {
        HStack(spacing: Space.s2) {
            Button { dismiss() } label: { IconSquare(systemName: modal ? "xmark" : "chevron.left") }
                .buttonStyle(PressStyle())
            VStack(alignment: .leading, spacing: 0) {
                if let e = eyebrow { Text(e).eyebrow() }
                Text(title).font(AppFont.serif(28)).foregroundStyle(Theme.ink)
            }
            Spacer()
        }
    }
}

struct SectionTitle: View {
    let title: LocalizedStringKey
    var body: some View {
        Text(title).font(AppFont.serif(22)).foregroundStyle(Theme.ink)
    }
}

/// Underlined input with a label above and an optional unit.
struct LineField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var unit: String = ""
    var keyboard: UIKeyboardType = .decimalPad
    var size: CGFloat = 28
    var placeholder: String = "0"

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(label).eyebrow()
            HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                TextField("", text: $text, prompt: Text(LocalizedStringKey(placeholder)).foregroundColor(Theme.muted.opacity(0.5)))
                    .keyboardType(keyboard)
                    .font(AppFont.serif(size))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(LocalizedStringKey(unit)).font(AppFont.sans(15)).foregroundStyle(Theme.muted)
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SegmentOption<T: Hashable>: Identifiable {
    let value: T
    let label: LocalizedStringKey
    var id: String { "\(value)" }
}

struct Segmented<T: Hashable>: View {
    @Environment(\.appAccent) private var accent
    let options: [SegmentOption<T>]
    @Binding var selection: T

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        HStack(spacing: 0) {
            ForEach(options) { o in
                let on = o.value == selection
                Button {
                    withAnimation(Motion.spring) { selection = o.value }
                    Haptics.tick()
                } label: {
                    Text(o.label)
                        .font(AppFont.sans(15, on ? .semibold : .regular))
                        .foregroundStyle(on ? Theme.ink : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: Space.s5)
                        .background(on ? Theme.surface : Color.clear, in: shape)
                        .overlay { if on { shape.stroke(Theme.line, lineWidth: 1) } }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.ink.opacity(0.06), in: shape)
    }
}

struct AccentToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Space.s2) {
            configuration.label
            Spacer(minLength: Space.s2)
            SwitchControl(isOn: configuration.$isOn)
        }
    }
}

/// iOS-style pill switch: large white knob with a soft shadow, light outlined track when off,
/// accent track when on. The knob stretches while pressed.
struct SwitchControl: View {
    @Environment(\.appAccent) private var accent
    @Binding var isOn: Bool
    @State private var pressed = false

    private let trackWidth: CGFloat = Space.s7
    private let trackHeight: CGFloat = Space.s4
    private let inset: CGFloat = 2

    var body: some View {
        let knobHeight = trackHeight - inset * 2
        let knobWidth = pressed ? knobHeight + Space.s1 : knobHeight
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? accent : Theme.bg)
                .overlay(Capsule().stroke(isOn ? accent : Theme.line, lineWidth: 1))
                .frame(width: trackWidth, height: trackHeight)
            Capsule()
                .fill(Theme.surface)
                .frame(width: knobWidth, height: knobHeight)
                .shadow(color: Theme.ink.opacity(0.25), radius: 3, x: 0, y: 2)
                .padding(.horizontal, inset)
        }
        .animation(Motion.bounce, value: isOn)
        .animation(Motion.press, value: pressed)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { pressed = true } }
                .onEnded { _ in
                    pressed = false
                    isOn.toggle()
                    Haptics.tick()
                }
        )
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAction { isOn.toggle() }
    }
}

// MARK: - Deadline status chips

enum DueState {
    case notSet, ok, soon, late

    static func from(days: Int?) -> DueState {
        guard let d = days else { return .notSet }
        if d < 0 { return .late }
        if d <= 30 { return .soon }
        return .ok
    }
}

struct StatusPill: View {
    @Environment(\.appAccent) private var accent
    let state: DueState
    var days: Int? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        Group {
            switch state {
            case .notSet:
                HStack(spacing: 4) { Image(systemName: "plus"); Text("Imposta") }
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Space.s1)
                    .frame(height: Space.s3)
                    .overlay(shape.strokeBorder(Theme.muted, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            case .ok:
                HStack(spacing: 4) { Image(systemName: "checkmark"); Text("OK") }
                    .foregroundStyle(accent)
                    .padding(.horizontal, Space.s1)
                    .frame(height: Space.s3)
                    .overlay(shape.stroke(accent, lineWidth: 1))
            case .soon:
                Text(verbatim: "\(max(days ?? 0, 0)) gg")
                    .foregroundStyle(Theme.surface)
                    .padding(.horizontal, Space.s1)
                    .frame(height: Space.s3)
                    .background(accent, in: shape)
            case .late:
                Text("Scaduta")
                    .foregroundStyle(Theme.surface)
                    .padding(.horizontal, Space.s1)
                    .frame(height: Space.s3)
                    .background(Theme.ink, in: shape)
            }
        }
        .font(AppFont.sans(13, .semibold))
        .fixedSize()
    }
}

/// The custom scooter (solid), tinted like any icon.
struct ScooterIcon: View {
    var width: CGFloat = Space.s4
    var body: some View {
        Image("Scooter")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: width)
    }
}
