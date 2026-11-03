import SwiftUI
import SwiftData

extension Notification.Name {
    static let dataChanged = Notification.Name("sl.dataChanged")
}

enum DataSignal {
    static func fire() { NotificationCenter.default.post(name: .dataChanged, object: nil) }
}

func selectedVehicle(_ vs: [Vehicle], id: String) -> Vehicle? {
    vs.first(where: { $0.uid.uuidString == id }) ?? vs.first
}

extension StatRange {
    var raw: String {
        switch self {
        case .m3: return "m3"
        case .m6: return "m6"
        case .y1: return "y1"
        case .all: return "all"
        case .year(let y): return "year\(y)"
        }
    }
    static func from(_ raw: String) -> StatRange {
        switch raw {
        case "m3": return .m3
        case "y1": return .y1
        case "all": return .all
        default: return .m6
        }
    }
}

// MARK: - Range chips (3M, 6M, 1A, Tutto)

struct RangeChips: View {
    @Environment(\.appAccent) private var accent
    @Binding var raw: String

    private let options: [(String, LocalizedStringKey)] = [("m3", "3M"), ("m6", "6M"), ("y1", "1A"), ("all", "Tutto")]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        HStack(spacing: Space.s1) {
            ForEach(options, id: \.0) { o in
                let on = raw == o.0
                Button {
                    withAnimation(Motion.spring) { raw = o.0 }
                    Haptics.tick()
                } label: {
                    Text(o.1)
                        .font(AppFont.sans(15, .semibold))
                        .foregroundStyle(on ? Theme.surface : Theme.muted)
                        .padding(.horizontal, Space.s2)
                        .frame(height: Space.s5)
                        .background(on ? accent : Theme.surface, in: shape)
                        .overlay(shape.stroke(on ? accent : Theme.line, lineWidth: 1))
                        .cardShadow()
                }
                .buttonStyle(PressStyle())
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Vehicle pill (menu) for Stats and Fuel

struct VehiclePill: View {
    let vehicles: [Vehicle]
    @Binding var selection: String   // uid string or "all"

    private var label: String {
        if selection == "all" { return "Tutti" }
        return vehicles.first(where: { $0.uid.uuidString == selection })?.displayName ?? (vehicles.first?.displayName ?? "")
    }

    var body: some View {
        if vehicles.count > 1 {
            Menu {
                Button("Tutti") { selection = "all" }
                ForEach(vehicles) { v in
                    Button(v.displayName) { selection = v.uid.uuidString }
                }
            } label: {
                HStack(spacing: Space.s1) {
                    Text(LocalizedStringKey(label)).font(AppFont.sans(15, .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, Space.s2)
                .frame(height: Space.s5)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
                .cardShadow()
            }
        }
    }
}

func scopedVehicles(_ vs: [Vehicle], selection: String) -> [Vehicle] {
    if selection == "all" { return vs }
    if let v = vs.first(where: { $0.uid.uuidString == selection }) { return [v] }
    if let f = vs.first { return [f] }
    return []
}

// MARK: - History and activity

enum HistoryEntry: Identifiable {
    case fuel(FuelEntry)
    case maint(MaintenanceEntry)
    case expense(ExpenseEntry)
    case reading(OdometerReading)

    var id: PersistentIdentifier {
        switch self {
        case .fuel(let x): return x.persistentModelID
        case .maint(let x): return x.persistentModelID
        case .expense(let x): return x.persistentModelID
        case .reading(let x): return x.persistentModelID
        }
    }
    var date: Date {
        switch self {
        case .fuel(let x): return x.date
        case .maint(let x): return x.date
        case .expense(let x): return x.date
        case .reading(let x): return x.date
        }
    }

    var amount: Double {
        switch self {
        case .fuel(let x): return x.total
        case .maint(let x): return x.total
        case .expense(let x): return x.amount
        case .reading: return 0
        }
    }

    static func all(_ v: Vehicle) -> [HistoryEntry] {
        var out: [HistoryEntry] = []
        for x in v.fuelEntries { out.append(.fuel(x)) }
        for x in v.maintenance { out.append(.maint(x)) }
        for x in v.expenses { out.append(.expense(x)) }
        for x in v.readings { out.append(.reading(x)) }
        return out.sorted { $0.date > $1.date }
    }

    static func recent(_ vs: [Vehicle], limit: Int) -> [HistoryEntry] {
        var out: [HistoryEntry] = []
        for v in vs { out.append(contentsOf: all(v)) }
        return Array(out.sorted { $0.date > $1.date }.prefix(limit))
    }
}

/// Lighter press-down for full-width rows.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension View {
    /// How list rows pop in and slide away.
    func rowTransition() -> some View {
        transition(.asymmetric(
            insertion: .scale(scale: 0.92).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)))
    }
}

/// Swipe left to show an accent-coloured trash block at the right edge, WhatsApp style: the page
/// does not scroll while the row is dragged sideways, a flick opens or closes it, pulling past the
/// end stretches with resistance, and it settles with a bounce. Tapping the block calls `onTrash`
/// (the caller asks for confirmation before deleting).
struct SwipeToDelete<Content: View>: View {
    @Environment(\.appAccent) private var accent
    @Binding var isOpen: Bool
    /// Identifies the row, so the line under it can end where the open row ends (see `SwipeCoordinator`).
    var rowID: PersistentIdentifier? = nil
    var onTrash: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var drag: CGFloat = 0
    @State private var dragging = false
    @State private var armed = false

    /// Bare background between the sliding row and the trash block, so the price never touches it.
    private let gap: CGFloat = SwipeMetrics.gap
    private let reveal: CGFloat = SwipeMetrics.reveal

    /// Resistance when pulling past the end of the trash block.
    private func rubber(_ x: CGFloat) -> CGFloat {
        let c: CGFloat = 0.55, d: CGFloat = 120
        return (c * x * d) / (d + c * x)
    }

    private func position(_ raw: CGFloat) -> CGFloat {
        if raw >= 0 { return 0 }
        if -raw <= reveal { return raw }
        return -(reveal + rubber(-raw - reveal))
    }

    private var offset: CGFloat { position((isOpen ? -reveal : 0) + drag) }

    private func close() {
        withAnimation(Motion.snap) { isOpen = false; drag = 0 }
    }

    var body: some View {
        content()
            .offset(x: offset)
            .background(alignment: .trailing) {
                Button { onTrash() } label: {
                    accent
                        .overlay(alignment: .trailing) {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Theme.surface)
                                .scaleEffect(-offset >= reveal * 0.5 ? 1 : 0.7)
                                .animation(Motion.bounce, value: -offset >= reveal * 0.5)
                                .frame(width: reveal - gap)
                        }
                        .frame(width: max(0, -offset - gap))
                        .clipped()
                }
                .buttonStyle(.plain)
                .allowsHitTesting(isOpen)
            }
            .background(
                SwipeBridge(
                    isOpen: isOpen,
                    onBegan: { dragging = true; armed = isOpen },
                    onChanged: { dx in
                        drag = dx
                        // One tick when the drag crosses the point where the row will stay open.
                        let nowArmed = ((isOpen ? -reveal : 0) + dx) < -reveal * 0.5
                        if nowArmed != armed { armed = nowArmed; Haptics.tick() }
                    },
                    onEnded: { dx, vx in
                        let raw = (isOpen ? -reveal : 0) + dx
                        // Where the row would land if it kept moving for a moment: a flick counts.
                        let projected = raw + vx * 0.2
                        let willOpen = projected < -reveal * 0.5
                        withAnimation(Motion.snap) {
                            isOpen = willOpen
                            drag = 0
                        }
                        dragging = false
                    },
                    onClose: { close() }
                )
            )
            .blocksSwipeBack(isOpen || dragging)
            .onChange(of: isOpen) { _, open in
                guard let id = rowID else { return }
                if open {
                    SwipeCoordinator.shared.openID = id
                } else if SwipeCoordinator.shared.openID == id {
                    SwipeCoordinator.shared.openID = nil
                }
            }
    }
}

/// Sizes shared by the swipe row and the lines between rows.
enum SwipeMetrics {
    static let gap: CGFloat = Space.s2
    static let reveal: CGFloat = Space.s8 + Space.s1 + Space.s2
}

/// Remembers which list row is swiped open. The line under an open row belongs to the next row,
/// so that row shortens its top line to end where the open row ends, matching the line above.
final class SwipeCoordinator: ObservableObject {
    static let shared = SwipeCoordinator()
    @Published var openID: PersistentIdentifier? = nil
}

struct HistoryRow: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @AppStorage("language") private var language = "it"
    @ObservedObject private var swipe = SwipeCoordinator.shared
    let entry: HistoryEntry
    var showVehicle: Bool = false
    /// The entry shown just above this one in the list, if any.
    var previousID: PersistentIdentifier? = nil
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var swipeOpen = false

    private var parts: (symbol: String, title: String, subtitle: String, amount: Double?, vehicle: String) {
        switch entry {
        case .fuel(let f):
            return ("fuelpump", "Rifornimento",
                    "\(f.liters.decimal(2, locale)) L · \(f.pricePerLiter.decimal(3, locale)) €/L\n\(f.date.short(locale)) · \(f.odometer.grouped(locale)) km",
                    f.total, f.vehicle?.displayName ?? "")
        case .maint(let m):
            let names = m.jobs.map { Catalog.displayName(jobKey: $0.jobKey, custom: $0.customName, lang: language) }.joined(separator: ", ")
            return ("wrench.and.screwdriver", "Manutenzione",
                    "\(names)\n\(m.date.short(locale)) · \(m.odometer.grouped(locale)) km",
                    m.total, m.vehicle?.displayName ?? "")
        case .expense(let e):
            let sub = e.title.isEmpty ? e.date.short(locale) : "\(e.title) · \(e.date.short(locale))"
            return (e.category.symbol, e.category.title, sub, e.amount, e.vehicle?.displayName ?? "")
        case .reading(let r):
            return ("gauge", "Contachilometri",
                    "\(r.date.short(locale)) · \(r.odometer.grouped(locale)) km", nil, r.vehicle?.displayName ?? "")
        }
    }

    var body: some View {
        SwipeToDelete(isOpen: $swipeOpen, rowID: entry.id, onTrash: { confirmDelete = true }) {
            Button {
                if swipeOpen {
                    withAnimation(Motion.spring) { swipeOpen = false }
                } else {
                    editing = true
                }
            } label: {
                rowContent
            }
            .buttonStyle(RowPressStyle())
        }
        .contextMenu {
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
        .confirmationDialog("Eliminare questa registrazione?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina registrazione", role: .destructive) { delete() }
            Button("Annulla", role: .cancel) { withAnimation(Motion.spring) { swipeOpen = false } }
        }
        .sheet(isPresented: $editing) {
            EntryEditSheet(entry: entry)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Radius.base)
                .presentationBackground(Theme.bg)
        }
    }

    private var rowContent: some View {
        let p = parts
        return HStack(alignment: .top, spacing: Space.s2) {
            Image(systemName: p.symbol)
                .font(.system(size: 20))
                .foregroundStyle(Theme.muted)
                .frame(width: Space.s3)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(p.title)).font(AppFont.serif(17)).foregroundStyle(Theme.ink)
                if showVehicle && !p.vehicle.isEmpty {
                    Text(verbatim: p.vehicle).font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                }
                Text(verbatim: p.subtitle).font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: Space.s1)
            if let a = p.amount {
                Text(a.money(locale)).font(AppFont.sans(15, .semibold)).foregroundStyle(Theme.ink).monospacedDigit()
            }
        }
        .padding(.vertical, Space.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .topLeading) {
            // When the row above is swiped open, this line (the one under that row) stops where the
            // open row stops, like the line above that row does.
            let shortened = previousID != nil && swipe.openID == previousID
            Hairline()
                .padding(.trailing, shortened ? SwipeMetrics.reveal : 0)
                .animation(Motion.snap, value: shortened)
        }
    }

    private func delete() {
        withAnimation(Motion.bounce) {
            swipeOpen = false
            switch entry {
            case .fuel(let x): context.delete(x)
            case .maint(let x): context.delete(x)
            case .expense(let x): context.delete(x)
            case .reading(let x): context.delete(x)
            }
            try? context.save()
        }
        DataSignal.fire()
    }
}

// MARK: - Chart placeholder (dashed outline)

struct ChartPlaceholder: View {
    let title: LocalizedStringKey
    let hint: LocalizedStringKey

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        VStack(spacing: Space.s2) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 40))
                p.addLine(to: CGPoint(x: 60, y: 24))
                p.addLine(to: CGPoint(x: 120, y: 44))
                p.addLine(to: CGPoint(x: 180, y: 16))
                p.addLine(to: CGPoint(x: 240, y: 32))
            }
            .stroke(Theme.muted.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 6]))
            .frame(width: 240, height: 56)
            Text(title).font(AppFont.serif(17)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Text(hint).eyebrow().multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.s4)
        .overlay(shape.strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
    }
}

// MARK: - Deadline cells (Garage card and vehicle page)

struct DeadlineCells: View {
    let vehicle: Vehicle
    var onTap: (DeadlineKind) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(DeadlineKind.allCases.enumerated()), id: \.offset) { i, kind in
                let d = vehicle.deadline(kind)
                let days = d.map { daysBetween(Date(), $0.dueDate) }
                Button { onTap(kind) } label: {
                    VStack(alignment: .leading, spacing: Space.s1) {
                        Text(LocalizedStringKey(kind.short)).eyebrow()
                        StatusPill(state: DueState.from(days: days), days: days)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.s2)
                    .padding(.vertical, Space.s2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                if i < DeadlineKind.allCases.count - 1 {
                    Rectangle().fill(Theme.line).frame(width: 1)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
