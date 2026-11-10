import SwiftUI

/// Pop-up over everything (not a sheet): the last two tanks. Tap outside, the X or "Ok" closes it.
struct TankRecapCard: View {
    let recap: TankRecap
    let onClose: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
            card
                .padding(.horizontal, Space.s3)
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Ultimi due pieni").eyebrow()
            HStack(alignment: .firstTextBaseline, spacing: Space.s1) {
                Text(verbatim: String(Int(recap.kmPerL.rounded())))
                    .font(AppFont.serif(56)).foregroundStyle(Theme.ink).monospacedDigit()
                Text(verbatim: "km/L").font(AppFont.sans(20)).foregroundStyle(Theme.muted)
            }
            .padding(.top, Space.s1)
            Text("± \(recap.plusMinus), stima").eyebrow().padding(.top, Space.s1)
            Hairline().padding(.top, Space.s2)
            row("Ultimo pieno", km: recap.lastKm, liters: recap.lastLiters)
            Hairline()
            row("Pieno precedente", km: recap.prevKm, liters: recap.prevLiters)
            Hairline()
            row("In tutto", km: recap.totalKm, liters: recap.totalLiters)
            PrimaryButton(title: "Ok", action: onClose).padding(.top, Space.s2)
        }
        .padding(.horizontal, Space.s3)
        .padding(.top, Space.s3)
        .padding(.bottom, Space.s2)
        .background(Theme.surface, in: shape)
        .overlay(shape.stroke(Theme.line, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) { IconSquare(systemName: "xmark") }
                .buttonStyle(PressStyle())
                .padding(Space.s2)
        }
        .shadow(color: Theme.ink.opacity(0.35), radius: 24, y: 12)
    }

    private func row(_ label: LocalizedStringKey, km: Int, liters: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                Text(verbatim: "\(km.grouped(locale)) km").font(AppFont.serif(17)).foregroundStyle(Theme.ink)
            }
            Spacer()
            Text(verbatim: "\(liters.decimal(2, locale)) L")
                .font(AppFont.serif(17)).foregroundStyle(Theme.ink).monospacedDigit()
        }
        .padding(.vertical, Space.s1)
    }
}
