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
    var success: Color { Color(hex: "#4ADE80")! }
    var danger:  Color { Color(hex: "#F87171")! }
    var warning: Color { Color(hex: "#FBBF24")! }

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
/// Renders a markdown string with inline styling (bold, italic, links, code).
/// Falls back to plain text if parsing fails.
struct MarkdownText: View {
    let markdown: String
    let color: Color

    init(_ markdown: String, color: Color = .primary) {
        self.markdown = markdown
        self.color = color
    }

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(applyColor(attributed))
        } else {
            Text(markdown)
                .foregroundColor(color)
        }
    }

    private func applyColor(_ string: AttributedString) -> AttributedString {
        var result = string
        result.foregroundColor = color
        return result
    }
}
