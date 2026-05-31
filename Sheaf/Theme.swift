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

// MARK: - Palette
enum Palette: String, CaseIterable {
    case purple    = "purple"
    case twilight  = "twilight"
    case oled      = "oled"
    case mint      = "mint"
    case ocean     = "ocean"
    case sepia     = "sepia"
    case pride     = "pride"
    case trans     = "trans"
    case nonbinary = "nonbinary"

    var label: String {
        switch self {
        case .purple:    return "Purple"
        case .twilight:  return "Twilight"
        case .oled:      return "OLED"
        case .mint:      return "Mint"
        case .ocean:     return "Ocean"
        case .sepia:     return "Sepia"
        case .pride:     return "Pride"
        case .trans:     return "Trans"
        case .nonbinary: return "Non-binary"
        }
    }

    /// Three representative colors shown in the palette picker swatch.
    var swatch: [Color] {
        switch self {
        case .purple:    return [Color(hex: "#8B5CF6")!, Color(hex: "#A78BFA")!, Color(hex: "#C4B5FD")!]
        case .twilight:   return [Color(hex: "#7C6FE5")!, Color(hex: "#9D8FFF")!, Color(hex: "#C7BEFF")!]
        case .oled:      return [Color(hex: "#5EE6FF")!, Color(hex: "#67D7FF")!, Color(hex: "#71C9FF")!]
        case .mint:      return [Color(hex: "#10B981")!, Color(hex: "#34D399")!, Color(hex: "#6EE7B7")!]
        case .ocean:     return [Color(hex: "#3B82F6")!, Color(hex: "#60A5FA")!, Color(hex: "#93C5FD")!]
        case .sepia:     return [Color(hex: "#D97706")!, Color(hex: "#F59E0B")!, Color(hex: "#FBBF24")!]
        case .pride:     return [Color(hex: "#EF4444")!, Color(hex: "#FB923C")!, Color(hex: "#FBBF24")!]
        case .trans:     return [Color(hex: "#F5A9B8")!, Color(hex: "#FFFFFF")!, Color(hex: "#5BCEFA")!]
        case .nonbinary: return [Color(hex: "#FCF434")!, Color(hex: "#FFFFFF")!, Color(hex: "#9C59D1")!]
        }
    }

    /// Card background shown behind the swatch tile in the picker.
    var swatchTileBackground: Color {
        switch self {
        case .purple:    return Color(hex: "#1A1535")!
        case .twilight:   return Color(hex: "#1F1A3A")!
        case .oled:      return .black
        case .mint:      return Color(hex: "#0F2A20")!
        case .ocean:     return Color(hex: "#0F1F35")!
        case .sepia:     return Color(hex: "#241A12")!
        case .pride:     return Color(hex: "#1F1422")!
        case .trans:     return Color(hex: "#2B1A24")!
        case .nonbinary: return Color(hex: "#1A1A1A")!
        }
    }

    // MARK: Palette colors

    fileprivate func accent(isDark: Bool) -> Color {
        switch self {
        case .purple:    return Color(hex: "#8B5CF6")!
        case .twilight:   return Color(hex: "#7C6FE5")!
        case .oled:      return Color(hex: "#22D3EE")!
        case .mint:      return isDark ? Color(hex: "#34D399")! : Color(hex: "#059669")!
        case .ocean:     return Color(hex: "#3B82F6")!
        case .sepia:     return isDark ? Color(hex: "#F59E0B")! : Color(hex: "#D97706")!
        case .pride:     return Color(hex: "#EC4899")!
        case .trans:     return Color(hex: "#5BCEFA")!
        case .nonbinary: return isDark ? Color(hex: "#9C59D1")! : Color(hex: "#7C3AED")!
        }
    }

    fileprivate func accentLight(isDark: Bool) -> Color {
        switch self {
        case .purple:    return Color(hex: "#A78BFA")!
        case .twilight:   return Color(hex: "#9D8FFF")!
        case .oled:      return Color(hex: "#67E8F9")!
        case .mint:      return isDark ? Color(hex: "#6EE7B7")! : Color(hex: "#34D399")!
        case .ocean:     return Color(hex: "#60A5FA")!
        case .sepia:     return Color(hex: "#FBBF24")!
        case .pride:     return Color(hex: "#F472B6")!
        case .trans:     return Color(hex: "#F5A9B8")!
        case .nonbinary: return isDark ? Color(hex: "#FCF434")! : Color(hex: "#9C59D1")!
        }
    }

    fileprivate func backgroundPrimary(isDark: Bool) -> Color {
        if !isDark {
            switch self {
            case .purple:    return Color(hex: "#F2F0FF")!
            case .twilight:   return Color(hex: "#EFECFF")!
            case .oled:      return Color(hex: "#F4F8FB")!
            case .mint:      return Color(hex: "#ECFDF5")!
            case .ocean:     return Color(hex: "#EFF6FF")!
            case .sepia:     return Color(hex: "#FBF4E4")!
            case .pride:     return Color(hex: "#FFF3F3")!
            case .trans:     return Color(hex: "#FFF1F5")!
            case .nonbinary: return Color(hex: "#FFFCE5")!
            }
        }
        switch self {
        case .purple:    return Color(hex: "#0F0C29")!
        case .twilight:   return Color(hex: "#13102E")!
        case .oled:      return .black
        case .mint:      return Color(hex: "#0A1F18")!
        case .ocean:     return Color(hex: "#0A1929")!
        case .sepia:     return Color(hex: "#1F1611")!
        case .pride:     return Color(hex: "#1A1020")!
        case .trans:     return Color(hex: "#21111B")!
        case .nonbinary: return Color(hex: "#141414")!
        }
    }

    fileprivate func backgroundSecondary(isDark: Bool) -> Color {
        if !isDark {
            switch self {
            case .oled: return Color(hex: "#FFFFFF")!
            default:    return Color(hex: "#FFFFFF")!
            }
        }
        switch self {
        case .purple:    return Color(hex: "#1A1535")!
        case .twilight:   return Color(hex: "#1F1A3A")!
        case .oled:      return Color(hex: "#0A0A0A")!
        case .mint:      return Color(hex: "#112B22")!
        case .ocean:     return Color(hex: "#112942")!
        case .sepia:     return Color(hex: "#2B1E14")!
        case .pride:     return Color(hex: "#26172D")!
        case .trans:     return Color(hex: "#2B1A24")!
        case .nonbinary: return Color(hex: "#1C1C1C")!
        }
    }

    fileprivate func backgroundGradient(isDark: Bool) -> LinearGradient {
        let top = backgroundPrimary(isDark: isDark)
        let bottom = backgroundSecondary(isDark: isDark)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    fileprivate func loginGradient(isDark: Bool) -> LinearGradient {
        if !isDark {
            return LinearGradient(
                colors: [backgroundPrimary(isDark: false),
                         accentLight(isDark: false).opacity(0.35),
                         backgroundSecondary(isDark: false)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [backgroundPrimary(isDark: true),
                     accent(isDark: true).opacity(0.35),
                     backgroundSecondary(isDark: true)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    fileprivate func textPrimary(isDark: Bool) -> Color {
        if isDark { return .white }
        switch self {
        case .ocean:     return Color(hex: "#0B1F3A")!
        case .mint:      return Color(hex: "#0B2A1E")!
        case .sepia:     return Color(hex: "#3A2410")!
        case .oled:      return Color(hex: "#0A0A0A")!
        default:         return Color(hex: "#1A1035")!
        }
    }
}

// MARK: - Client Settings (synced to server)
struct ClientSettings: Codable, Equatable {
    var themeMode: String
    var palette:   String

    static let empty = ClientSettings(themeMode: ThemeMode.system.rawValue,
                                      palette: Palette.purple.rawValue)

    init(themeMode: String, palette: String) {
        self.themeMode = themeMode
        self.palette = palette
    }

    init(from dict: [String: Any]) {
        self.themeMode = dict["theme_mode"] as? String ?? ThemeMode.system.rawValue
        self.palette   = dict["palette"]    as? String ?? Palette.purple.rawValue
    }

    func toDict() -> [String: Any] {
        ["theme_mode": themeMode, "palette": palette]
    }
}

// MARK: - ThemeManager
final class ThemeManager: ObservableObject {
    @Published var mode: ThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "sheaf_theme") }
    }

    @Published var palette: Palette {
        didSet { UserDefaults.standard.set(palette.rawValue, forKey: "sheaf_palette") }
    }

    init() {
        let rawMode = UserDefaults.standard.string(forKey: "sheaf_theme") ?? "system"
        mode = ThemeMode(rawValue: rawMode) ?? .system
        let rawPalette = UserDefaults.standard.string(forKey: "sheaf_palette") ?? "purple"
        palette = Palette(rawValue: rawPalette) ?? .purple
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

    /// Apply a palette received from the server without triggering a server save.
    func applyFromServer(palette newPalette: Palette) {
        guard newPalette != palette else { return }
        palette = newPalette
    }
}

// MARK: - Theme Colors
/// Use these everywhere instead of hardcoded hex values.
struct Theme {
    let isDark: Bool
    let palette: Palette

    init(isDark: Bool, palette: Palette = .purple) {
        self.isDark = isDark
        self.palette = palette
    }

    // Backgrounds
    var backgroundPrimary:   Color { palette.backgroundPrimary(isDark: isDark) }
    var backgroundSecondary: Color { palette.backgroundSecondary(isDark: isDark) }
    var backgroundCard:      Color { isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04) }
    var backgroundElevated:  Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06) }

    // Gradients
    var backgroundGradient: LinearGradient { palette.backgroundGradient(isDark: isDark) }
    var loginGradient:      LinearGradient { palette.loginGradient(isDark: isDark) }

    // Text
    var textPrimary:   Color { palette.textPrimary(isDark: isDark) }
    var textSecondary: Color { textPrimary.opacity(0.6) }
    var textTertiary:  Color { textPrimary.opacity(0.35) }

    // Borders & dividers
    var border:   Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }
    var divider:  Color { isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06) }

    // Accent
    var accent:       Color { palette.accent(isDark: isDark) }
    var accentLight:  Color { palette.accentLight(isDark: isDark) }
    var accentSoft:   Color { isDark ? accentLight.opacity(0.15) : accent.opacity(0.1) }

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
