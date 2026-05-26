import SwiftUI

struct AddSplitSheet: View {
    @Environment(SplitsViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    let preselectedFriend: UserProfile?

    @State private var title          = ""
    @State private var amountText     = ""
    @State private var selectedFriends: [UserProfile] = []
    @State private var selectedPayerId: String?       = nil
    @State private var splitMode: SplitMode           = .equal
    @State private var customShares: [String: String] = [:]
    @State private var note           = ""
    @State private var isSaving       = false
    @State private var saveError: String?             = nil
    @FocusState private var amountFocused: Bool

    // MARK: - Computed

    private var totalAmount: Double { Double(amountText) ?? 0 }
    private var payerId: String     { selectedPayerId ?? vm.currentId }
    private var participantIds: [String] {
        Array(Set([vm.currentId] + selectedFriends.map(\.id))).sorted()
    }
    private var customShareIds: [String] {
        participantIds.filter { $0 != payerId }
    }

    private var isValid: Bool {
        guard !title.isEmpty, totalAmount > 0, !selectedFriends.isEmpty else { return false }
        switch splitMode {
        case .equal: return true
        case .exact:
            let vals = customShareIds.map { Double(customShares[$0] ?? "") ?? 0 }
            return !vals.isEmpty && vals.allSatisfy { $0 >= 0 } && vals.reduce(0, +) <= totalAmount + 0.001
        case .percent:
            let vals = customShareIds.map { Double(customShares[$0] ?? "") ?? 0 }
            return !vals.isEmpty && vals.allSatisfy { $0 >= 0 } && vals.reduce(0, +) <= 100.001
        }
    }

    private var sharesDict: [String: Double] {
        switch splitMode {
        case .equal:
            let each = totalAmount / Double(participantIds.count)
            return Dictionary(uniqueKeysWithValues: participantIds.filter { $0 != payerId }.map { ($0, each) })
        case .exact:
            return Dictionary(uniqueKeysWithValues: customShareIds.compactMap { id -> (String, Double)? in
                guard let v = Double(customShares[id] ?? "") else { return nil }
                return (id, v)
            }.filter { $0.1 > 0 })
        case .percent:
            return Dictionary(uniqueKeysWithValues: customShareIds.compactMap { id -> (String, Double)? in
                guard let p = Double(customShares[id] ?? "") else { return nil }
                return (id, totalAmount * p / 100)
            }.filter { $0.1 > 0 })
        }
    }

    private var payerShare: Double {
        max(0, totalAmount - sharesDict.values.reduce(0, +))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        amountHero
                        friendsCard
                        if !selectedFriends.isEmpty { payerCard }
                        if !selectedFriends.isEmpty && totalAmount > 0 { splitCard }
                        noteRow
                        if let err = saveError { errorBanner(err) }
                        saveButton
                        Color.clear.frame(height: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Split")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.appSubtext)
                }
            }
            .onAppear {
                selectedPayerId = vm.currentId
                if let pre = preselectedFriend { selectedFriends = [pre] }
            }
        }
        .presentationBackground(Color.appBackground)
    }

    // MARK: - Amount Hero

    private var amountHero: some View {
        VStack(spacing: 14) {
            // Big centred amount
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: 32, weight: .light, design: .rounded))
                    .foregroundStyle(.appSubtext)
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(.appText)
                    .focused($amountFocused)
                    .fixedSize()
                    .frame(minWidth: 60)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onTapGesture { amountFocused = true }

            // Title
            TextField("What's this for?", text: $title)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.appText)
                .padding(.vertical, 11)
                .padding(.horizontal, 16)
                .background(Color.appSubtext.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    // MARK: - Friends Card

    private var friendsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("Split with", systemImage: "person.2.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.appText)

                if vm.friends.isEmpty {
                    Text("No friends added yet")
                        .font(.subheadline)
                        .foregroundStyle(.appSubtext)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 10)], spacing: 14) {
                        ForEach(vm.friends) { friend in
                            let sel = selectedFriends.contains { $0.id == friend.id }
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if sel {
                                    selectedFriends.removeAll { $0.id == friend.id }
                                    customShares.removeValue(forKey: friend.id)
                                    if selectedPayerId == friend.id { selectedPayerId = vm.currentId }
                                } else {
                                    selectedFriends.append(friend)
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .bottomTrailing) {
                                        FriendAvatar(initials: friend.initials, id: friend.id, size: 46)
                                            .overlay(
                                                Circle().strokeBorder(
                                                    sel ? Color.electricBlue : Color.clear,
                                                    lineWidth: 2.5
                                                )
                                            )
                                        if sel {
                                            Circle()
                                                .fill(Color.electricBlue)
                                                .frame(width: 16, height: 16)
                                                .overlay(
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundStyle(.white)
                                                )
                                                .offset(x: 3, y: 3)
                                        }
                                    }
                                    Text(firstName(friend.displayName))
                                        .font(.caption2)
                                        .foregroundStyle(sel ? Color.electricBlue : .appSubtext)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Payer Card

    private var payerCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Paid by", systemImage: "creditcard.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.appText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        payerPill(
                            id: vm.currentId,
                            name: "You",
                            initials: String(vm.currentDisplayName.prefix(2)).uppercased()
                        )
                        ForEach(selectedFriends) { f in
                            payerPill(id: f.id, name: firstName(f.displayName), initials: f.initials)
                        }
                    }
                }
            }
        }
    }

    private func payerPill(id: String, name: String, initials: String) -> some View {
        let sel = payerId == id
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedPayerId = id
        } label: {
            HStack(spacing: 8) {
                FriendAvatar(initials: initials, id: id, size: 26)
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(sel ? .white : .appText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(sel ? Color.electricBlue : Color.appSubtext.opacity(0.07))
            .clipShape(Capsule())
        }
    }

    // MARK: - Split Card

    private var splitCard: some View {
        card {
            VStack(spacing: 16) {
                // Mode toggle
                HStack(spacing: 6) {
                    ForEach(SplitMode.allCases) { mode in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                splitMode = mode
                            }
                        } label: {
                            Text(mode.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(splitMode == mode ? .appOnAccent : .appSubtext)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    splitMode == mode
                                        ? Color.electricBlue
                                        : Color.appSubtext.opacity(0.07)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                // Custom share inputs
                if splitMode != .equal {
                    VStack(spacing: 8) {
                        ForEach(customShareIds, id: \.self) { uid in
                            customShareRow(uid: uid)
                        }

                        let remainder: Double = splitMode == .percent
                            ? max(0, 100 - customShareIds.reduce(0.0) { $0 + (Double(customShares[$1] ?? "") ?? 0) })
                            : payerShare

                        HStack {
                            Text(payerId == vm.currentId ? "Your share" : "\(name(for: payerId))'s share")
                                .font(.caption).foregroundStyle(.appSubtext)
                            Spacer()
                            Text(splitMode == .percent
                                 ? "\(String(format: "%.1f", remainder))%"
                                 : remainder.asCurrency)
                                .font(.caption.bold())
                                .foregroundStyle(remainder >= 0 ? Color(hex: "#34D399") : Color(hex: "#FF6B6B"))
                        }
                        .padding(.horizontal, 2)
                        .padding(.top, 2)
                    }
                }

                Divider().opacity(0.3)

                // Per-person summary
                VStack(spacing: 10) {
                    if splitMode == .equal {
                        let each = totalAmount / Double(participantIds.count)
                        HStack {
                            Text("Each person")
                                .font(.subheadline).foregroundStyle(.appSubtext)
                            Spacer()
                            Text(each.asCurrency)
                                .font(.subheadline.bold()).foregroundStyle(.appText)
                        }
                    }

                    ForEach(participantIds, id: \.self) { id in
                        let isPayer = id == payerId
                        let share   = isPayer ? payerShare : (sharesDict[id] ?? 0)
                        let initials: String = id == vm.currentId
                            ? String(vm.currentDisplayName.prefix(2)).uppercased()
                            : (vm.friends.first { $0.id == id }?.initials ?? "?")

                        HStack(spacing: 10) {
                            FriendAvatar(initials: initials, id: id, size: 28)

                            HStack(spacing: 4) {
                                Text(id == vm.currentId ? "You" : name(for: id))
                                    .font(.subheadline).foregroundStyle(.appText)
                                if isPayer {
                                    Text("· paid")
                                        .font(.caption).foregroundStyle(.appSubtext)
                                }
                            }

                            Spacer()

                            if isPayer {
                                Text(totalAmount.asCurrency)
                                    .font(.subheadline.bold()).foregroundStyle(.appText)
                            } else if share > 0 {
                                Text("owes \(share.asCurrency)")
                                    .font(.subheadline).foregroundStyle(splitOrange)
                            } else {
                                Text("settled")
                                    .font(.caption).foregroundStyle(splitGreen)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func customShareRow(uid: String) -> some View {
        let friend = selectedFriends.first { $0.id == uid }
        HStack(spacing: 12) {
            FriendAvatar(initials: friend?.initials ?? "?", id: uid, size: 28)
            Text(firstName(friend?.displayName ?? "Friend"))
                .font(.subheadline).foregroundStyle(.appText)
            Spacer()
            HStack(spacing: 4) {
                Text(splitMode == .percent ? "%" : "$")
                    .font(.subheadline).foregroundStyle(.appSubtext)
                TextField("0", text: Binding(
                    get: { customShares[uid] ?? "" },
                    set: { customShares[uid] = $0 }
                ))
                .keyboardType(.decimalPad)
                .foregroundStyle(.appText)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            }
        }
        .padding(10)
        .background(Color.appSubtext.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Note & Error & Save

    private var noteRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text").foregroundStyle(.appSubtext)
            TextField("Add a note (optional)", text: $note)
                .foregroundStyle(.appText)
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(Color.appSubtext.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func errorBanner(_ msg: String) -> some View {
        Label(msg, systemImage: "exclamationmark.circle")
            .font(.subheadline)
            .foregroundStyle(Color(hex: "#FF6B6B"))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#FF6B6B").opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var saveButton: some View {
        Button(action: save) {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Add Split").fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(isValid ? Color.electricBlue : Color.appSubtext.opacity(0.08))
            .foregroundStyle(isValid ? .appOnAccent : .appSubtext)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!isValid || isSaving)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.appSubtext.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.appSubtext.opacity(0.08), lineWidth: 1)
            )
    }

    private func firstName(_ full: String) -> String {
        full.components(separatedBy: " ").first ?? full
    }

    private func name(for userId: String) -> String {
        if userId == vm.currentId { return "You" }
        return selectedFriends.first { $0.id == userId }?.displayName ?? "Friend"
    }

    // MARK: - Save

    private func save() {
        guard isValid, !isSaving else { return }
        isSaving = true
        let payerName = payerId == vm.currentId
            ? vm.currentDisplayName
            : (selectedFriends.first { $0.id == payerId }?.displayName ?? "Friend")

        Task {
            do {
                try await vm.createSplit(
                    title: title,
                    totalAmount: totalAmount,
                    paidByUserId: payerId,
                    paidByName: payerName,
                    participantIds: participantIds,
                    shares: sharesDict,
                    note: note
                )
                dismiss()
            } catch {
                saveError = "Failed to save. Check your connection."
                isSaving = false
            }
        }
    }
}

// MARK: - Split Mode

private enum SplitMode: String, CaseIterable, Identifiable {
    case equal, exact, percent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equal:   return "Equal"
        case .exact:   return "Exact"
        case .percent: return "By %"
        }
    }
}
