import SwiftUI

struct AvatarView: View {
    let member: Member
    let size: CGFloat
    @Environment(\.apiBaseURL) private var baseURL

    var body: some View {
        ZStack {
            if let url = resolveAvatarURL(member.avatarURL, baseURL: baseURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallbackView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
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
