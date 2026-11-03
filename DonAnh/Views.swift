import SwiftUI
import Photos

// MARK: - Gốc

struct ContentView: View {
    @EnvironmentObject var lib: PhotoLibrary

    var body: some View {
        switch lib.phase {
        case .idle: StartView()
        case .denied: DeniedView()
        case .scanning(let p, let text): ScanningView(progress: p, text: text)
        case .ready: MainView()
        }
    }
}

struct StartView: View {
    @EnvironmentObject var lib: PhotoLibrary

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Dọn Ảnh")
                .font(.largeTitle.bold())
            Text("Tìm ảnh trùng, video nặng và ảnh chụp màn hình để giải phóng dung lượng. Mọi thứ xử lý ngay trên iPhone, không gửi đi đâu.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                Task { await lib.start() }
            } label: {
                Text("Cho phép truy cập và quét")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            Text("Hãy chọn “Cho phép truy cập toàn bộ ảnh” để quét được cả thư viện.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .task {
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
                await lib.start()
            }
        }
    }
}

struct DeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Chưa có quyền truy cập ảnh")
                .font(.title2.bold())
            Text("Vào Cài đặt → Dọn Ảnh → Ảnh, chọn “Truy cập toàn bộ”.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Mở Cài đặt") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

struct ScanningView: View {
    let progress: Double
    let text: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .padding(.horizontal, 40)
            Text(text)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text("Thư viện lớn có thể mất vài phút. Hãy để màn hình sáng.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

struct MainView: View {
    @EnvironmentObject var lib: PhotoLibrary

    var body: some View {
        TabView {
            NavigationStack { DuplicatesView() }
                .tabItem { Label("Ảnh trùng", systemImage: "square.on.square") }
                .badge(lib.groups.count)
            NavigationStack { LargestView() }
                .tabItem { Label("Nặng nhất", systemImage: "arrow.down.circle") }
            NavigationStack { VideosView() }
                .tabItem { Label("Video", systemImage: "video") }
            NavigationStack { ScreenshotsView() }
                .tabItem { Label("Màn hình", systemImage: "iphone") }
        }
    }
}

// MARK: - Khung chung: tiêu đề, nút quét lại, thanh xoá

struct CleanerChrome: ViewModifier {
    @EnvironmentObject var lib: PhotoLibrary
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await lib.scan() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Quét lại")
                }
            }
            .safeAreaInset(edge: .bottom) { DeleteBar() }
    }
}

extension View {
    func cleanerChrome(_ title: String) -> some View { modifier(CleanerChrome(title: title)) }
}

struct DeleteBar: View {
    @EnvironmentObject var lib: PhotoLibrary
    @State private var deleting = false
    @State private var showDone = false
    @State private var showFail = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(lib.marked.count) mục đã chọn")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(bytes(lib.markedBytes))
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            Spacer()
            Button(role: .destructive) {
                Task {
                    deleting = true
                    let ok = await lib.deleteMarked()
                    deleting = false
                    if ok { showDone = true } else { showFail = true }
                }
            } label: {
                if deleting {
                    ProgressView()
                } else {
                    Label("Xoá", systemImage: "trash")
                        .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(lib.marked.isEmpty || deleting)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .alert("Đã chuyển vào “Đã xoá gần đây”", isPresented: $showDone) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Để giải phóng dung lượng ngay: mở Ảnh → Album → Đã xoá gần đây → Chọn → Xoá tất cả.")
        }
        .alert("Chưa xoá", isPresented: $showFail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Bạn đã huỷ, hoặc iOS không cho phép xoá. Các mục vẫn còn nguyên.")
        }
    }
}

// MARK: - Ảnh thu nhỏ

enum ThumbLoader {
    static let manager = PHCachingImageManager()

    static func load(_ a: PHAsset, side: CGFloat = 240) async -> UIImage? {
        await withCheckedContinuation { cont in
            let o = PHImageRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.resizeMode = .fast
            o.isNetworkAccessAllowed = true
            manager.requestImage(for: a, targetSize: CGSize(width: side, height: side),
                                 contentMode: .aspectFill, options: o) { img, _ in
                cont.resume(returning: img)
            }
        }
    }
}

struct Thumb: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemBackground)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .task(id: asset.localIdentifier) {
                image = await ThumbLoader.load(asset)
            }
    }
}

struct PhotoCell: View {
    @EnvironmentObject var lib: PhotoLibrary
    let item: Item
    var isBest = false
    var showKeep = true

    var body: some View {
        let del = lib.marked.contains(item.id)
        Button { lib.toggle(item.id) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Thumb(asset: item.asset)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(del ? 0.55 : 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(del ? Color.red : (showKeep ? Color.green : Color.clear), lineWidth: 2.5)
                    }
                    .overlay(alignment: .topLeading) {
                        if del || showKeep {
                            Text(del ? "XOÁ" : "GIỮ")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(del ? Color.red : Color.green, in: RoundedRectangle(cornerRadius: 4))
                                .padding(5)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isBest {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .shadow(radius: 2)
                                .padding(5)
                        }
                    }
                Text("\(item.asset.pixelWidth)×\(item.asset.pixelHeight) · \(bytes(item.size))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(del ? "sẽ xoá" : "giữ")")
    }
}

// MARK: - Ảnh trùng

struct DuplicatesView: View {
    @EnvironmentObject var lib: PhotoLibrary
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Picker("Độ giống", selection: $lib.similarity) {
                    ForEach(Similarity.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Text("Chạm ảnh để đổi GIỮ / XOÁ. Ảnh có ngôi sao là bản nét nhất và được giữ tự động.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if lib.groups.isEmpty {
                    Text("Không tìm thấy ảnh trùng. Thử mức “Hơi giống”.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }

                ForEach(Array(lib.groups.enumerated()), id: \.element.id) { idx, g in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Nhóm \(idx + 1) · \(g.items.count) ảnh")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            let s = g.items.filter { lib.marked.contains($0.id) }.reduce(Int64(0)) { $0 + $1.size }
                            Text(s > 0 ? "− \(bytes(s))" : "giữ tất cả")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(s > 0 ? Color.red : Color.secondary)
                        }
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(g.items) { item in
                                PhotoCell(item: item, isBest: item.id == g.id)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .cleanerChrome("Ảnh trùng")
    }
}

// MARK: - Video

struct VideosView: View {
    @EnvironmentObject var lib: PhotoLibrary

    var body: some View {
        let maxSize = max(lib.videos.first?.size ?? 1, 1)
        let total = lib.videos.reduce(Int64(0)) { $0 + $1.size }
        List {
            Section {
                ForEach(lib.videos) { v in
                    VideoRow(item: v, maxSize: maxSize)
                }
            } header: {
                Text("\(lib.videos.count) video · \(bytes(total)) · nặng nhất ở trên")
            } footer: {
                Text("Video gắn nhãn TRÙNG đã được chọn sẵn để xoá. Chạm để chọn hoặc bỏ chọn.")
            }
        }
        .cleanerChrome("Video")
    }
}

struct VideoRow: View {
    @EnvironmentObject var lib: PhotoLibrary
    let item: Item
    let maxSize: Int64

    var body: some View {
        let del = lib.marked.contains(item.id)
        Button { lib.toggle(item.id) } label: {
            HStack(spacing: 12) {
                Thumb(asset: item.asset)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        if lib.duplicateVideoIDs.contains(item.id) {
                            Text("TRÙNG")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                        }
                    }
                    Text(detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.2))
                            Capsule().fill(Color.red)
                                .frame(width: g.size.width * CGFloat(Double(item.size) / Double(maxSize)))
                        }
                    }
                    .frame(height: 4)
                }
                Image(systemName: del ? "trash.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(del ? Color.red : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(del ? Color.red.opacity(0.08) : nil)
    }

    private var detail: String {
        let s = Int(item.asset.duration.rounded())
        let dur = "\(s / 60):" + String(format: "%02d", s % 60)
        let date = item.asset.creationDate?.formatted(date: .numeric, time: .omitted) ?? ""
        return "\(bytes(item.size)) · \(dur) · \(date)"
    }
}

// MARK: - Ảnh chụp màn hình

struct ScreenshotsView: View {
    @EnvironmentObject var lib: PhotoLibrary
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        let ids = lib.screenshots.map(\.id)
        let allMarked = !ids.isEmpty && ids.allSatisfy { lib.marked.contains($0) }
        ScrollView {
            if lib.screenshots.isEmpty {
                Text("Không có ảnh chụp màn hình.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(lib.screenshots) { item in
                    PhotoCell(item: item, showKeep: false)
                }
            }
            .padding()
        }
        .cleanerChrome("Ảnh màn hình")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(allMarked ? "Bỏ chọn" : "Chọn tất cả") {
                    if allMarked { lib.marked.subtract(ids) } else { lib.marked.formUnion(ids) }
                }
                .disabled(ids.isEmpty)
            }
        }
    }
}

// MARK: - Nặng nhất: toàn bộ ảnh và video, xếp theo dung lượng

enum SizeFilter: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case photos = "Ảnh"
    case videos = "Video"
    var id: String { rawValue }
}

struct LargestView: View {
    @EnvironmentObject var lib: PhotoLibrary
    @State private var filter: SizeFilter = .all
    @State private var preview: Item?
    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 6)]

    private var items: [Item] {
        switch filter {
        case .all: return lib.largest
        case .photos: return lib.largest.filter { $0.asset.mediaType == .image }
        case .videos: return lib.largest.filter { $0.asset.mediaType == .video }
        }
    }

    var body: some View {
        let list = items
        let total = list.reduce(Int64(0)) { $0 + $1.size }
        let top50 = list.prefix(50).reduce(Int64(0)) { $0 + $1.size }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Loại", selection: $filter) {
                    ForEach(SizeFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(list.count) mục · tổng \(bytes(total))")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    if list.count > 50, total > 0 {
                        Text("50 mục nặng nhất chiếm \(bytes(top50)) (\(Int(Double(top50) / Double(total) * 100))%).")
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Text("Chạm để chọn xoá. Nhấn giữ để xem ảnh lớn.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(list) { item in
                        SizeCell(item: item)
                            .onLongPressGesture { preview = item }
                    }
                }
            }
            .padding()
        }
        .cleanerChrome("Nặng nhất")
        .sheet(item: $preview) { PreviewSheet(item: $0) }
    }
}

struct SizeCell: View {
    @EnvironmentObject var lib: PhotoLibrary
    let item: Item

    var body: some View {
        let del = lib.marked.contains(item.id)
        let isVideo = item.asset.mediaType == .video
        Button { lib.toggle(item.id) } label: {
            Thumb(asset: item.asset)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .opacity(del ? 0.55 : 1)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(del ? Color.red : Color.clear, lineWidth: 2.5)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 3) {
                        if isVideo { Image(systemName: "video.fill") }
                        Text(bytes(item.size)).monospacedDigit()
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                    .padding(5)
                }
                .overlay(alignment: .topTrailing) {
                    if del {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .red)
                            .padding(4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(bytes(item.size)), \(del ? "sẽ xoá" : "giữ")")
    }
}

struct PreviewSheet: View {
    @EnvironmentObject var lib: PhotoLibrary
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var image: UIImage?

    var body: some View {
        let del = lib.marked.contains(item.id)
        NavigationStack {
            VStack(spacing: 16) {
                Group {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                    } else {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)

                VStack(spacing: 4) {
                    Text(item.name).font(.headline).lineLimit(1)
                    Text(info)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Button(role: del ? nil : .destructive) {
                    lib.toggle(item.id)
                    dismiss()
                } label: {
                    Label(del ? "Bỏ chọn xoá" : "Chọn để xoá", systemImage: del ? "arrow.uturn.backward" : "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(del ? .gray : .red)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Đóng") { dismiss() } }
            }
        }
        .task { image = await ThumbLoader.load(item.asset, side: 1200) }
    }

    private var info: String {
        var parts = [bytes(item.size), "\(item.asset.pixelWidth)×\(item.asset.pixelHeight)"]
        if item.asset.mediaType == .video {
            let s = Int(item.asset.duration.rounded())
            parts.append("\(s / 60):" + String(format: "%02d", s % 60))
        }
        if let d = item.asset.creationDate { parts.append(d.formatted(date: .abbreviated, time: .omitted)) }
        return parts.joined(separator: " · ")
    }
}
