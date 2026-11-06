import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - Storage

/// A photo attached to a maintenance entry or an expense (receipt, invoice, the work itself).
/// The picture lives in a file next to the database (external storage), not inside it.
@Model
final class EntryPhoto {
    var createdAt: Date = Date()
    @Attribute(.externalStorage) var data: Data = Data()
    var maintenance: MaintenanceEntry?
    var expense: ExpenseEntry?

    init(data: Data, createdAt: Date = Date()) {
        self.data = data
        self.createdAt = createdAt
    }
}

enum PhotoTools {
    /// Longest side of a stored photo, in pixels.
    static let maxSide: CGFloat = 1600

    /// Shrinks a picture so it stays small on the phone and in the backup (about 200–400 KB).
    static func shrink(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return img.jpegData(compressionQuality: 0.7)
    }

    static func shrink(_ data: Data) -> Data? {
        UIImage(data: data).flatMap { shrink($0) }
    }
}

extension MaintenanceEntry {
    var photoData: [Data] { photos.sorted { $0.createdAt < $1.createdAt }.map { $0.data } }
}

extension ExpenseEntry {
    var photoData: [Data] { photos.sorted { $0.createdAt < $1.createdAt }.map { $0.data } }
}

// MARK: - Form section

/// "Foto" block for the forms: thumbnails, an "Aggiungi" tile, tap a thumbnail to open it full screen.
/// The pictures are held in `photos` until the form is saved.
struct PhotoSection: View {
    @Environment(\.appAccent) private var accent
    @Binding var photos: [Data]
    @State private var choosing = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var picked: [PhotosPickerItem] = []
    @State private var viewing: ViewerStart?

    private struct ViewerStart: Identifiable {
        let id = UUID()
        let index: Int
    }

    private let tileW: CGFloat = 88
    private let tileH: CGFloat = 112
    private let tileRadius: CGFloat = 12
    private let limit = 8

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("Foto").eyebrow()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s2) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { i, d in
                        Button { viewing = ViewerStart(index: i) } label: {
                            PhotoThumb(data: d, width: tileW, height: tileH, radius: tileRadius)
                        }
                        .buttonStyle(PressStyle())
                    }
                    if photos.count < limit {
                        Button { choosing = true } label: {
                            VStack(spacing: Space.s1) {
                                Image(systemName: "plus").font(.system(size: 22, weight: .semibold))
                                Text("Aggiungi").font(AppFont.sans(13, .semibold))
                            }
                            .foregroundStyle(accent)
                            .frame(width: tileW, height: tileH)
                            .overlay(
                                RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                                    .stroke(accent.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
            }
            if !photos.isEmpty {
                Text("Tocca una foto per aprirla.").eyebrow()
            }
        }
        .confirmationDialog("Aggiungi una foto", isPresented: $choosing, titleVisibility: .hidden) {
            if cameraAvailable {
                Button("Scatta una foto") { showCamera = true }
            }
            Button("Scegli dalla libreria") { showLibrary = true }
            Button("Annulla", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibrary, selection: $picked,
                      maxSelectionCount: max(1, limit - photos.count), matching: .images)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var added: [Data] = []
                for item in items {
                    if let raw = try? await item.loadTransferable(type: Data.self),
                       let small = PhotoTools.shrink(raw) {
                        added.append(small)
                    }
                }
                await MainActor.run {
                    photos.append(contentsOf: added.prefix(max(0, limit - photos.count)))
                    picked = []
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let small = PhotoTools.shrink(image), photos.count < limit { photos.append(small) }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $viewing) { start in
            PhotoViewer(photos: $photos, start: start.index)
        }
    }
}

/// One small picture, cropped to fill.
struct PhotoThumb: View {
    let data: Data
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.surface
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .cardShadow()
        .task(id: data.count) {
            let d = data
            let target = CGSize(width: width * 3, height: height * 3)
            image = await Task.detached(priority: .userInitiated) {
                UIImage(data: d)?.preparingThumbnail(of: target)
            }.value
        }
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Full-screen viewer

/// One picture you can pinch to zoom. A UIScrollView does the zooming, so swiping between
/// pictures still works while the picture is at normal size.
private struct ZoomImage: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 4
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.delegate = context.coordinator
        sv.backgroundColor = .clear
        let iv = UIImageView(image: UIImage(data: data))
        iv.contentMode = .scaleAspectFit
        iv.frame = sv.bounds
        iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sv.addSubview(iv)
        context.coordinator.imageView = iv
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        sv.addGestureRecognizer(tap)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func doubleTap(_ g: UITapGestureRecognizer) {
            guard let sv = g.view as? UIScrollView else { return }
            sv.setZoomScale(sv.zoomScale > 1.01 ? 1 : 2.5, animated: true)
        }
    }
}

struct PhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var photos: [Data]
    @State private var index: Int

    private let background = Color(hex: 0x1D130D)
    private let onDark = Color(hex: 0xF8F1E4)

    init(photos: Binding<[Data]>, start: Int) {
        _photos = photos
        _index = State(initialValue: start)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.offset) { i, d in
                    ZoomImage(data: d).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(onDark)
                            .frame(width: Space.s5, height: Space.s5)
                            .background(onDark.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                    Spacer()
                    Text("\(min(index + 1, max(photos.count, 1))) di \(photos.count)")
                        .font(AppFont.sans(15, .semibold)).foregroundStyle(onDark).monospacedDigit()
                    Spacer()
                    Color.clear.frame(width: Space.s5, height: Space.s5)
                }
                .padding(.horizontal, Space.s2)
                .padding(.top, Space.s1)
                Spacer()
                Button { remove() } label: {
                    HStack(spacing: Space.s1) {
                        Image(systemName: "trash")
                        Text("Elimina foto")
                    }
                    .font(AppFont.sans(15, .semibold))
                    .foregroundStyle(onDark)
                    .padding(.horizontal, Space.s3)
                    .frame(height: Space.s5)
                    .background(onDark.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.base, style: .continuous))
                }
                .buttonStyle(PressStyle())
                .padding(.bottom, Space.s3)
            }
        }
    }

    private func remove() {
        guard photos.indices.contains(index) else { return }
        Haptics.tick()
        photos.remove(at: index)
        if photos.isEmpty {
            dismiss()
        } else {
            index = min(index, photos.count - 1)
        }
    }
}
