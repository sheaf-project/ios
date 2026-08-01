import SwiftUI

// MARK: - AppearanceView

struct AppearanceView: View {
    @EnvironmentObject var store: SystemStore
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) var theme
    @AppStorage("quickSwitchPosition") private var quickSwitchPosition: QuickSwitchPosition = .belowFronters

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    modeSection
                    paletteSection
                    quickSwitchSection
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(Text("Appearance"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(theme.backgroundPrimary, for: .navigationBar)
    }

    // MARK: Mode

    private var modeSection: some View {
        VStack(spacing: 0) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                Button {
                    themeManager.mode = mode
                    store.saveClientSettings()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.icon)
                            .foregroundColor(themeManager.mode == mode ? theme.accentLight : theme.textTertiary)
                            .frame(width: 20)
                        Text(mode.label)
                            .font(.subheadline)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        if themeManager.mode == mode {
                            Image(systemName: "checkmark")
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(theme.accentLight)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                if mode != ThemeMode.allCases.last {
                    Divider().background(theme.divider).padding(.leading, 52)
                }
            }
        }
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
        .padding(.horizontal, 24)
    }

    // MARK: Palette

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Palette")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                ForEach(visiblePalettes, id: \.self) { palette in
                    PaletteTile(
                        palette: palette,
                        isSelected: themeManager.palette == palette,
                        accent: theme.accentLight
                    ) {
                        themeManager.palette = palette
                        store.saveClientSettings()
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Quick Switch

    private var quickSwitchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Switch")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(availablePositions, id: \.self) { position in
                    Button {
                        quickSwitchPosition = position
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: position.icon)
                                .foregroundColor(quickSwitchPosition == position ? theme.accentLight : theme.textTertiary)
                                .frame(width: 20)
                            Text(position.label)
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            if quickSwitchPosition == position {
                                Image(systemName: "checkmark")
                                    .font(.footnote).fontWeight(.semibold)
                                    .foregroundColor(theme.accentLight)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    if position != availablePositions.last {
                        Divider().background(theme.divider).padding(.leading, 52)
                    }
                }
            }
            .background(theme.backgroundCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.backgroundCard, lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }

    private var availablePositions: [QuickSwitchPosition] {
        if #available(iOS 26.1, *) {
            return QuickSwitchPosition.allCases
        }
        return QuickSwitchPosition.allCases.filter { $0 != .mergedWithTabBar }
    }

    private var visiblePalettes: [Palette] {
        // OLED's pure-black background only makes sense in dark mode.
        Palette.allCases.filter { !($0 == .oled && !theme.isDark) }
    }
}

// MARK: - Palette Tile

private struct PaletteTile: View {
    let palette: Palette
    let isSelected: Bool
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(Array(palette.swatch.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundColor(accent)
                    }
                }
                Text(palette.label)
                    .font(.footnote).fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
            .background(palette.swatchTileBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? accent : Color.white.opacity(0.06),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
