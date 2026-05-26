import Foundation
import Observation
import UIKit

@MainActor
@Observable
class SplitsViewModel {
    var friends: [UserProfile] = []
    var splits: [SplitExpense] = []
    var searchResult: UserProfile? = nil
    var isSearching = false
    var searchError: String? = nil
    var isLoading = false

    private let supabase = SupabaseService.shared
    private var currentUserId: String = ""
    private var currentUserName: String = ""
    private var currentUserEmail: String = ""
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var lifecycleObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var isAppActive = true

    var currentId: String { currentUserId }
    var currentDisplayName: String { currentUserName.isEmpty ? "You" : currentUserName }
    var totalOwedToYou: Double {
        friends.reduce(0) { total, friend in max(0, balance(with: friend.id)) + total }
    }
    var totalYouOwe: Double {
        friends.reduce(0) { total, friend in max(0, -balance(with: friend.id)) + total }
    }
    var openSplitsCount: Int {
        splits.filter { $0.participantIds.contains(currentUserId) && !isSplitSettled($0) }.count
    }
    var settledSplitsCount: Int {
        splits.filter { $0.participantIds.contains(currentUserId) && isSplitSettled($0) }.count
    }
    var recentSplits: [SplitExpense] { Array(splits.prefix(5)) }

    // MARK: - Lifecycle

    func startListening(user: AppUser) {
        if currentUserId == user.uid, !friends.isEmpty || !splits.isEmpty {
            startAutoRefresh()
            return
        }
        currentUserId    = user.uid
        currentUserEmail = (user.email ?? "").lowercased()
        currentUserName  = user.displayName ?? String(user.email?.split(separator: "@").first ?? "User")
        setupLifecycleObservers()
        startAutoRefresh()

        Task {
            try? await saveProfile()
            await refresh()
        }
    }

    func stopListening() {
        refreshTask?.cancel()
        refreshTask = nil
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        lifecycleObservers.removeAll()
        friends = []
        splits = []
        currentUserId = ""
        searchResult = nil
        searchError = nil
    }

    func refresh() async {
        guard !currentUserId.isEmpty else { return }
        do {
            let loadedSplits    = try await loadSplits()
            let participantIds  = Set(loadedSplits.flatMap(\.participantIds).filter { $0 != currentUserId })
            let loadedFriends   = try await loadFriends(extraProfileIds: participantIds)
            friends = loadedFriends
            splits  = loadedSplits
        } catch {
            friends = []
            splits  = []
        }
    }

    // MARK: - Private helpers

    private func setupLifecycleObservers() {
        // Guard against duplicate registration if startListening is called again
        guard lifecycleObservers.isEmpty else { return }

        let bg = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // queue: .main guarantees we're on the main thread; assumeIsolated
            // satisfies the compiler without an extra async hop.
            MainActor.assumeIsolated { self?.isAppActive = false }
        }

        let fg = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.isAppActive = true }
        }

        lifecycleObservers = [bg, fg]
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                guard self?.isAppActive == true else { continue }
                await self?.refresh()
            }
        }
    }

    // MARK: - Profile

    private func saveProfile() async throws {
        let profile = UserProfile(id: currentUserId, displayName: currentUserName, email: currentUserEmail)
        try await supabase.upsert(profile, table: "profiles")
    }

    private func loadFriends(extraProfileIds: Set<String> = []) async throws -> [UserProfile] {
        let links: [FriendLink] = try await supabase.select(
            table: "friends",
            queryItems: [URLQueryItem(name: "user_id", value: "eq.\(currentUserId)")]
        )
        let ids = Set(links.map(\.friendId)).union(extraProfileIds)
        guard !ids.isEmpty else { return [] }
        let joinedIds = ids.sorted().joined(separator: ",")
        return try await supabase.select(
            table: "profiles",
            queryItems: [
                URLQueryItem(name: "id",    value: "in.(\(joinedIds))"),
                URLQueryItem(name: "order", value: "display_name.asc")
            ]
        )
    }

    private func loadSplits() async throws -> [SplitExpense] {
        let loaded: [SplitExpense] = try await supabase.select(
            table: "splits",
            queryItems: [
                URLQueryItem(name: "participant_ids", value: "cs.{\(currentUserId)}"),
                URLQueryItem(name: "order",           value: "date.desc")
            ]
        )
        return loaded
    }

    // MARK: - Balances

    /// Positive → friend owes you. Negative → you owe friend.
    func balance(with friendId: String) -> Double {
        splits
            .filter { $0.participantIds.contains(friendId) && $0.participantIds.contains(currentUserId) }
            .reduce(0) { total, split in
                if split.paidByUserId == currentUserId {
                    return total + split.unsettledAmount(for: friendId)
                } else if split.paidByUserId == friendId {
                    return total - split.unsettledAmount(for: currentUserId)
                }
                return total
            }
    }

    var netBalance: Double { friends.reduce(0) { $0 + balance(with: $1.id) } }

    func splits(with friendId: String) -> [SplitExpense] {
        splits.filter { $0.participantIds.contains(friendId) && $0.participantIds.contains(currentUserId) }
    }

    func hasUnsettled(with friendId: String) -> Bool {
        splits(with: friendId).contains { split in
            let settler = split.paidByUserId == currentUserId ? friendId : currentUserId
            return !(split.settled[settler] ?? false)
        }
    }

    func isSplitSettled(_ split: SplitExpense) -> Bool {
        split.participantIds
            .filter { $0 != split.paidByUserId }
            .allSatisfy { split.isSettled(by: $0) }
    }

    func splitSummary(_ split: SplitExpense) -> String {
        let total = "$\(String(format: "%.2f", split.totalAmount))"
        if split.paidByUserId == currentUserId {
            let owed = split.participantIds
                .filter { $0 != currentUserId }
                .reduce(0) { $0 + split.unsettledAmount(for: $1) }
            return owed > 0
                ? "You paid \(total). Others owe you $\(String(format: "%.2f", owed))."
                : "You paid \(total). Settled."
        }
        let youOwe = split.unsettledAmount(for: currentUserId)
        return youOwe > 0
            ? "\(split.paidByName) paid \(total). You owe $\(String(format: "%.2f", youOwe))."
            : "\(split.paidByName) paid \(total). Settled."
    }

    // MARK: - Search

    func searchUser(email: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        isSearching = true; searchError = nil; searchResult = nil

        do {
            let results: [UserProfile] = try await supabase.select(
                table: "profiles",
                queryItems: [
                    URLQueryItem(name: "email", value: "eq.\(trimmed)"),
                    URLQueryItem(name: "limit", value: "1")
                ]
            )
            if let profile = results.first, profile.id != currentUserId {
                searchResult = profile
            } else {
                searchError = "No SpendLens account found for that email."
            }
        } catch {
            searchError = "Search failed. Check your connection."
        }
        isSearching = false
    }

    // MARK: - Friends

    func addFriend(_ profile: UserProfile) async throws {
        guard !currentUserId.isEmpty else {
            throw SupabaseServiceError.requestFailed("Please sign in again before adding friends.")
        }
        guard profile.id != currentUserId else {
            throw SupabaseServiceError.requestFailed("You cannot add yourself as a friend.")
        }
        if isFriend(profile.id) { return }

        let mine   = FriendLink(userId: currentUserId, friendId: profile.id)
        let theirs = FriendLink(userId: profile.id,    friendId: currentUserId)
        try await supabase.upsert(mine,   table: "friends", onConflict: "user_id,friend_id")
        try? await supabase.upsert(theirs, table: "friends", onConflict: "user_id,friend_id")
        await refresh()
    }

    func isFriend(_ profileId: String) -> Bool {
        friends.contains { $0.id == profileId }
    }

    // MARK: - Create Split

    func createSplit(
        title: String,
        totalAmount: Double,
        paidByUserId: String,
        paidByName: String,
        participantIds: [String],
        shares: [String: Double],
        note: String?
    ) async throws {
        var settled: [String: Bool] = [:]
        for pid in participantIds where pid != paidByUserId { settled[pid] = false }

        var split = SplitExpense()
        split.title         = title
        split.totalAmount   = totalAmount
        split.paidByUserId  = paidByUserId
        split.paidByName    = paidByName
        split.participantIds = participantIds
        split.shares        = shares
        split.settled       = settled
        split.date          = Date()
        split.note          = note?.isEmpty == false ? note : nil

        try await supabase.upsert(split, table: "splits")
        await refresh()
    }

    // MARK: - Settle

    func settle(split: SplitExpense, settlerId: String? = nil) async throws {
        let resolvedSettlerId = settlerId ?? (split.paidByUserId == currentUserId
            ? split.participantIds.first(where: { $0 != currentUserId }) ?? ""
            : currentUserId)
        guard !resolvedSettlerId.isEmpty, resolvedSettlerId != split.paidByUserId else { return }

        var updatedSettled = split.settled
        updatedSettled[resolvedSettlerId] = true
        try await supabase.update(
            ["settled": updatedSettled],
            table: "splits",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(split.id)")]
        )
        await refresh()
    }

    func settleAll(with friendId: String) async throws {
        let unsettled = splits(with: friendId).filter { split in
            let settler = split.paidByUserId == currentUserId ? friendId : currentUserId
            return !(split.settled[settler] ?? false)
        }
        for split in unsettled {
            let settler = split.paidByUserId == currentUserId ? friendId : currentUserId
            try await settle(split: split, settlerId: settler)
        }
    }

    func settleVisibleSide(of split: SplitExpense) async throws {
        if split.paidByUserId == currentUserId {
            let unsettledParticipants = split.participantIds.filter {
                $0 != currentUserId && !(split.settled[$0] ?? false)
            }
            for participantId in unsettledParticipants {
                try await settle(split: split, settlerId: participantId)
            }
        } else {
            try await settle(split: split, settlerId: currentUserId)
        }
    }

    // MARK: - Delete

    func deleteSplit(_ split: SplitExpense) async throws {
        guard split.participantIds.contains(currentUserId) else {
            throw SupabaseServiceError.requestFailed("You are not a participant in this split.")
        }

        splits.removeAll { $0.id == split.id }

        do {
            try await supabase.delete(
                table: "splits",
                queryItems: [URLQueryItem(name: "id", value: "eq.\(split.id)")]
            )
        } catch {
            // Network failed — restore by re-fetching, then propagate the error
            await refresh()
            throw error
        }

        // Background sync (don't await — UI is already updated optimistically)
        Task { await refresh() }
    }
}

private struct FriendLink: Codable {
    let userId:   String
    let friendId: String

    enum CodingKeys: String, CodingKey {
        case userId   = "user_id"
        case friendId = "friend_id"
    }
}
