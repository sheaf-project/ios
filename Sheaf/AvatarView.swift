import SwiftUI

// MARK: - Avatar Image Cache

/// Shared cache for avatar images with automatic eviction under memory pressure.
final class AvatarImageCache: @unchecked Sendable {
    static let shared = AvatarImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 150
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        let cost = image.jpegData(compressionQuality: 1)?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    /// Fetches an image from the network or cache.
    func fetch(url: URL) async -> UIImage? {
        if let cached = image(for: url) { return cached }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let image = UIImage(data: data) else {
            return nil
        }
        set(image, for: url)
        return image
    }
}

// MARK: - AvatarView

struct AvatarView: View {
    let member: Member
    let size: CGFloat
    @Environment(\.apiBaseURL) private var baseURL

    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?

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
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
            image = nil
        }
    }

    private func loadIfNeeded() {
        guard image == nil,
              let url = resolveAvatarURL(member.avatarURL, baseURL: baseURL) else { return }

        // Check cache first (synchronous)
        if let cached = AvatarImageCache.shared.image(for: url) {
            image = cached
            return
        }

        loadTask = Task {
            let fetched = await AvatarImageCache.shared.fetch(url: url)
            guard !Task.isCancelled else { return }
            await MainActor.run { image = fetched }
        }
    }

    var fallbackView: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [member.displayColor, member.displayColor.opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            Text(member.initials)
                .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
