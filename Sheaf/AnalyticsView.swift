import SwiftUI
import Charts

// MARK: - AnalyticsView

struct AnalyticsView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var analytics: FrontingAnalytics?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var timeRange: GraphTimeRange = .month

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundPrimary.ignoresSafeArea()

                if isLoading && analytics == nil {
                    ProgressView().tint(theme.accentLight)
                } else if let analytics {
                    content(analytics)
                } else if let errorMessage {
                    errorState(errorMessage)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accentLight)
                }
            }
        }
        .task { await load() }
        .onChange(of: timeRange) {
            Task { await load() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    func content(_ data: FrontingAnalytics) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                timeRangePicker
                    .padding(.top, 8)

                let active = data.members.filter { $0.totalSeconds > 0 }

                if active.isEmpty {
                    noDataView
                } else {
                    summaryCards(active)
                    donutSection(active)
                    memberBreakdown(active)
                    hourOfDaySection(data)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .refreshable { await load() }
    }

    // MARK: - Time Range Picker

    var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(GraphTimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        timeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.subheadline).fontWeight(timeRange == range ? .bold : .medium)
                        .foregroundColor(timeRange == range ? .white : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(timeRange == range ? theme.accentLight : Color.clear)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }

    // MARK: - Summary Cards

    func summaryCards(_ active: [MemberFrontingStats]) -> some View {
        HStack(spacing: 12) {
            summaryCard(
                icon: "clock.fill",
                label: "Total Front Time",
                value: formatDuration(active.reduce(0) { $0 + $1.totalSeconds })
            )
            summaryCard(
                icon: "person.2.fill",
                label: "Active Members",
                value: "\(active.count)"
            )
        }
    }

    func summaryCard(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(theme.accentLight)
                Text(label)
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(theme.textSecondary)
            }
            Text(value)
                .font(.title3).fontWeight(.bold).fontDesign(.rounded)
                .foregroundColor(theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }

    // MARK: - Donut Chart

    func donutSection(_ stats: [MemberFrontingStats]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Distribution")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)

            HStack(spacing: 24) {
                FrontTimeDonut(stats: stats, members: store.members)
                    .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(stats.prefix(6)) { stat in
                        if let member = memberFor(stat) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(member.displayColor)
                                    .frame(width: 8, height: 8)
                                Text(member.displayName ?? member.name)
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundColor(theme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(String(format: "%.0f%%", stat.percentOfWindow * 100))
                                    .font(.caption2).fontWeight(.semibold)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(theme.backgroundCard)
            .cornerRadius(14)
        }
    }

    // MARK: - Member Breakdown

    func memberBreakdown(_ stats: [MemberFrontingStats]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)

            ForEach(stats) { stat in
                if let member = memberFor(stat) {
                    memberRow(member: member, stats: stat)
                }
            }
        }
    }

    func memberRow(member: Member, stats: MemberFrontingStats) -> some View {
        HStack(spacing: 12) {
            AvatarView(member: member, size: 36)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(member.displayName ?? member.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    if member.isCustomFront {
                        Text("custom")
                            .font(.caption2).fontWeight(.medium)
                            .foregroundColor(theme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.backgroundElevated)
                            .cornerRadius(4)
                    }
                    Spacer()
                    Text(formatDuration(stats.totalSeconds))
                        .font(.caption).fontWeight(.medium)
                        .foregroundColor(theme.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(member.displayColor.opacity(0.15))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(member.displayColor)
                            .frame(width: max(2, geo.size.width * CGFloat(stats.percentOfWindow)), height: 6)
                    }
                }
                .frame(height: 6)

                HStack(spacing: 16) {
                    Label("\(stats.sessionCount) sessions", systemImage: "arrow.triangle.swap")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                    Label("longest \(formatDuration(stats.longestSessionSeconds))", systemImage: "timer")
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(14)
    }

    // MARK: - Hour of Day

    func hourOfDaySection(_ data: FrontingAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity by Hour")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)

            let hourData = aggregateHourlyData(data)

            HourOfDayBarChart(hourData: hourData, accentColor: theme.accentLight, bgColor: theme.backgroundElevated)
                .frame(height: 120)
                .padding(16)
                .background(theme.backgroundCard)
                .cornerRadius(14)
        }
    }

    // MARK: - States

    var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundColor(theme.textTertiary)
            Text("No fronting data for this period")
                .font(.body).fontWeight(.medium).fontDesign(.rounded)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundColor(theme.textTertiary)
            Text("No analytics available")
                .font(.body).fontWeight(.medium).fontDesign(.rounded)
                .foregroundColor(theme.textTertiary)
        }
    }

    func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(theme.warning)
            Text(message)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(theme.accentLight)
        }
        .padding()
    }

    // MARK: - Helpers

    func memberFor(_ stats: MemberFrontingStats) -> Member? {
        store.members.first { $0.id == stats.memberID }
    }

    func formatDuration(_ seconds: Int) -> String {
        let d = seconds / 86400
        let h = (seconds % 86400) / 3600
        let m = (seconds % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }

    func aggregateHourlyData(_ data: FrontingAnalytics) -> [Int] {
        var hours = [Int](repeating: 0, count: 24)
        for stat in data.members where stat.totalSeconds > 0 {
            for (i, secs) in stat.hourOfDaySeconds.enumerated() where i < 24 {
                hours[i] += secs
            }
        }
        return hours
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            analytics = try await store.loadFrontingAnalytics(days: timeRange.days)
        } catch {
            if analytics == nil {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

// MARK: - Front Time Donut

struct FrontTimeDonut: View {
    @Environment(\.theme) var theme
    let stats: [MemberFrontingStats]
    let members: [Member]

    private let lineWidth: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.backgroundElevated, lineWidth: lineWidth)

            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                Circle()
                    .trim(from: seg.start, to: seg.end)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text("\(stats.count)")
                    .font(.title2).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundColor(theme.textPrimary)
                Text(stats.count == 1 ? "member" : "members")
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    private var segments: [(start: CGFloat, end: CGFloat, color: Color)] {
        let total = stats.reduce(0) { $0 + $1.totalSeconds }
        guard total > 0 else { return [] }
        var result: [(start: CGFloat, end: CGFloat, color: Color)] = []
        var current: CGFloat = 0
        let gap: CGFloat = stats.count > 1 ? 0.004 : 0
        for stat in stats {
            let fraction = CGFloat(stat.totalSeconds) / CGFloat(total)
            guard fraction > 0.001 else { continue }
            let member = members.first { $0.id == stat.memberID }
            let color = member?.displayColor ?? .purple
            result.append((start: current + gap, end: current + fraction - gap, color: color))
            current += fraction
        }
        return result
    }
}

// MARK: - Hour of Day Bar Chart

struct HourOfDayBarChart: View {
    @Environment(\.theme) var theme
    let hourData: [Int]
    let accentColor: Color
    let bgColor: Color

    var body: some View {
        let maxVal = hourData.max() ?? 1

        VStack(spacing: 6) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        let value = hourData[hour]
                        let height = maxVal > 0
                            ? geo.size.height * CGFloat(value) / CGFloat(maxVal)
                            : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(value > 0 ? accentColor : bgColor)
                            .frame(height: max(2, height))
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach([0, 6, 12, 18, 23], id: \.self) { hour in
                    Text(hourLabel(hour))
                        .font(.caption2)
                        .foregroundColor(theme.textTertiary)
                    if hour != 23 { Spacer() }
                }
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return formatter.string(from: date).lowercased()
    }
}
