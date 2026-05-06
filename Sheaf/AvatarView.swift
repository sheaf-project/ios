import SwiftUI
import ImageIO
import CryptoKit
#if os(watchOS)
import WatchConnectivity
#endif

// MARK: - Avatar Image Cache

/// Shared cache for avatar images with automatic eviction under memory pressure.
final class AvatarImageCache: @unchecked Sendable {
    static let shared = AvatarImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private static let diskCacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("avatars")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        cache.countLimit = 150
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    /// Returns a stable filename for a URL using its SHA256 hash.
    private static func diskKey(for url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Loads image data from the disk cache.
    func imageFromDisk(for url: URL) -> UIImage? {
        let path = Self.diskCacheDirectory.appendingPathComponent(Self.diskKey(for: url))
        guard let data = try? Data(contentsOf: path) else { return nil }
        guard let img = UIImage(data: data) ?? Self.decodeWithImageIO(data) else { return nil }
        set(img, for: url)
        return img
    }

    /// Persists raw image data to disk.
    func writeToDisk(_ data: Data, for url: URL) {
        let path = Self.diskCacheDirectory.appendingPathComponent(Self.diskKey(for: url))
        try? data.write(to: path, options: .atomic)
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        let pixels = Int(image.size.width * image.scale) * Int(image.size.height * image.scale)
        let cost = pixels * 4
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    /// Fetches an image from memory, disk, or network (in that order).
    func fetch(request: URLRequest) async -> UIImage? {
        guard let url = request.url else { return nil }
        if let cached = image(for: url) { return cached }
        if let disk = imageFromDisk(for: url) { return disk }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return nil }
            guard let image = UIImage(data: data) ?? Self.decodeWithImageIO(data) else {
                return nil
            }
            set(image, for: url)
            writeToDisk(data, for: url)
            return image
        } catch {
            return nil
        }
    }

    /// Decodes image data using ImageIO directly, supporting formats UIImage may not handle.
    private static func decodeWithImageIO(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return UIImage(cgImage: cgImage)
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceShouldCacheImmediately: true
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}

// MARK: - AvatarView

struct AvatarView: View {
    let member: Member
    let size: CGFloat
    @Environment(\.apiBaseURL) private var baseURL
    @Environment(\.apiAccessToken) private var accessToken

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .onAppear { loadIfNeeded() }
        #if os(watchOS)
        .onReceive(NotificationCenter.default.publisher(for: .avatarsUpdated)) { _ in
            loadFromLocalCache()
        }
        #endif
    }

    #if os(watchOS)
    private func loadFromLocalCache() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatars")
        let cachedFile = cacheDir.appendingPathComponent(member.id + ".jpg")
        if let localData = try? Data(contentsOf: cachedFile),
           let localImage = UIImage(data: localData) {
            image = localImage
        }
    }
    #endif

    private func loadIfNeeded() {
        guard image == nil else { return }

        // Check local file cache (JPEG avatars synced from iPhone via WatchConnectivity)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatars")
        let cachedFile = cacheDir.appendingPathComponent(member.id + ".jpg")
        if let localData = try? Data(contentsOf: cachedFile),
           let localImage = UIImage(data: localData) {
            image = localImage
            return
        }

        #if os(watchOS)
        // On watchOS, request avatar from iPhone which can decode WebP
        requestAvatarFromPhone()
        #else
        loadFromNetwork()
        #endif
    }

    #if os(watchOS)
    private func requestAvatarFromPhone() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            // Phone not reachable, try direct network fetch as fallback
            loadFromNetwork()
            return
        }
        let memberID = member.id
        let message: [String: Any] = [
            "requestAvatar": memberID,
            "avatarURL": member.avatarURL ?? "",
            "baseURL": baseURL
        ]
        WCSession.default.sendMessage(message, replyHandler: { reply in
            guard let jpegData = reply["avatarData"] as? Data,
                  UIImage(data: jpegData) != nil else { return }
            // Save to local cache, then notify all AvatarViews to reload
            let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("avatars")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? jpegData.write(to: dir.appendingPathComponent(memberID + ".jpg"))
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .avatarsUpdated, object: nil)
            }
        }, errorHandler: { _ in })
    }
    #endif

    private func loadFromNetwork() {
        guard let url = resolveAvatarURL(member.avatarURL, baseURL: baseURL) else { return }

        // Check in-memory cache
        if let cached = AvatarImageCache.shared.image(for: url) {
            image = cached
            return
        }

        // Check disk cache
        if let disk = AvatarImageCache.shared.imageFromDisk(for: url) {
            image = disk
            return
        }

        var request = URLRequest(url: url)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        request.setValue("Sheaf iOS/\(version)", forHTTPHeaderField: "User-Agent")
        if member.avatarURL?.hasPrefix("/") == true {
            if !accessToken.isEmpty {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            if let cfID = KeychainHelper.get(key: "sheaf_cf_client_id"), !cfID.isEmpty,
               let cfSecret = KeychainHelper.get(key: "sheaf_cf_client_secret"), !cfSecret.isEmpty {
                request.setValue(cfID, forHTTPHeaderField: "CF-Access-Client-Id")
                request.setValue(cfSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
            }
        }

        Task {
            image = await AvatarImageCache.shared.fetch(request: request)
        }
    }

    var fallbackView: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [member.displayColor, member.displayColor.opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            if let emoji = member.emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size * 0.48))
            } else {
                Text(member.initials)
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}
