import SwiftUI
import Combine

// MARK: - Theme Mode
enum ThemeMode: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
}

// MARK: - Client Settings (synced to server)
struct ClientSettings: Codable, Equatable {
    var themeMode: String

    static let empty = ClientSettings(themeMode: ThemeMode.system.rawValue)

    init(themeMode: String) { self.themeMode = themeMode }

    init(from dict: [String: Any]) {
        self.themeMode = dict["theme_mode"] as? String ?? ThemeMode.system.rawValue
    }

    func toDict() -> [String: Any] {
        ["theme_mode": themeMode]
    }
}

// MARK: - ThemeManager
final class ThemeManager: ObservableObject {
    @Published var mode: ThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "sheaf_theme") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "sheaf_theme") ?? "system"
        mode = ThemeMode(rawValue: raw) ?? .system
    }

    /// Resolved colorScheme to pass to the root view. nil = follow system.
    var colorScheme: ColorScheme? {
        switch mode {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// Apply a mode received from the server without triggering a server save.
    func applyFromServer(_ newMode: ThemeMode) {
        guard newMode != mode else { return }
        mode = newMode
    }
}

// MARK: - Theme Colors
/// Use these everywhere instead of hardcoded hex values.
struct Theme {
    let isDark: Bool

    // Backgrounds
    var backgroundPrimary:   Color { isDark ? Color(hex: "#0F0C29")! : Color(hex: "#F2F0FF")! }
    var backgroundSecondary: Color { isDark ? Color(hex: "#1A1535")! : Color(hex: "#FFFFFF")! }
    var backgroundCard:      Color { isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04) }
    var backgroundElevated:  Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06) }

    // Gradients
    var backgroundGradient: LinearGradient {
        isDark
            ? LinearGradient(colors: [Color(hex: "#0F0C29")!, Color(hex: "#1A1535")!],
                             startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(hex: "#F2F0FF")!, Color(hex: "#EBE8FF")!],
                             startPoint: .top, endPoint: .bottom)
    }

    var loginGradient: LinearGradient {
        isDark
            ? LinearGradient(colors: [Color(hex: "#0F0C29")!, Color(hex: "#302B63")!, Color(hex: "#24243E")!],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(hex: "#EDE9FF")!, Color(hex: "#DDD6FE")!, Color(hex: "#E0E7FF")!],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    var textPrimary:   Color { isDark ? .white              : Color(hex: "#1A1035")! }
    var textSecondary: Color { isDark ? .white.opacity(0.6) : Color(hex: "#1A1035")!.opacity(0.6) }
    var textTertiary:  Color { isDark ? .white.opacity(0.35): Color(hex: "#1A1035")!.opacity(0.35) }

    // Borders & dividers
    var border:   Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }
    var divider:  Color { isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06) }

    // Accent
    var accent:       Color { Color(hex: "#8B5CF6")! }
    var accentLight:  Color { Color(hex: "#A78BFA")! }
    var accentSoft:   Color { isDark ? Color(hex: "#A78BFA")!.opacity(0.15) : Color(hex: "#8B5CF6")!.opacity(0.1) }

    // Status
    var success: Color { isDark ? Color(hex: "#4ADE80")! : Color(hex: "#16A34A")! }
    var danger:  Color { isDark ? Color(hex: "#F87171")! : Color(hex: "#DC2626")! }
    var warning: Color { isDark ? Color(hex: "#FBBF24")! : Color(hex: "#D97706")! }

    // Input fields
    var inputBackground: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05) }
    var inputBorder:     Color { isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12) }
    var inputBorderFocused: Color { accentLight }
}

// MARK: - Environment Keys
struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(isDark: true)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Markdown Text

struct MarkdownText: View {
    let markdown: String
    let color: Color

    init(_ markdown: String, color: Color = .primary) {
        self.markdown = markdown
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    private enum Block {
        case heading(String, Int)
        case quote(String)
        case codeBlock(String)
        case listItem(String, Bool)
        case paragraph(String)
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = markdown.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeLines: [String] = []

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            } else if trimmed.hasPrefix("### ") {
                blocks.append(.heading(String(trimmed.dropFirst(4)), 3))
            } else if trimmed.hasPrefix("## ") {
                blocks.append(.heading(String(trimmed.dropFirst(3)), 2))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(.heading(String(trimmed.dropFirst(2)), 1))
            } else if trimmed.hasPrefix("> ") {
                blocks.append(.quote(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(.listItem(String(trimmed.dropFirst(2)), false))
            } else if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                blocks.append(.listItem(String(trimmed[match.upperBound...]), true))
            } else {
                blocks.append(.paragraph(trimmed))
            }
        }

        if inCodeBlock && !codeLines.isEmpty {
            blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
        }

        return blocks
    }

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .heading(let text, let level):
            inlineText(text)
                .font(level == 1 ? .title3.bold() : level == 2 ? .headline : .subheadline.bold())

        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color.opacity(0.3))
                    .frame(width: 3)
                inlineText(text)
                    .italic()
                    .opacity(0.8)
            }

        case .codeBlock(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(color)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.08))
                .cornerRadius(8)

        case .listItem(let text, let ordered):
            HStack(alignment: .top, spacing: 8) {
                if ordered {
                    Text("•")
                        .foregroundColor(color.opacity(0.5))
                } else {
                    Text("•")
                        .foregroundColor(color.opacity(0.5))
                }
                inlineText(text)
            }

        case .paragraph(let text):
            inlineText(text)
        }
    }

    private func inlineText(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(applyColor(attributed))
        }
        return Text(text).foregroundColor(color)
    }

    private func applyColor(_ string: AttributedString) -> AttributedString {
        var result = string
        result.foregroundColor = color
        return result
    }
}
