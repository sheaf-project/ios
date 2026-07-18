import SwiftUI

// MARK: - Relationship Graph
struct RelationshipGraphView: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.theme) var theme
    @Environment(\.apiBaseURL) private var baseURL
    @Environment(\.apiAccessToken) private var accessToken

    private enum GraphScope: String, CaseIterable {
        case members
        case groups
    }

    @State private var scope: GraphScope = .members
    @State private var reloadToken = 0
    @State private var graph: RelationshipGraph?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var positions: [CGPoint] = []
    @State private var nodeIndex: [String: Int] = [:]
    @State private var edgeFans: [String: EdgeFan] = [:]
    @State private var avatars: [String: UIImage] = [:]

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseScale: CGFloat = 1
    @State private var baseOffset: CGSize = .zero
    @State private var canvasSize: CGSize = .zero

    private let nodeRadius: CGFloat = 20

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView().tint(theme.accentLight)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { reloadToken += 1 }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accentLight)
                }
                .padding(24)
            } else if let graph, !graph.nodes.isEmpty {
                graphCanvas(graph)
            } else {
                Text(scope == .groups
                     ? "No group relationships to show yet."
                     : "No member relationships to show yet.")
                    .font(.subheadline)
                    .foregroundColor(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $scope) {
                    Text("Members").tag(GraphScope.members)
                    Text("Groups").tag(GraphScope.groups)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .task(id: "\(scope.rawValue)-\(reloadToken)") {
            await load()
        }
    }

    // MARK: - Canvas

    @ViewBuilder
    private func graphCanvas(_ graph: RelationshipGraph) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    draw(graph, in: context, size: size)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: baseOffset.width + value.translation.width,
                                height: baseOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in baseOffset = offset }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = (baseScale * value).clamped(to: 0.2...5)
                        }
                        .onEnded { _ in baseScale = scale }
                )

                Text("Pinch to zoom, drag to pan.")
                    .font(.caption2)
                    .foregroundColor(theme.textTertiary)
                    .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    fit()
                } label: {
                    Image(systemName: "scope")
                        .font(.body)
                        .foregroundColor(theme.accentLight)
                        .padding(12)
                        .background(Circle().fill(theme.backgroundCard))
                }
                .accessibilityLabel("Recentre")
                .padding(16)
            }
            .onAppear { canvasSize = geo.size; fit() }
            .onChange(of: geo.size) { _, s in canvasSize = s; fit() }
        }
    }

    private func draw(_ graph: RelationshipGraph, in context: GraphicsContext, size: CGSize) {
        let n = graph.nodes.count
        guard positions.count == n, n > 0 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        func screen(_ i: Int) -> CGPoint {
            CGPoint(x: center.x + offset.width + positions[i].x * scale,
                    y: center.y + offset.height + positions[i].y * scale)
        }

        let edgeColor = theme.border

        for e in graph.edges {
            guard let s = nodeIndex[e.sourceID], let t = nodeIndex[e.targetID], s != t else { continue }
            let a = screen(s)
            let b = screen(t)
            let fan = edgeFans[e.id] ?? EdgeFan(curve: 0, labelT: 0)

            let pa = screen(min(s, t))
            let pb = screen(max(s, t))
            let dxp = pb.x - pa.x
            let dyp = pb.y - pa.y
            let plen = max(1, sqrt(dxp * dxp + dyp * dyp))
            let perp = CGPoint(x: -dyp / plen, y: dxp / plen)
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            let control = CGPoint(x: mid.x + perp.x * fan.curve, y: mid.y + perp.y * fan.curve)

            var path = Path()
            path.move(to: a)
            if fan.curve == 0 {
                path.addLine(to: b)
            } else {
                path.addQuadCurve(to: b, control: control)
            }
            context.stroke(path, with: .color(edgeColor), lineWidth: 1)

            let labelT = (0.5 + fan.labelT).clamped(to: 0.2...0.8)
            drawEdgeLabel(e, at: quadPoint(a, control, b, labelT), in: context)

            if e.directed {
                let inDir = fan.curve == 0
                    ? CGPoint(x: b.x - a.x, y: b.y - a.y)
                    : CGPoint(x: b.x - control.x, y: b.y - control.y)
                drawArrowhead(at: b, inDir: inDir, in: context, color: edgeColor)
            }
        }

        for (i, node) in graph.nodes.enumerated() {
            let p = screen(i)
            let color = Color(hex: node.color ?? "") ?? fallbackNodeColors[i % fallbackNodeColors.count]
            let rect = CGRect(x: p.x - nodeRadius, y: p.y - nodeRadius,
                              width: nodeRadius * 2, height: nodeRadius * 2)
            if let img = avatars[node.id] {
                var layer = context
                layer.clip(to: Path(ellipseIn: rect))
                let side = min(img.size.width, img.size.height)
                let f = (nodeRadius * 2) / max(1, side)
                let drawSize = CGSize(width: img.size.width * f, height: img.size.height * f)
                layer.draw(
                    Image(uiImage: img),
                    in: CGRect(x: p.x - drawSize.width / 2, y: p.y - drawSize.height / 2,
                               width: drawSize.width, height: drawSize.height)
                )
                context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2)
            } else {
                context.fill(Path(ellipseIn: rect), with: .color(color))
                let initial = node.name.trimmingCharacters(in: .whitespaces).first.map(String.init)?.uppercased() ?? "?"
                let resolved = context.resolve(
                    Text(initial)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                )
                context.draw(resolved, at: p, anchor: .center)
            }

            let name = context.resolve(
                Text(node.name)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textPrimary)
            )
            context.draw(name, at: CGPoint(x: p.x, y: p.y + nodeRadius + 2), anchor: .top)
        }
    }

    private func drawEdgeLabel(_ edge: RelationshipGraphEdge, at point: CGPoint, in context: GraphicsContext) {
        let resolved = context.resolve(
            Text(edge.sourceLabel)
                .font(.system(size: 10))
                .foregroundColor(theme.textSecondary)
        )
        let sz = resolved.measure(in: CGSize(width: 300, height: 50))
        let rect = CGRect(x: point.x - sz.width / 2 - 3, y: point.y - sz.height / 2 - 1,
                          width: sz.width + 6, height: sz.height + 2)
        context.fill(Path(roundedRect: rect, cornerRadius: 3),
                     with: .color(theme.backgroundPrimary.opacity(0.85)))
        context.draw(resolved, at: point, anchor: .center)
    }

    private func drawArrowhead(at target: CGPoint, inDir: CGPoint, in context: GraphicsContext, color: Color) {
        let len = sqrt(inDir.x * inDir.x + inDir.y * inDir.y)
        guard len >= 1 else { return }
        let ux = inDir.x / len
        let uy = inDir.y / len
        let tip = CGPoint(x: target.x - ux * nodeRadius, y: target.y - uy * nodeRadius)
        let size: CGFloat = 8
        let backX = tip.x - ux * size
        let backY = tip.y - uy * size
        let half = size * 0.5
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: backX - uy * half, y: backY + ux * half))
        path.addLine(to: CGPoint(x: backX + uy * half, y: backY - ux * half))
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    private func quadPoint(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let mt = 1 - t
        return CGPoint(
            x: a.x * mt * mt + control.x * 2 * mt * t + b.x * t * t,
            y: a.y * mt * mt + control.y * 2 * mt * t + b.y * t * t
        )
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        errorMessage = nil
        graph = nil
        positions = []
        avatars = [:]
        scale = 1
        offset = .zero
        baseScale = 1
        baseOffset = .zero
        guard let api = store.api else {
            isLoading = false
            errorMessage = "Couldn't load the graph."
            return
        }
        do {
            let g = try await api.getRelationshipGraph(scope: scope.rawValue)
            graph = g
            nodeIndex = Dictionary(uniqueKeysWithValues: g.nodes.enumerated().map { ($1.id, $0) })
            edgeFans = computeFans(g)
            isLoading = false
            async let avatarLoad: Void = loadAvatars(g)
            async let layout: Void = runLayout(g)
            _ = await (avatarLoad, layout)
        } catch {
            if !Task.isCancelled {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func computeFans(_ g: RelationshipGraph) -> [String: EdgeFan] {
        var byPair: [String: [RelationshipGraphEdge]] = [:]
        for e in g.edges {
            guard let s = nodeIndex[e.sourceID], let t = nodeIndex[e.targetID], s != t else { continue }
            byPair["\(min(s, t))-\(max(s, t))", default: []].append(e)
        }
        var out: [String: EdgeFan] = [:]
        for group in byPair.values {
            let m = group.count
            for (k, e) in group.enumerated() {
                if m == 1 {
                    out[e.id] = EdgeFan(curve: 0, labelT: 0)
                } else {
                    let spread = CGFloat(k) - CGFloat(m - 1) / 2
                    out[e.id] = EdgeFan(curve: spread * 34, labelT: spread * 0.16)
                }
            }
        }
        return out
    }

    private func loadAvatars(_ g: RelationshipGraph) async {
        for node in g.nodes {
            guard !Task.isCancelled,
                  let url = resolveAvatarURL(node.avatarURL, baseURL: baseURL) else { continue }
            var request = URLRequest(url: url)
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            request.setValue("Sheaf iOS/\(version)", forHTTPHeaderField: "User-Agent")
            if node.avatarURL?.hasPrefix("/") == true {
                if !accessToken.isEmpty {
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                }
                if let cfID = KeychainHelper.get(key: "sheaf_cf_client_id"), !cfID.isEmpty,
                   let cfSecret = KeychainHelper.get(key: "sheaf_cf_client_secret"), !cfSecret.isEmpty {
                    request.setValue(cfID, forHTTPHeaderField: "CF-Access-Client-Id")
                    request.setValue(cfSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
                }
            }
            if let img = await AvatarImageCache.shared.fetch(request: request) {
                avatars[node.id] = img
            }
        }
    }

    // MARK: - Force-directed layout

    private func runLayout(_ g: RelationshipGraph) async {
        let n = g.nodes.count
        guard n > 0 else { return }
        let edges: [(Int, Int)] = g.edges.compactMap { e in
            guard let s = nodeIndex[e.sourceID], let t = nodeIndex[e.targetID], s != t else { return nil }
            return (s, t)
        }

        var pts = [CGPoint](repeating: .zero, count: n)
        let r0 = 120 + 30 * sqrt(CGFloat(n))
        for i in 0..<n {
            let a = 2 * .pi * CGFloat(i) / CGFloat(max(1, n))
            pts[i] = CGPoint(x: r0 * cos(a), y: r0 * sin(a))
        }
        var vx = [CGFloat](repeating: 0, count: n)
        var vy = [CGFloat](repeating: 0, count: n)
        positions = pts

        let k: CGFloat = 150 // ideal edge length
        let kRep = k * k
        var alpha: CGFloat = 1
        var steps = 0
        while alpha > 0.02, steps < 600, !Task.isCancelled {
            for i in 0..<n {
                var fx: CGFloat = 0
                var fy: CGFloat = 0
                for j in 0..<n where j != i {
                    var dx = pts[i].x - pts[j].x
                    var dy = pts[i].y - pts[j].y
                    var d2 = dx * dx + dy * dy
                    if d2 < 0.01 {
                        dx = CGFloat(i - j) * 0.1
                        dy = 0.1
                        d2 = dx * dx + dy * dy
                    }
                    let d = sqrt(d2)
                    let f = kRep / d2
                    fx += dx / d * f
                    fy += dy / d * f
                }
                fx -= pts[i].x * 0.08
                fy -= pts[i].y * 0.08
                vx[i] = (vx[i] + fx) * 0.85
                vy[i] = (vy[i] + fy) * 0.85
            }
            for (s, t) in edges {
                let dx = pts[t].x - pts[s].x
                let dy = pts[t].y - pts[s].y
                let d = max(1, sqrt(dx * dx + dy * dy))
                let f = (d - k) * 0.02
                let ux = dx / d * f
                let uy = dy / d * f
                vx[s] += ux
                vy[s] += uy
                vx[t] -= ux
                vy[t] -= uy
            }
            let cap = 40 * alpha
            for i in 0..<n {
                let vlen = sqrt(vx[i] * vx[i] + vy[i] * vy[i])
                let s = vlen > cap ? cap / vlen : 1
                pts[i].x += vx[i] * s
                pts[i].y += vy[i] * s
            }
            alpha *= 0.99
            steps += 1
            positions = pts
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
        fit()
    }

    private func fit() {
        guard !positions.isEmpty, canvasSize != .zero else { return }
        var maxR: CGFloat = 1
        for p in positions {
            maxR = max(maxR, sqrt(p.x * p.x + p.y * p.y))
        }
        let half = min(canvasSize.width, canvasSize.height) / 2
        var s = (half - 80) / (maxR + 1)
        if let spacing = typicalSpacing() {
            s = max(s, 64 / spacing)
        }
        scale = s.clamped(to: 0.2...4)
        offset = .zero
        baseScale = scale
        baseOffset = .zero
    }

    private func typicalSpacing() -> CGFloat? {
        let n = positions.count
        guard n > 1 else { return nil }
        var dists = [CGFloat]()
        dists.reserveCapacity(n)
        for i in 0..<n {
            var best = CGFloat.greatestFiniteMagnitude
            for j in 0..<n where j != i {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                best = min(best, dx * dx + dy * dy)
            }
            dists.append(sqrt(best))
        }
        let sorted = dists.sorted()
        let median = sorted[n / 2]
        return median > 0 ? median : nil
    }
}

private struct EdgeFan {
    let curve: CGFloat
    let labelT: CGFloat
}

private let fallbackNodeColors: [Color] = [
    Color(hex: "#8B5CF6") ?? .purple,
    Color(hex: "#3B82F6") ?? .blue,
    Color(hex: "#10B981") ?? .green,
    Color(hex: "#F59E0B") ?? .orange,
    Color(hex: "#EF4444") ?? .red,
    Color(hex: "#EC4899") ?? .pink,
    Color(hex: "#14B8A6") ?? .teal,
    Color(hex: "#6366F1") ?? .indigo,
]

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
