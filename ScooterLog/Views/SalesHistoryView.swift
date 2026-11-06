import SwiftUI
import SwiftData
import PDFKit
import UIKit

// MARK: - What goes on the page

/// The service history for a buyer. Deliberately plain: make and model, kilometres, the maintenance
/// that was done and the deadlines. No nickname, no photos.
struct SalesReport {
    struct Row {
        let date: String
        let km: String
        let work: String
        let place: String
        let cost: String
    }
    struct DeadlineRow {
        let title: String
        let last: String
        let next: String
    }

    let title: String
    let subtitle: String
    let maintenanceTitle: String
    let columns: (String, String, String)
    let rows: [Row]
    let emptyText: String
    let deadlineTitle: String
    let deadlineColumns: (String, String)
    let deadlines: [DeadlineRow]
    let footer: String

    static func make(for v: Vehicle, language lang: String, now: Date = Date()) -> SalesReport {
        let loc = Loc.locale(lang)
        let t: (String) -> String = { Loc.tr($0, lang) }

        var name = [v.make, v.model].filter { !$0.isEmpty }.joined(separator: " ")
        if name.isEmpty { name = v.model }
        let subtitle = String(format: t("%@ km al %@"), v.currentOdometer.grouped(loc), now.formatted(
            .dateTime.day().month(.wide).year().locale(loc)))

        let entries = v.maintenance.sorted { $0.date > $1.date }
        let rows = entries.map { e -> Row in
            let names = e.jobs.map { Catalog.displayName(jobKey: $0.jobKey, custom: $0.customName, lang: lang) }
                .filter { !$0.isEmpty }
            var place = e.workshop
            if !e.note.isEmpty { place = place.isEmpty ? e.note : place + " · " + e.note }
            return Row(date: e.date.short(loc),
                       km: e.odometer > 0 ? e.odometer.grouped(loc) + " km" : "",
                       work: names.joined(separator: ", "),
                       place: place,
                       cost: e.total.money(loc))
        }

        let deadlines = DeadlineKind.allCases.compactMap { kind -> DeadlineRow? in
            guard let d = v.deadline(kind) else { return nil }
            let last = d.renewals.max() ?? d.startDate
            return DeadlineRow(title: t(kind.title),
                               last: last.map { $0.monthShortYear(loc) } ?? "–",
                               next: d.dueDate.monthShortYear(loc))
        }

        return SalesReport(
            title: name, subtitle: subtitle,
            maintenanceTitle: t("Manutenzione"),
            columns: (t("Data"), t("Intervento"), t("Costo")),
            rows: rows, emptyText: t("Nessuna manutenzione registrata."),
            deadlineTitle: t("Scadenze"),
            deadlineColumns: (t("Ultima"), t("Prossima")),
            deadlines: deadlines,
            footer: t("Generato con Scoot · dati inseriti dal proprietario"))
    }
}

// MARK: - Drawing the PDF (A4)

enum SalesPDF {
    private static let pageW: CGFloat = 595
    private static let pageH: CGFloat = 842
    private static let margin: CGFloat = 40

    private static let ink = UIColor(red: 0x4A / 255, green: 0x2F / 255, blue: 0x20 / 255, alpha: 1)
    private static let muted = UIColor(red: 0x7A / 255, green: 0x63 / 255, blue: 0x4F / 255, alpha: 1)
    private static let line = UIColor(red: 0x4A / 255, green: 0x2F / 255, blue: 0x20 / 255, alpha: 0.18)

    private static func font(_ size: CGFloat, _ w: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: w)
    }

    private static func attrs(_ f: UIFont, _ c: UIColor, align: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.alignment = align
        p.lineBreakMode = .byWordWrapping
        return [.font: f, .foregroundColor: c, .paragraphStyle: p]
    }

    private static func height(_ s: String, _ a: [NSAttributedString.Key: Any], width: CGFloat) -> CGFloat {
        guard !s.isEmpty else { return 0 }
        let r = (s as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                              options: [.usesLineFragmentOrigin, .usesFontLeading],
                                              attributes: a, context: nil)
        return ceil(r.height)
    }

    static func make(_ r: SalesReport) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let contentW = pageW - margin * 2
        let dateX = margin, dateW: CGFloat = 96
        let workX = margin + 108, workW: CGFloat = 270
        let costW: CGFloat = 90
        let costX = pageW - margin - costW

        return renderer.pdfData { ctx in
            var y: CGFloat = margin

            func newPage() {
                ctx.beginPage()
                y = margin
            }
            func room(_ h: CGFloat) {
                if y + h > pageH - margin - 24 { newPage() }
            }
            func draw(_ s: String, _ a: [NSAttributedString.Key: Any], x: CGFloat, y: CGFloat, w: CGFloat) {
                (s as NSString).draw(with: CGRect(x: x, y: y, width: w, height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: a, context: nil)
            }
            func rule() {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: margin, y: y))
                p.addLine(to: CGPoint(x: pageW - margin, y: y))
                line.setStroke()
                p.lineWidth = 0.5
                p.stroke()
            }

            newPage()

            // Title block
            let titleA = attrs(font(26, .bold), ink)
            draw(r.title, titleA, x: margin, y: y, w: contentW)
            y += height(r.title, titleA, width: contentW) + 4
            let subA = attrs(font(12), muted)
            draw(r.subtitle, subA, x: margin, y: y, w: contentW)
            y += height(r.subtitle, subA, width: contentW) + 24

            // Maintenance
            let headA = attrs(font(14, .bold), ink)
            draw(r.maintenanceTitle, headA, x: margin, y: y, w: contentW)
            y += 24

            let colA = attrs(font(10, .semibold), muted)
            let colR = attrs(font(10, .semibold), muted, align: .right)
            func columnHeader() {
                draw(r.columns.0, colA, x: dateX, y: y, w: dateW)
                draw(r.columns.1, colA, x: workX, y: y, w: workW)
                draw(r.columns.2, colR, x: costX, y: y, w: costW)
                y += 16
                rule()
                y += 8
            }
            columnHeader()

            if r.rows.isEmpty {
                draw(r.emptyText, attrs(font(12), muted), x: margin, y: y, w: contentW)
                y += 24
            }

            let dA = attrs(font(11, .semibold), ink)
            let kA = attrs(font(10), muted)
            let wA = attrs(font(11, .semibold), ink)
            let pA = attrs(font(10), muted)
            let cA = attrs(font(11, .semibold), ink, align: .right)
            for row in r.rows {
                let hL = height(row.date, dA, width: dateW) + (row.km.isEmpty ? 0 : 2 + height(row.km, kA, width: dateW))
                let hM = height(row.work, wA, width: workW) + (row.place.isEmpty ? 0 : 2 + height(row.place, pA, width: workW))
                let h = max(hL, hM, 14)
                if y + h + 12 > pageH - margin - 24 {
                    newPage()
                    columnHeader()
                }
                draw(row.date, dA, x: dateX, y: y, w: dateW)
                if !row.km.isEmpty {
                    draw(row.km, kA, x: dateX, y: y + height(row.date, dA, width: dateW) + 2, w: dateW)
                }
                draw(row.work, wA, x: workX, y: y, w: workW)
                if !row.place.isEmpty {
                    draw(row.place, pA, x: workX, y: y + height(row.work, wA, width: workW) + 2, w: workW)
                }
                draw(row.cost, cA, x: costX, y: y, w: costW)
                y += h + 8
                rule()
                y += 8
            }

            // Deadlines
            if !r.deadlines.isEmpty {
                room(60 + CGFloat(r.deadlines.count) * 24)
                y += 16
                draw(r.deadlineTitle, headA, x: margin, y: y, w: contentW)
                y += 24
                let lastX = margin + 200, nextX = margin + 340, cw: CGFloat = 120
                draw(r.deadlineColumns.0, colA, x: lastX, y: y, w: cw)
                draw(r.deadlineColumns.1, colA, x: nextX, y: y, w: cw)
                y += 16
                rule()
                y += 8
                for d in r.deadlines {
                    draw(d.title, wA, x: margin, y: y, w: 190)
                    draw(d.last, dA, x: lastX, y: y, w: cw)
                    draw(d.next, dA, x: nextX, y: y, w: cw)
                    y += 22
                }
            }

            // Footer on the last page
            let fA = attrs(font(9), muted)
            draw(r.footer, fA, x: margin, y: pageH - margin - 6, w: contentW)
        }
    }
}

// MARK: - The page in the app

private struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.backgroundColor = .clear
        v.document = PDFDocument(data: data)
        return v
    }

    func updateUIView(_ v: PDFView, context: Context) {
        v.document = PDFDocument(data: data)
    }
}

struct SalesHistoryView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @AppStorage("selectedVehicle") private var selectedID = ""
    @AppStorage("language") private var language = "it"
    @State private var chosenID = ""
    @State private var shareItem: PDFShareItem?
    @State private var failed = false

    private var vehicle: Vehicle? {
        if let v = vehicles.first(where: { $0.uid.uuidString == chosenID }) { return v }
        return selectedVehicle(vehicles, id: selectedID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            BackHeader(title: "Storico per la vendita")
                .padding(.horizontal, Space.s2)
                .padding(.top, Space.s2)

            if vehicles.count > 1, let v = vehicle {
                Menu {
                    ForEach(vehicles) { x in
                        Button(x.displayName) { chosenID = x.uid.uuidString }
                    }
                } label: {
                    HStack(spacing: Space.s1) {
                        Text(verbatim: v.displayName).font(AppFont.sans(15, .semibold))
                        Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, Space.s2)
            }

            if let v = vehicle {
                let data = SalesPDF.make(SalesReport.make(for: v, language: language))
                PDFPreview(data: data)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.base, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    .padding(.horizontal, Space.s2)
                PrimaryButton(title: "Condividi PDF") { share(data, for: v) }
                    .padding(.horizontal, Space.s2)
                    .padding(.bottom, Space.s2)
            } else {
                Text("Aggiungi prima un veicolo dal garage.")
                    .font(AppFont.serif(22)).foregroundStyle(Theme.ink)
                    .padding(Space.s2)
                Spacer()
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
        .alert("Creazione del PDF non riuscita", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        }
    }

    private func share(_ data: Data, for v: Vehicle) {
        let day = Date().formatted(.iso8601.year().month().day())
        let base = [v.make, v.model].filter { !$0.isEmpty }.joined(separator: "-")
            .replacingOccurrences(of: " ", with: "-")
        if let url = BackupService.tempFile(named: "storico-\(base.isEmpty ? "veicolo" : base)-\(day).pdf", data: data) {
            Haptics.tick()
            shareItem = PDFShareItem(url: url)
        } else {
            failed = true
        }
    }
}

private struct PDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
