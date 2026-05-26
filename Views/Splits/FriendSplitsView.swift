import SwiftUI

struct FriendSplitsView: View {
    @Environment(SplitsViewModel.self) private var vm
    let friend: UserProfile

    @State private var showAddSplit      = false
    @State private var isSettlingAll     = false
    @State private var actionError: String?    = nil
    @State private var splitToDelete: SplitExpense? = nil
    @State private var showDeleteConfirm = false

    private var friendSplits: [SplitExpense] { vm.splits(with: friend.id) }
    private var balance: Double { vm.balance(with: friend.id) }
    private var hasUnsettled: Bool { vm.hasUnsettled(with: friend.id) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    heroBalance
                        .padding(.horizontal)
                        .padding(.top, 8)

                    if let actionError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.caption)
                            Text(actionError)
                                .font(.caption)
                        }
                        .foregroundStyle(Color(hex: "#FF6B6B"))
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if friendSplits.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 8) {
                            ForEach(friendSplits) { split in
                                SplitRow(
                                    split: split,
                                    currentUserId: vm.currentId,
                                    friendId: friend.id,
                                    onSettle: { Task { await settle(split: split) } },
                                    onDelete: { splitToDelete = split; showDeleteConfirm = true }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }

                    Color.clear.frame(height: 90)
                }
            }

            // FAB
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showAddSplit = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(splitGreen)
                    .clipShape(Circle())
                    .shadow(color: splitGreen.opacity(0.45), radius: 14)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle(friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasUnsettled {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await settleAllAction() }
                    } label: {
                        if isSettlingAll {
                            ProgressView().tint(splitGreen)
                        } else {
                            Text("Settle All")
                                .fontWeight(.semibold)
                                .foregroundStyle(splitGreen)
                        }
                    }
                    .disabled(isSettlingAll)
                }
            }
        }
        .sheet(isPresented: $showAddSplit) {
            AddSplitSheet(preselectedFriend: friend).environment(vm)
        }
        .confirmationDialog("Delete this split?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Split", role: .destructive) {
                guard let split = splitToDelete else { return }
                Task { await delete(split: split) }
            }
            Button("Cancel", role: .cancel) { splitToDelete = nil }
        } message: {
            Text("This removes the bill for everyone in this split.")
        }
    }

    // MARK: - Hero Balance

    private var heroBalance: some View {
        let active = abs(balance) > 0.005
        let color  = balance > 0 ? splitGreen : splitOrange

        return HStack(spacing: 14) {
            FriendAvatar(initials: friend.initials, id: friend.id, size: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.headline)
                    .foregroundStyle(.appText)
                    .lineLimit(1)
                Text(friend.email)
                    .font(.caption)
                    .foregroundStyle(.appSubtext)
                    .lineLimit(1)
            }

            Spacer()

            if active {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(abs(balance).asCurrency)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                    Text(balance > 0 ? "owes you" : "you owe")
                        .font(.caption)
                        .foregroundStyle(.appSubtext)
                }
            } else {
                Label("Settled", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(splitGreen)
            }
        }
        .padding(16)
        .background(active ? color.opacity(0.07) : Color.appSubtext.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(active ? color.opacity(0.22) : Color.appSubtext.opacity(0.08), lineWidth: 1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "equal.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.appSubtext.opacity(0.35))
            Text("No splits yet")
                .font(.headline)
                .foregroundStyle(.appText)
            Text("Tap + to add a split with \(friend.displayName).")
                .font(.subheadline)
                .foregroundStyle(.appSubtext)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func settleAllAction() async {
        isSettlingAll = true
        do {
            try await vm.settleAll(with: friend.id)
            actionError = nil
        } catch {
            actionError = "Could not settle all splits. Try again."
        }
        isSettlingAll = false
    }

    private func settle(split: SplitExpense) async {
        do {
            let settlerId = split.paidByUserId == vm.currentId ? friend.id : vm.currentId
            try await vm.settle(split: split, settlerId: settlerId)
            actionError = nil
        } catch {
            actionError = "Could not settle this split. Try again."
        }
    }

    private func delete(split: SplitExpense) async {
        do {
            try await vm.deleteSplit(split)
            splitToDelete      = nil
            showDeleteConfirm  = false
            actionError        = nil
        } catch {
            splitToDelete      = nil
            showDeleteConfirm  = false
            actionError        = "Could not delete this split. Try again."
        }
    }
}

// MARK: - Split Row

struct SplitRow: View {
    let split:         SplitExpense
    let currentUserId: String
    let friendId:      String
    let onSettle:      () -> Void
    let onDelete:      () -> Void

    private var iPaid: Bool { split.paidByUserId == currentUserId }
    private var isSettled: Bool {
        iPaid
            ? split.participantIds.filter { $0 != currentUserId }.allSatisfy { split.isSettled(by: $0) }
            : split.isSettled(by: currentUserId)
    }
    private var displayAmount: Double {
        iPaid ? split.unsettledAmount(for: friendId) : split.unsettledAmount(for: currentUserId)
    }
    private var accentColor: Color {
        isSettled ? .appSubtext : (iPaid ? splitGreen : splitOrange)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Direction icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(isSettled ? 0.06 : 0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            // Title + meta
            VStack(alignment: .leading, spacing: 3) {
                Text(split.title.isEmpty ? "Split" : split.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSettled ? .appSubtext : .appText)
                    .lineLimit(1)
                Text("\(paidByLabel) · \(split.date.shortFormatted)")
                    .font(.caption)
                    .foregroundStyle(.appSubtext)
            }

            Spacer()

            // Amount + status
            VStack(alignment: .trailing, spacing: 3) {
                if isSettled {
                    Text("Settled")
                        .font(.caption.bold())
                        .foregroundStyle(splitGreen)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(splitGreen.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("\(iPaid ? "+" : "−")\(displayAmount.asCurrency)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                    Button(iPaid ? "Mark paid" : "Settle", action: onSettle)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.electricBlue)
                }
            }

            // Context menu
            Menu {
                if !isSettled {
                    Button(action: onSettle) {
                        Label(iPaid ? "Mark Paid" : "Settle", systemImage: "checkmark.seal")
                    }
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.appSubtext.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.appSubtext.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.appSubtext.opacity(0.06), lineWidth: 1)
        }
    }

    private var iconName: String {
        if isSettled { return "checkmark" }
        return iPaid ? "arrow.down" : "arrow.up"
    }

    private var paidByLabel: String {
        iPaid ? "You paid \(split.totalAmount.asCurrency)"
              : "\(split.paidByName) paid \(split.totalAmount.asCurrency)"
    }
}
