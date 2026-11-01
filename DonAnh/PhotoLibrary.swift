import Photos
import UIKit

// MARK: - Model

struct Item: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let name: String
    let size: Int64              // tổng dung lượng các tệp của ảnh/video (byte)
    let fingerprint: UInt64?     // dHash 64-bit từ ảnh thu nhỏ
    let color: SIMD3<Float>      // màu trung bình (0...1)

    var pixels: Int { asset.pixelWidth * asset.pixelHeight }

    static func == (a: Item, b: Item) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct DupGroup: Identifiable {
    let id: String
    let items: [Item]           // phần tử đầu tiên là bản tốt nhất
    var saving: Int64 { items.dropFirst().reduce(0) { $0 + $1.size } }
}

enum Similarity: String, CaseIterable, Identifiable {
    case exact = "Y hệt"
    case close = "Rất giống"
    case loose = "Hơi giống"

    var id: String { rawValue }
    var bits: Int {
        switch self {
        case .exact: return 3
        case .close: return 7
        case .loose: return 12
        }
    }
    var colorTolerance: Float {
        switch self {
        case .exact: return 0.10
        case .close: return 0.16
        case .loose: return 0.22
        }
    }
}

func bytes(_ b: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
}

// MARK: - Library

@MainActor
final class PhotoLibrary: ObservableObject {
    enum Phase {
        case idle
        case denied
        case scanning(Double, String)
        case ready
    }

    @Published var phase: Phase = .idle
    @Published var groups: [DupGroup] = []
    @Published var videos: [Item] = []
    @Published var screenshots: [Item] = []
    @Published var duplicateVideoIDs: Set<String> = []
    @Published var marked: Set<String> = []
    @Published var similarity: Similarity = .close {
        didSet { Task { await regroup() } }
    }

    private var photos: [Item] = []
    private var index: [String: Item] = [:]

    var markedBytes: Int64 {
        marked.reduce(0) { $0 + (index[$1]?.size ?? 0) }
    }

    func toggle(_ id: String) {
        if marked.contains(id) { marked.remove(id) } else { marked.insert(id) }
    }

    func start() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            phase = .denied
            return
        }
        await scan()
    }

    func scan() async {
        phase = .scanning(0, "Đang đọc thư viện…")

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var imageAssets: [PHAsset] = []
        var videoAssets: [PHAsset] = []
        PHAsset.fetchAssets(with: .image, options: opts).enumerateObjects { a, _, _ in imageAssets.append(a) }
        PHAsset.fetchAssets(with: .video, options: opts).enumerateObjects { a, _, _ in videoAssets.append(a) }

        let total = max(imageAssets.count + videoAssets.count, 1)
        var done = 0

        func analyze(_ assets: [PHAsset], label: String) async -> [Item] {
            var out: [Item] = []
            out.reserveCapacity(assets.count)
            let chunk = 48
            for start in stride(from: 0, to: assets.count, by: chunk) {
                let slice = Array(assets[start..<min(start + chunk, assets.count)])
                let items = await withTaskGroup(of: Item.self) { group -> [Item] in
                    for a in slice { group.addTask { Analyzer.item(for: a) } }
                    var r: [Item] = []
                    for await i in group { r.append(i) }
                    return r
                }
                out += items
                done += slice.count
                phase = .scanning(Double(done) / Double(total), "\(label) \(min(start + chunk, assets.count))/\(assets.count)")
            }
            return out
        }

        let p = await analyze(imageAssets, label: "Ảnh")
        let v = await analyze(videoAssets, label: "Video")

        photos = p
        videos = v.sorted { $0.size > $1.size }
        screenshots = p
            .filter { $0.asset.mediaSubtypes.contains(.photoScreenshot) }
            .sorted { ($0.asset.creationDate ?? .distantPast) > ($1.asset.creationDate ?? .distantPast) }
        index = Dictionary((p + v).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        marked = []

        phase = .scanning(1, "Đang so sánh ảnh…")
        await regroup()
        phase = .ready
    }

    func regroup() async {
        let p = photos, v = videos, s = similarity
        let result = await Task.detached(priority: .userInitiated) {
            Grouper.run(photos: p, videos: v, sim: s)
        }.value

        // Giữ lại các lựa chọn tay ở Video và Ảnh màn hình, đặt lại đề xuất cho ảnh trùng.
        let keepManual = Set(videos.map(\.id)).union(screenshots.map(\.id))
        var m = marked.filter { keepManual.contains($0) }
        for g in result.groups { for it in g.items.dropFirst() { m.insert(it.id) } }
        m.formUnion(result.dupVideos)

        groups = result.groups
        duplicateVideoIDs = result.dupVideos
        marked = m
    }

    /// Xoá các mục đã đánh dấu. iOS sẽ hiện hộp thoại xác nhận của hệ thống.
    func deleteMarked() async -> Bool {
        let ids = Array(marked)
        guard !ids.isEmpty else { return false }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
        } catch {
            return false
        }
        let gone = Set(ids)
        photos.removeAll { gone.contains($0.id) }
        videos.removeAll { gone.contains($0.id) }
        screenshots.removeAll { gone.contains($0.id) }
        for id in gone { index[id] = nil }
        marked = []
        await regroup()
        return true
    }
}

// MARK: - Phân tích từng ảnh (chạy ngoài luồng chính)

enum Analyzer {
    static let manager = PHImageManager.default()

    static func item(for a: PHAsset) -> Item {
        let res = PHAssetResource.assetResources(for: a)
        var size: Int64 = 0
        for r in res {
            if let n = r.value(forKey: "fileSize") as? NSNumber { size += n.int64Value }
        }
        let name = res.first?.originalFilename ?? "Không tên"

        var fp: UInt64? = nil
        var col = SIMD3<Float>(repeating: 0)
        if let cg = thumbnail(a) {
            let r = dHash(cg)
            fp = r.0
            col = r.1
        }
        return Item(id: a.localIdentifier, asset: a, name: name, size: size, fingerprint: fp, color: col)
    }

    static func thumbnail(_ a: PHAsset) -> CGImage? {
        let o = PHImageRequestOptions()
        o.isSynchronous = true
        o.deliveryMode = .fastFormat
        o.resizeMode = .fast
        o.isNetworkAccessAllowed = false
        var out: CGImage?
        manager.requestImage(for: a, targetSize: CGSize(width: 64, height: 64),
                             contentMode: .aspectFill, options: o) { img, _ in
            out = img?.cgImage
        }
        return out
    }

    /// dHash: thu ảnh về 9×8 xám, so sánh từng điểm với điểm bên phải.
    static func dHash(_ img: CGImage) -> (UInt64, SIMD3<Float>) {
        let w = 9, h = 8
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ok: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return (0, SIMD3(repeating: 0)) }

        var sum = SIMD3<Float>(repeating: 0)
        for i in stride(from: 0, to: px.count, by: 4) {
            sum += SIMD3(Float(px[i]), Float(px[i + 1]), Float(px[i + 2]))
        }
        func lum(_ i: Int) -> Float {
            0.299 * Float(px[i]) + 0.587 * Float(px[i + 1]) + 0.114 * Float(px[i + 2])
        }
        var hash: UInt64 = 0
        for y in 0..<h {
            for x in 0..<8 {
                let i = (y * w + x) * 4
                hash <<= 1
                if lum(i) < lum(i + 4) { hash |= 1 }
            }
        }
        return (hash, sum / Float(w * h * 255))
    }
}

// MARK: - Gom nhóm

enum Grouper {
    static func run(photos: [Item], videos: [Item], sim: Similarity) -> (groups: [DupGroup], dupVideos: Set<String>) {
        let cand = photos.filter { $0.fingerprint != nil }
        let n = cand.count
        let fps = cand.map { $0.fingerprint! }
        let cols = cand.map(\.color)
        var parent = Array(0..<n)

        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
            return x
        }

        let bits = sim.bits
        let tol2 = sim.colorTolerance * sim.colorTolerance
        if n > 1 {
            for i in 0..<(n - 1) {
                let fi = fps[i], ci = cols[i]
                for j in (i + 1)..<n {
                    if (fi ^ fps[j]).nonzeroBitCount > bits { continue }
                    let d = ci - cols[j]
                    if (d * d).sum() > tol2 { continue }
                    let a = find(i), b = find(j)
                    if a != b { parent[a] = b }
                }
            }
        }

        var buckets: [Int: [Item]] = [:]
        for i in 0..<n { buckets[find(i), default: []].append(cand[i]) }

        let groups = buckets.values
            .filter { $0.count > 1 }
            .map { items -> DupGroup in
                let s = items.sorted { ($0.pixels, $0.size) > ($1.pixels, $1.size) }
                return DupGroup(id: s[0].id, items: s)
            }
            .sorted { $0.saving > $1.saving }

        // Video trùng: cùng độ dài (±0,5 giây), cùng độ phân giải, khung hình giống nhau.
        var dup = Set<String>()
        let vs = videos.sorted { ($0.asset.creationDate ?? .distantPast) < ($1.asset.creationDate ?? .distantPast) }
        for i in vs.indices where !dup.contains(vs[i].id) {
            for j in vs.indices where j > i && !dup.contains(vs[j].id) {
                let a = vs[i], b = vs[j]
                guard abs(a.asset.duration - b.asset.duration) < 0.5, a.pixels == b.pixels else { continue }
                if let fa = a.fingerprint, let fb = b.fingerprint, (fa ^ fb).nonzeroBitCount > 8 { continue }
                dup.insert(b.id)
            }
        }
        return (groups, dup)
    }
}
