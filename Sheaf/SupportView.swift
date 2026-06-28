import SwiftUI

/// Settings > Support. Surfaces operator contact, service status, and policy
/// links pulled from `/v1/auth/config` (all optional), plus static project
/// source/issues and security-contact links.
struct SupportView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var store: SystemStore

    @State private var isLoading = true
    @State private var config: [String: Any] = [:]

    private var supportEmail: String? { (config["support_email"] as? String)?.nilIfEmpty }
    private var supportURL: String? { (config["support_url"] as? String)?.nilIfEmpty }
    private var supportNote: String? { (config["support_note"] as? String)?.nilIfEmpty }
    private var supportCustomText: String? { (config["support_custom_text"] as? String)?.nilIfEmpty }
    private var statusURL: String? { (config["status_url"] as? String)?.nilIfEmpty }
    private var termsURL: String? { (config["terms_url"] as? String)?.nilIfEmpty }
    private var privacyURL: String? { (config["privacy_url"] as? String)?.nilIfEmpty }

    private var hasOperatorContact: Bool {
        supportEmail != nil || supportURL != nil || supportNote != nil || statusURL != nil
    }

    private var hasPolicies: Bool {
        termsURL != nil || privacyURL != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView().tint(theme.accentLight).padding(.top, 40)
                }

                // Operator-authored markdown blurb at the top. Server strips
                // any raw HTML before sending so it's safe to render.
                if let customText = supportCustomText {
                    MarkdownText(customText, color: theme.textPrimary)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                }

                if hasOperatorContact {
                    section(title: "Contact this instance") {
                        if let note = supportNote {
                            Text(note)
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(theme.backgroundCard)
                                .cornerRadius(12)
                        }
                        VStack(spacing: 0) {
                            if let email = supportEmail {
                                linkRow(icon: "envelope", title: "Email support", subtitle: email,
                                        url: "mailto:\(email)")
                            }
                            if let url = supportURL {
                                if supportEmail != nil { divider }
                                linkRow(icon: "globe", title: "Support site", subtitle: url, url: url)
                            }
                            if let url = statusURL {
                                if supportEmail != nil || supportURL != nil { divider }
                                linkRow(icon: "waveform.path.ecg", title: "Service status",
                                        subtitle: url, url: url)
                            }
                        }
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                    }
                }

                if hasPolicies {
                    section(title: "Policies") {
                        VStack(spacing: 0) {
                            if let url = termsURL {
                                linkRow(icon: "doc.text", title: "Terms of service",
                                        subtitle: url, url: url)
                            }
                            if let url = privacyURL {
                                if termsURL != nil { divider }
                                linkRow(icon: "lock.shield", title: "Privacy policy",
                                        subtitle: url, url: url)
                            }
                        }
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                    }
                }

                section(title: "Sheaf") {
                    VStack(spacing: 0) {
                        linkRow(icon: "chevron.left.forwardslash.chevron.right",
                                title: "Source & issues",
                                subtitle: "github.com/sheaf-project",
                                url: "https://github.com/sheaf-project/ios/issues")
                        divider
                        linkRow(icon: "shield.lefthalf.filled",
                                title: "Report a security issue",
                                subtitle: "security@sheaf.sh",
                                url: "mailto:security@sheaf.sh")
                    }
                    .background(theme.backgroundCard)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(theme.backgroundPrimary)
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func linkRow(icon: String, title: String, subtitle: String, url: String) -> some View {
        Button {
            if let target = URL(string: url) {
                UIApplication.shared.open(target)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(theme.accentLight)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.footnote)
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider().background(theme.divider).padding(.leading, 50)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = store.api else { return }
        if let cfg = try? await api.getAuthConfig() {
            config = cfg
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
