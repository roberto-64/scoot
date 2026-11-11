import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Lets the user pick a backup file and restore it.
/// Order: pick file, check it is a real backup, ask for confirmation, then replace the data.
struct BackupImporterModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var context
    @State private var pending: Data?
    @State private var confirm = false
    @State private var failed = false

    func body(content: Content) -> some View {
        content
            // Any file can be picked (a backup saved to iCloud Drive can be labelled in ways that grey out a plain
            // ".json" filter); `isValidBackup` still checks that the contents are a real Scoot backup.
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.json, .data]) { result in
                handle(result)
            }
            .confirmationDialog("Sostituire tutti i dati con questo backup?",
                                isPresented: $confirm,
                                titleVisibility: .visible) {
                Button("Sostituisci", role: .destructive) { apply() }
                Button("Annulla", role: .cancel) { pending = nil }
            } message: {
                Text("I dati attuali verranno cancellati.")
            }
            .alert("File non valido", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Questo file non è un backup di Scoot.")
            }
    }

    private func handle(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), isValidBackup(data) else {
            failed = true
            return
        }
        pending = data
        confirm = true
    }

    private func isValidBackup(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(BackupFile.self, from: data)) != nil
    }

    private func apply() {
        guard let data = pending else { return }
        pending = nil
        if BackupService.restore(data, into: context) {
            Haptics.success()
            DataSignal.fire()
        } else {
            failed = true
        }
    }
}

extension View {
    func backupImporter(isPresented: Binding<Bool>) -> some View {
        modifier(BackupImporterModifier(isPresented: isPresented))
    }
}
