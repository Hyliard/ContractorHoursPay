import SwiftUI
import UIKit

struct UserAvatarView: View {
    @EnvironmentObject private var authManager: AuthManager

    let user: User?
    let size: CGFloat

    @State private var image: UIImage?
    @State private var isLoading = false

    private let service = AvatarAPIService()

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.tertiarySystemGroupedBackground))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityLabel("Foto de perfil")
        .task(id: user?.avatarUrl) {
            await loadAvatar()
        }
    }

    private func loadAvatar() async {
        guard let avatarUrl = user?.avatarUrl, !avatarUrl.isEmpty, let token = authManager.token else {
            image = nil
            isLoading = false
            return
        }

        if let cachedImage = AvatarImageCache.image(forKey: avatarUrl) {
            image = cachedImage
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await service.fetchAvatar(token: token)
            guard let loadedImage = UIImage(data: data) else {
                image = nil
                return
            }
            AvatarImageCache.setImage(loadedImage, forKey: avatarUrl)
            image = loadedImage
        } catch {
            image = nil
        }
    }
}

enum AvatarImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    static func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    static func removeImage(forKey key: String?) {
        guard let key else { return }
        cache.removeObject(forKey: key as NSString)
    }
}
