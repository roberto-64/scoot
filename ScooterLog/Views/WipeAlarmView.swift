import SwiftUI

/// What the missing-data alarm knows: the newest automatic backup, if one was found.
struct WipeAlarm: Identifiable {
    let id = UUID()
    let knownCount: Int
    let found: AutoBackup.Found?
}

/// Pop-up over everything when Scoot opens empty but had data the last time it was used.
struct WipeAlarmCard: View {
    let alarm: WipeAlarm
    let onRestore: (AutoBackup.Found) -> Void
    let onPickFile: () -> Void
    let onLater: () -> Void
    @Environment(\.appAccent) private var accent

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.5).ignoresSafeArea()
            card.padding(.horizontal, Space.s3)
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.base, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: Space.s6, height: Space.s6)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("I tuoi dati sembrano spariti")
                .font(AppFont.serif(22)).foregroundStyle(Theme.ink)
                .padding(.top, Space.s2)
            Text("L’ultima volta Scoot aveva \(alarm.knownCount) registrazioni. Ora è vuoto.")
                .font(AppFont.sans(15)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s1)
            Hairline().padding(.top, Space.s2)
            if let f = alarm.found {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Backup automatico più recente").font(AppFont.sans(13)).foregroundStyle(Theme.muted)
                    (Text(f.date, format: .dateTime.day().month().hour().minute()) + Text(verbatim: " · ") + Text("\(f.count) registrazioni"))
                        .font(AppFont.serif(17)).foregroundStyle(Theme.ink)
                }
                .padding(.vertical, Space.s1)
                Hairline()
                PrimaryButton(title: "Ripristina questo backup") { onRestore(f) }
                    .padding(.top, Space.s2)
                textButton("Scegli un altro file", color: accent, bold: true, action: onPickFile)
            } else {
                Text("Nessun backup automatico trovato.")
                    .font(AppFont.sans(15)).foregroundStyle(Theme.ink)
                    .padding(.vertical, Space.s1)
                Hairline()
                PrimaryButton(title: "Scegli un file di backup", action: onPickFile)
                    .padding(.top, Space.s2)
            }
            textButton("Non ora", color: Theme.muted, bold: false, action: onLater)
        }
        .padding(.horizontal, Space.s3)
        .padding(.top, Space.s3)
        .padding(.bottom, Space.s2)
        .background(Theme.surface, in: shape)
        .overlay(shape.stroke(Theme.line, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.35), radius: 24, y: 12)
    }

    private func textButton(_ title: LocalizedStringKey, color: Color, bold: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.sans(15, bold ? .semibold : .regular))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s1)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .padding(.top, Space.s1)
    }
}
