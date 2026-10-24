import SwiftUI

// MARK: - Slider spec

/// The shape of a slider custom field, read from its options with the
/// server's defaults filled in. Labeled is a 0 to 100 position between two
/// words and reads as a percentage; numeric is a quantity in the owner's
/// own range with an optional step and unit.
struct SliderSpec: Equatable {
    static let modeLabeled = "labeled"
    static let modeNumeric = "numeric"

    var isNumeric: Bool
    var min: Double
    var max: Double
    var step: Double?
    var unit: String?
    var labels: SliderLabels
    var gradient: [String]?

    static let labeled = SliderSpec(isNumeric: false, min: 0, max: 100, step: nil, unit: nil,
                                    labels: SliderLabels(), gradient: nil)

    init(isNumeric: Bool, min: Double, max: Double, step: Double?, unit: String?,
         labels: SliderLabels, gradient: [String]?) {
        self.isNumeric = isNumeric
        self.min = min
        self.max = max
        self.step = step
        self.unit = unit
        self.labels = labels
        self.gradient = gradient
    }

    init(options: CustomFieldOptions?) {
        let numeric = options?.mode == Self.modeNumeric
        let lo = numeric ? (options?.min ?? 0) : 0
        let hi = numeric ? (options?.max ?? 10) : 100
        isNumeric = numeric
        min = hi > lo ? lo : 0
        max = hi > lo ? hi : (numeric ? 10 : 100)
        step = (options?.step).flatMap { $0 > 0 ? $0 : nil }
        unit = numeric ? (options?.unit).flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } : nil
        labels = options?.labels ?? SliderLabels()
        gradient = (options?.gradient).flatMap { $0.count >= 2 ? $0 : nil }
    }

    var span: Double { max - min }
    var midpoint: Double { min + span / 2 }

    var hasAnyLabel: Bool {
        [labels.left, labels.center, labels.right].contains { !($0 ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// The options body the server expects. Nil keys are omitted, which is
    /// how a label, unit or gradient is cleared.
    var options: CustomFieldOptions {
        func clean(_ s: String?) -> String? {
            let t = s?.trimmingCharacters(in: .whitespaces) ?? ""
            return t.isEmpty ? nil : t
        }
        let trimmed = SliderLabels(left: clean(labels.left), center: clean(labels.center), right: clean(labels.right))
        let stops = (gradient?.count ?? 0) >= 2 ? gradient : nil
        if isNumeric {
            return CustomFieldOptions(mode: Self.modeNumeric, min: min, max: max, step: step,
                                      unit: clean(unit), labels: trimmed, gradient: stops)
        }
        return CustomFieldOptions(mode: Self.modeLabeled, labels: trimmed, gradient: stops)
    }

    /// Why a numeric spec cannot be saved, or nil when it can.
    var problem: String? {
        guard isNumeric else { return nil }
        if max <= min { return String(localized: "Max has to be more than min.") }
        if let step {
            if step <= 0 { return String(localized: "Step has to be more than zero.") }
            if step > span { return String(localized: "Step cannot be bigger than the range.") }
        }
        return nil
    }

    /// "62%" or "172.5 cm", the same reading the public profile serves.
    func format(_ value: Double) -> String {
        let shown = tidyNumber(value)
        if !isNumeric { return "\(shown)%" }
        if let unit { return "\(shown) \(unit)" }
        return shown
    }

    func fraction(_ value: Double) -> Double {
        guard span > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, (value - min) / span))
    }

    /// Values land on the step grid, or on the two decimals the reading
    /// shows, so the number stored is the number shown.
    func snap(_ value: Double) -> Double {
        var x: Double
        if let step, step > 0 {
            x = min + ((value - min) / step).rounded() * step
        } else {
            x = (value * 100).rounded() / 100
        }
        x = Swift.min(max, Swift.max(min, x))
        return x
    }
}

/// Trailing zeros are noise on a reading: 3.0 shows as 3, 2.5 stays 2.5.
func tidyNumber(_ value: Double) -> String {
    let rounded = (value * 100).rounded() / 100
    if abs(rounded - rounded.rounded()) < 1e-9 { return String(Int64(rounded)) }
    return String(rounded)
}

/// A slider value out of the type-erased wire value, or nil when unset.
func sliderNumber(_ value: Any?) -> Double? {
    switch value {
    case let d as Double: return d.isFinite ? d : nil
    case let i as Int:    return Double(i)
    default:              return nil
    }
}

func formatSliderValue(_ value: Any?, options: CustomFieldOptions?) -> String {
    guard let n = sliderNumber(value) else { return "" }
    return SliderSpec(options: options).format(n)
}

// MARK: - Gradient presets

struct SliderGradientPreset: Identifiable, Equatable {
    let id: String
    let label: String
    let stops: [String]?

    static let none = SliderGradientPreset(id: "none", label: String(localized: "No gradient"), stops: nil)
    static let custom = SliderGradientPreset(id: "custom", label: String(localized: "Custom colours"), stops: ["#5B92C9", "#E08D5E"])

    static let all: [SliderGradientPreset] = [
        .none,
        SliderGradientPreset(id: "cool-warm",    label: String(localized: "Cool to warm"),    stops: ["#5B92C9", "#E08D5E"]),
        SliderGradientPreset(id: "calm-intense", label: String(localized: "Calm to intense"), stops: ["#7BAA7E", "#D6534D"]),
        SliderGradientPreset(id: "sad-happy",    label: String(localized: "Low to high"),     stops: ["#5479AE", "#E4C44F"]),
        SliderGradientPreset(id: "soft-hard",    label: String(localized: "Soft to hard"),    stops: ["#F4EBD8", "#A89B8C", "#3A2E4D"]),
        SliderGradientPreset(id: "day-night",    label: String(localized: "Day to night"),    stops: ["#F4D86E", "#1E2444"]),
        SliderGradientPreset(id: "rose-dusk",    label: String(localized: "Rose dusk"),       stops: ["#F4B89E", "#D17A8E", "#5B4378"]),
        SliderGradientPreset(id: "sage-meadow",  label: String(localized: "Sage meadow"),     stops: ["#C5D9B5", "#4A6B47"]),
        SliderGradientPreset(id: "monochrome",   label: String(localized: "Monochrome"),      stops: ["#E4DEEC", "#3A2E4D"]),
        .custom,
    ]

    /// The preset id is not stored; it is worked out from the stops.
    static func matching(_ stops: [String]?) -> SliderGradientPreset {
        guard let stops, stops.count >= 2 else { return .none }
        let upper = stops.map { $0.uppercased() }
        return all.first { $0.stops?.map { $0.uppercased() } == upper } ?? .custom
    }
}

// MARK: - Track

struct SliderTrack: View {
    @Environment(\.theme) var theme
    let fraction: Double
    let gradient: [String]?
    var dimmed = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.backgroundElevated)
                if let gradient, gradient.count >= 2 {
                    Capsule().fill(LinearGradient(
                        colors: gradient.compactMap { Color(hex: $0) },
                        startPoint: .leading, endPoint: .trailing))
                } else {
                    Capsule().fill(theme.accentLight)
                        .frame(width: Swift.max(8, geo.size.width * fraction))
                }
            }
        }
        .frame(height: 8)
        .opacity(dimmed ? 0.6 : 1)
    }
}

/// Track plus marker plus reading. Used for the settings preview.
struct SliderReadout: View {
    @Environment(\.theme) var theme
    let value: Double
    let spec: SliderSpec

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    SliderTrack(fraction: spec.fraction(value), gradient: spec.gradient)
                        .frame(maxHeight: .infinity)
                    Circle()
                        .fill(theme.textPrimary)
                        .frame(width: 14, height: 14)
                        .offset(x: (geo.size.width - 14) * spec.fraction(value))
                }
            }
            .frame(height: 14)
            Text(spec.format(value))
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(theme.textPrimary)
                .frame(width: 72, alignment: .trailing)
        }
    }
}

struct SliderEndLabels: View {
    @Environment(\.theme) var theme
    let spec: SliderSpec

    var body: some View {
        if spec.hasAnyLabel {
            HStack {
                Text(spec.labels.left ?? "").frame(maxWidth: .infinity, alignment: .leading)
                if let c = spec.labels.center, !c.isEmpty {
                    Text(c).frame(maxWidth: .infinity, alignment: .center)
                }
                Text(spec.labels.right ?? "").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption)
            .foregroundColor(theme.textSecondary)
            .lineLimit(1)
        } else if spec.isNumeric {
            HStack {
                Text(spec.format(spec.min))
                Spacer()
                Text(spec.format(spec.max))
            }
            .font(.caption)
            .foregroundColor(theme.textSecondary)
        }
    }
}

// MARK: - Member editor control

struct SliderInput: View {
    @Environment(\.theme) var theme
    let value: Double?
    let spec: SliderSpec
    let onChange: (Double?) -> Void

    private let handle: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                GeometryReader { geo in
                    let shown = value ?? spec.midpoint
                    let x = (geo.size.width - handle) * spec.fraction(shown)
                    ZStack(alignment: .leading) {
                        SliderTrack(fraction: spec.fraction(shown), gradient: spec.gradient, dimmed: value == nil)
                            .frame(maxHeight: .infinity)
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            .frame(width: handle, height: handle)
                            .offset(x: x)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                        let width = Swift.max(1, geo.size.width - handle)
                        let f = Swift.min(1, Swift.max(0, (g.location.x - handle / 2) / width))
                        onChange(spec.snap(spec.min + f * spec.span))
                    })
                }
                .frame(height: handle)

                Text(value.map(spec.format) ?? String(localized: "not set"))
                    .font(.subheadline).fontWeight(value == nil ? .regular : .medium)
                    .foregroundColor(value == nil ? theme.textTertiary : theme.textPrimary)
                    .frame(width: 72, alignment: .trailing)

                if value != nil {
                    Button { onChange(nil) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            SliderEndLabels(spec: spec)
        }
        .padding(12).background(theme.backgroundCard).cornerRadius(12)
    }
}

// MARK: - Settings editor

struct SliderOptionsEditor: View {
    @Environment(\.theme) var theme
    @Binding var spec: SliderSpec

    @State private var minText = ""
    @State private var maxText = ""
    @State private var stepText = ""

    private var preset: SliderGradientPreset { SliderGradientPreset.matching(spec.gradient) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Kind")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
            kindRow(String(localized: "Between two labels (0 to 100)"), selected: !spec.isNumeric) {
                spec.isNumeric = false
                spec.min = 0; spec.max = 100; spec.step = nil; spec.unit = nil
                syncTexts()
            }
            kindRow(String(localized: "A number with a range"), selected: spec.isNumeric) {
                spec.isNumeric = true
                spec.min = 0; spec.max = 10; spec.step = nil
                syncTexts()
            }

            if spec.isNumeric {
                HStack(spacing: 8) {
                    numberBox("Min", text: $minText) { spec.min = Double($0) ?? 0 }
                    numberBox("Max", text: $maxText) { spec.max = Double($0) ?? 0 }
                }
                HStack(spacing: 8) {
                    numberBox("Step", text: $stepText, placeholder: String(localized: "any")) {
                        spec.step = Double($0)
                    }
                    textBox("Unit", text: Binding(
                        get: { spec.unit ?? "" },
                        set: { spec.unit = $0.isEmpty ? nil : String($0.prefix(12)) }
                    ), placeholder: String(localized: "e.g. cm"))
                }
                if let problem = spec.problem {
                    Text(problem)
                        .font(.caption)
                        .foregroundColor(theme.danger)
                }
            }

            labelBox(String(localized: "Left label"),
                     placeholder: spec.isNumeric ? String(localized: "optional") : String(localized: "e.g. Calm"),
                     text: Binding(get: { spec.labels.left ?? "" }, set: { spec.labels.left = capped($0) }))
            labelBox(String(localized: "Centre label"), placeholder: String(localized: "optional"),
                     text: Binding(get: { spec.labels.center ?? "" }, set: { spec.labels.center = capped($0) }))
            labelBox(String(localized: "Right label"),
                     placeholder: spec.isNumeric ? String(localized: "optional") : String(localized: "e.g. Intense"),
                     text: Binding(get: { spec.labels.right ?? "" }, set: { spec.labels.right = capped($0) }))

            Text("Track colours")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
            Menu {
                ForEach(SliderGradientPreset.all) { p in
                    Button {
                        spec.gradient = p.id == "custom" ? (spec.gradient ?? p.stops) : p.stops
                    } label: {
                        if p.id == preset.id {
                            Label(p.label, systemImage: "checkmark")
                        } else {
                            Text(p.label)
                        }
                    }
                }
            } label: {
                HStack {
                    if let stops = preset.id == "custom" ? spec.gradient : preset.stops {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: stops.compactMap { Color(hex: $0) },
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: 40, height: 12)
                    }
                    Text(preset.label)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }
                .padding(12).background(theme.backgroundCard).cornerRadius(12)
            }

            if preset.id == "custom", let stops = spec.gradient {
                customStops(stops)
            }

            Text("Preview")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
            VStack(spacing: 6) {
                SliderReadout(value: spec.min + spec.span * 0.62, spec: spec)
                SliderEndLabels(spec: spec)
            }
            .padding(12).background(theme.backgroundCard).cornerRadius(12)
        }
        .onAppear(perform: syncTexts)
    }

    private func capped(_ s: String) -> String? {
        s.isEmpty ? nil : String(s.prefix(50))
    }

    private func syncTexts() {
        minText = tidyNumber(spec.min)
        maxText = tidyNumber(spec.max)
        stepText = spec.step.map(tidyNumber) ?? ""
    }

    private func kindRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? theme.accentLight : theme.textTertiary)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func numberBox(_ title: LocalizedStringKey, text: Binding<String>, placeholder: String = "0",
                           commit: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .padding(10).background(theme.backgroundCard).cornerRadius(10)
                .foregroundColor(theme.textPrimary)
                .onChange(of: text.wrappedValue) { _, new in commit(new.trimmingCharacters(in: .whitespaces)) }
        }
    }

    private func textBox(_ title: LocalizedStringKey, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            TextField(placeholder, text: text)
                .autocorrectionDisabled()
                .padding(10).background(theme.backgroundCard).cornerRadius(10)
                .foregroundColor(theme.textPrimary)
        }
    }

    private func labelBox(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            TextField(placeholder, text: text)
                .padding(10).background(theme.backgroundCard).cornerRadius(10)
                .foregroundColor(theme.textPrimary)
        }
    }

    private func customStops(_ stops: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(stops.enumerated()), id: \.offset) { i, hex in
                HStack(spacing: 10) {
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: hex) ?? .gray },
                        set: { c in
                            var g = stops
                            guard i < g.count else { return }
                            g[i] = c.toHex()
                            spec.gradient = g
                        }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    Text(String(format: String(localized: "Colour %d"), i + 1))
                        .font(.subheadline)
                        .foregroundColor(theme.textPrimary)
                    Text(hex.uppercased())
                        .font(.caption.monospaced())
                        .foregroundColor(theme.textTertiary)
                    Spacer()
                    if stops.count > 2 {
                        Button {
                            var g = stops
                            g.remove(at: i)
                            spec.gradient = g
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if stops.count < 8 {
                Button {
                    spec.gradient = stops + ["#888888"]
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add colour")
                    }
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(theme.accentLight)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
