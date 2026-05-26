import SwiftUI

struct SplitsView: View {
    @Environment(SplitsViewModel.self) private var vm

    @State private var showAddFriend = false
    @State private var showAddSplit  = false
    @State private var actionError: String? = nil

    private var sortedFriends: [UserProfile] {
        vm.friends.sorted {
            let l = abs(vm.balance(with: $0.id))
            let r = abs(vm.balance(with: $1.id))
            return l == r ? $0.displayName < $1.displayName : l > r
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.appBackground.ignoresSafeArea()

                if vm.friends.isEmpty {
                    emptyState
                } else {
                    scrollContent
                }

                if !vm.friends.isEmpty {
                    fab
                }
            }
            .navigationTitle("Splits")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(splitGreen)
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) { AddFriendSheet().environment(vm) }
            .sheet(isPresented: $showAddSplit)  { AddSplitSheet(preselectedFriend: nil).environment(vm) }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                balanceSummary
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)

                if let actionError {
                    Text(actionError)
                        .font(.caption)
                        .foregroundStyle(splitOrange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }

                LazyVStack(spacing: 0) {
                    ForEach(sortedFriends) { friend in
                        NavigationLink {
                            FriendSplitsView(friend: friend).environment(vm)
                        } label: {
                            FriendRow(
                                friend: friend,
                                balance: vm.balance(with: friend.id),
                                openCount: vm.splits(with: friend.id).filter { !vm.isSplitSettled($0) }.count
                            )
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if vm.hasUnsettled(with: friend.id) {
                                Button {
                                    Task { await settleAll(with: friend.id) }
                                } label: {
                                    Label("Settle up", systemImage: "checkmark.seal")
                                }
                            }
                        }
                    }
                }

                Color.clear.frame(height: 100)
            }
        }
    }

    // MARK: - Balance Summary

    private var balanceSummary: some View {
        HStack(spacing: 10) {
            balancePill(label: "You owe", amount: vm.totalYouOwe, color: splitOrange)
            balancePill(label: "Owed to you", amount: vm.totalOwedToYou, color: splitGreen)
        }
    }

    private func balancePill(label: String, amount: Double, color: Color) -> some View {
        let active = amount > 0.005
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.appSubtext)
            Text(amount.asCurrency)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(active ? color : .appSubtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(active ? color.opacity(0.07) : Color.appSubtext.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(active ? color.opacity(0.25) : Color.clear, lineWidth: 1)
        }
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showAddSplit = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Add expense")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 48)
            .background {
                Capsule()
                    .fill(splitGreen)
                    .shadow(color: splitGreen.opacity(0.4), radius: 14, y: 4)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.appSubtext.opacity(0.35))

            VStack(spacing: 6) {
                Text("No friends yet")
                    .font(.title3.bold())
                    .foregroundStyle(.appText)
                Text("Add friends to start splitting expenses.\nThey need a SpendLens account.")
                    .font(.subheadline)
                    .foregroundStyle(.appSubtext)
                    .multilineTextAlignment(.center)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showAddFriend = true
            } label: {
                Label("Add a friend", systemImage: "person.badge.plus")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(splitGreen)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func settleAll(with friendId: String) async {
        do {
            try await vm.settleAll(with: friendId)
            actionError = nil
        } catch {
            actionError = "Could not settle. Try again."
        }
    }
}

// MARK: - Friend Row

private struct FriendRow: View {
    let friend:     UserProfile
    let balance:    Double
    let openCount:  Int

    private var isOwedToYou: Bool { balance >  0.005 }
    private var youOwe:      Bool { balance < -0.005 }
    private var settled:     Bool { !isOwedToYou && !youOwe }

    var body: some View {
        HStack(spacing: 14) {
            FriendAvatar(initials: friend.initials, id: friend.id, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.appText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.appSubtext)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if settled {
                    Text("Settled")
                        .font(.caption.bold())
                        .foregroundStyle(.appSubtext)
                } else {
                    Text(abs(balance).asCurrency)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(isOwedToYou ? splitGreen : splitOrange)
                    Text(isOwedToYou ? "owed to you" : "you owe")
                        .font(.caption2)
                        .foregroundStyle(.appSubtext)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.appSubtext.opacity(0.3))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.appSubtext.opacity(0.07))
                .frame(height: 0.5)
                .padding(.leading, 60)
        }
    }

    private var subtitle: String {
        switch openCount {
        case 0:  return "All settled"
        case 1:  return "1 open split"
        default: return "\(openCount) open splits"
        }
    }
}

// MARK: - Friend Avatar (used across Splits files)

struct FriendAvatar: View {
    let initials: String
    let id:       String
    let size:     CGFloat

    var avatarColor: Color {
        let palette: [Color] = [
            splitGreen,
            Color(hex: "#6366F1"),
            Color(hex: "#EC4899"),
            Color(hex: "#F59E0B"),
            Color(hex: "#4F8EF7"),
            Color(hex: "#14B8A6"),
        ]
        return palette[abs(id.hashValue) % palette.count]
    }

    var body: some View {
        ZStack {
            Circle().fill(avatarColor.opacity(0.18))
            Text(initials)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(avatarColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Shared color tokens

let splitGreen  = Color(hex: "#1CB79C")
let splitOrange = Color(hex: "#FF6B1A")
