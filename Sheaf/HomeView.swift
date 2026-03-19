import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: SystemStore
    @State private var showSwitchSheet = false
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#0F0C29") ?? .black,
                         Color(hex: "#1A1535") ?? .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Right Now")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if let since = store.oldestCurrentFront?.startedAt {
                                Text("Since \(since.formatted(date: .omitted, time: .shortened))")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        Spacer()
                        Button {
                            Task { await refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Fronting card(s)
                    if store.isLoading && store.currentFronts.isEmpty {
                        FrontingSkeletonView()
                    } else if store.frontingMembers.isEmpty {
                        NoOneFrontingCard()
                    } else {
                        ForEach(store.frontingMembers) { member in
                            FrontingMemberCard(member: member)
                                .padding(.horizontal, 24)
                        }
                    }



                    // Quick switch section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Switch")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                Spacer().frame(width: 12)
                                ForEach(store.members.prefix(8)) { member in
                                    QuickSwitchChip(member: member) {
                                        Task { await store.switchFronting(to: [member.id]) }
                                    }
                                }
                                Button {
                                    showSwitchSheet = true
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                                .frame(width: 52, height: 52)
                                            Image(systemName: "plus")
                                                .foregroundColor(.white.opacity(0.5))
                                                .font(.system(size: 18))
                                        }
                                        Text("More")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                                Spacer().frame(width: 12)
                            }
                        }
                    }

                    Spacer().frame(height: 80)
                }
            }
        }
        .sheet(isPresented: $showSwitchSheet) {
            SwitchFrontingSheet()
                .environmentObject(store)
        }
    }

    func refresh() async {
        isRefreshing = true
        store.loadAll()
        try? await Task.sleep(nanoseconds: 800_000_000)
        isRefreshing = false
    }
}

// MARK: - Fronting Member Card
struct FrontingMemberCard: View {
    let member: Member

    var body: some View {
        HStack(spacing: 16) {
            AvatarView(member: member, size: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(member.displayName ?? member.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let pronouns = member.pronouns, !pronouns.isEmpty {
                    Text(pronouns)
                        .font(.system(size: 13))
                        .foregroundColor(member.displayColor.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(member.displayColor.opacity(0.15))
                        .cornerRadius(8)
                }


            }

            Spacer()

            // Fronting indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: "#4ADE80")!)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color(hex: "#4ADE80")!.opacity(0.8), radius: 4)
                Text("front")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#4ADE80")!)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [member.displayColor.opacity(0.18),
                         member.displayColor.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(member.displayColor.opacity(0.3), lineWidth: 1.5)
        )
    }
}

// MARK: - No One Fronting
struct NoOneFrontingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.25))
            Text("No one is fronting")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Text("Use Quick Switch below to set who's fronting")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 24)
    }
}

// MARK: - Quick Switch Chip
struct QuickSwitchChip: View {
    let member: Member
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                AvatarView(member: member, size: 52)
                Text(member.displayName ?? member.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                    .frame(width: 64)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Skeleton
struct FrontingSkeletonView: View {
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.06))
            .frame(height: 110)
            .padding(.horizontal, 24)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0),
                                     Color.white.opacity(0.06),
                                     Color.white.opacity(0)],
                            startPoint: shimmer ? .topLeading : .bottomTrailing,
                            endPoint: shimmer ? .bottomTrailing : .topLeading
                        )
                    )
                    .padding(.horizontal, 24)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Switch Fronting Sheet
struct SwitchFrontingSheet: View {
    @EnvironmentObject var store: SystemStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedIDs: Set<String> = []
    @State private var note = ""
    @State private var isSwitching = false

    var body: some View {
        ZStack {
            Color(hex: "#0F0C29")!.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                HStack {
                    Text("Switch Fronting")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Text("Select who is fronting")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.members) { member in
                            MemberSelectRow(member: member, isSelected: selectedIDs.contains(member.id)) {
                                if selectedIDs.contains(member.id) {
                                    selectedIDs.remove(member.id)
                                } else {
                                    selectedIDs.insert(member.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }



                // Confirm
                Button {
                    Task {
                        isSwitching = true
                        await store.switchFronting(to: Array(selectedIDs))
                        isSwitching = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        if isSwitching { ProgressView().tint(.white) }
                        else {
                            Image(systemName: "arrow.left.arrow.right")
                            Text("Switch Now")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Group {
                        if selectedIDs.isEmpty {
                            Color.white.opacity(0.1)
                        } else {
                            LinearGradient(colors: [Color(hex: "#A78BFA")!, Color(hex: "#6366F1")!],
                                           startPoint: .leading, endPoint: .trailing)
                        }
                    })
                    .cornerRadius(14)
                }
                .disabled(selectedIDs.isEmpty || isSwitching)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            selectedIDs = Set(store.frontingMembers.map { $0.id })
        }
    }
}

struct MemberSelectRow: View {
    let member: Member
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AvatarView(member: member, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName ?? member.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    if let p = member.pronouns, !p.isEmpty {
                        Text(p)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color(hex: "#A78BFA")! : Color.white.opacity(0.3))
                    .font(.system(size: 22))
            }
            .padding(14)
            .background(isSelected ? Color(hex: "#A78BFA")!.opacity(0.1) : Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color(hex: "#A78BFA")!.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1.5))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
