import SwiftUI

struct AddExpenseSheet: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(AuthViewModel.self) private var authVM
    var onDismiss: () -> Void

    @State private var amountString = "0"
    @State private var title = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var date = Date()
    @State private var note = ""
    @State private var isRecurring = false
    @State private var aiSuggesting = false
    @State private var aiTag: String? = nil
    @State private var tagSource: String? = nil
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var addSuccess = false
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private var amount: Double { Double(amountString) ?? 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        amountDisplay
                        numpad

                        GlassCard {
                            VStack(spacing: 18) {
                                // Title
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Description")
                                            .font(.caption).fontWeight(.semibold).foregroundStyle(.appSubtext)
                                            .textCase(.uppercase).tracking(0.8)
                                        Spacer()
                                        if aiSuggesting {
                                            HStack(spacing: 4) {
                                                ProgressView().scaleEffect(0.7).tint(Color.electricBlue)
                                                Text("\(tagSource ?? "Auto") tagging...").font(.caption2).foregroundStyle(Color.electricBlue)
                                            }
                                        }
                                    }
                                    TextField("e.g. Starbucks coffee", text: $title)
                                        .font(.body).foregroundStyle(.appText).tint(Color.electricBlue)
                                        .onChange(of: title) { _, newVal in triggerAutoTag(title: newVal) }
                                }

                                Divider().background(Color.appSubtext.opacity(0.08))

                                // Category
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Category")
                                        .font(.caption).fontWeight(.semibold).foregroundStyle(.appSubtext)
                                        .textCase(.uppercase).tracking(0.8)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                                                CategoryPill(category: cat, isSelected: selectedCategory == cat, size: .small) {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedCategory = cat }
                                                }
                                            }
                                        }.padding(.horizontal, 2)
                                    }
                                }

                                Divider().background(Color.appSubtext.opacity(0.08))

                                // Date
                                HStack {
                                    Text("Date").font(.caption).fontWeight(.semibold).foregroundStyle(.appSubtext)
                                        .textCase(.uppercase).tracking(0.8)
                                    Spacer()
                                    DatePicker("", selection: $date, displayedComponents: [.date])
                                        .labelsHidden().tint(Color.electricBlue).colorScheme(.dark)
                                }

                                Divider().background(Color.appSubtext.opacity(0.08))

                                TextField("Note (optional)", text: $note, axis: .vertical)
                                    .font(.body).foregroundStyle(.appText).tint(Color.electricBlue).lineLimit(1...3)

                                Divider().background(Color.appSubtext.opacity(0.08))

                                Toggle(isOn: $isRecurring) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.2.circlepath").foregroundStyle(Color.electricBlue)
                                        Text("Recurring expense").font(.body).foregroundStyle(.appText)
                                    }
                                }.tint(Color.electricBlue)
                            }
                        }
                        .padding(.horizontal)

                        addButton
                        if let saveError {
                            Text(saveError)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#FF6B6B"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                        Color.clear.frame(height: 20)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onDismiss()
                    }.foregroundStyle(.appSubtext)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private var amountDisplay: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$").font(.system(size: 36, weight: .light, design: .rounded)).foregroundStyle(.appSubtext)
                Text(amountString == "0" ? "0" : amountString)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(amount > 0 ? .white : .appSubtext)
                    .contentTransition(.numericText(value: amount))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: amountString)
            }
            CategoryPill(category: selectedCategory, isSelected: true, size: .small)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedCategory)
        }
        .padding(.top, 8).frame(maxWidth: .infinity)
    }

    private var numpad: some View {
        let keys: [[String]] = [["1","2","3"],["4","5","6"],["7","8","9"],[".", "0","⌫"]]
        return VStack(spacing: 10) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in NumpadKey(label: key) { handleNumpadInput(key) } }
                }
            }
        }.padding(.horizontal, 32)
    }

    private var addButton: some View {
        Button {
            guard amount > 0, !title.isEmpty else {
                UINotificationFeedbackGenerator().notificationOccurred(.error); return
            }
            Task { await saveExpense() }
        } label: {
            HStack {
                if isSaving { ProgressView().tint(.white) }
                else if addSuccess { Image(systemName: "checkmark").font(.headline) }
                else { Text("Add Expense").font(.headline).fontWeight(.bold) }
            }
            .foregroundStyle(amount > 0 && !title.isEmpty ? .appOnAccent : .appSubtext).frame(maxWidth: .infinity).frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(amount > 0 && !title.isEmpty ? Color.electricBlue : Color.appSubtext.opacity(0.08))
                    .shadow(color: amount > 0 && !title.isEmpty ? Color.electricBlue.opacity(0.4) : .clear, radius: 12)
            }
        }
        .padding(.horizontal).disabled(amount <= 0 || title.isEmpty || isSaving)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: addSuccess)
    }

    private func handleNumpadInput(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch key {
        case "⌫": amountString = amountString.count > 1 ? String(amountString.dropLast()) : "0"
        case ".": if !amountString.contains(".") { amountString += "." }
        default:
            if amountString == "0" { amountString = key }
            else if amountString.count < 10 {
                if let dotIdx = amountString.firstIndex(of: ".") {
                    if amountString.distance(from: dotIdx, to: amountString.endIndex) - 1 < 2 { amountString += key }
                } else { amountString += key }
            }
        }
    }

    private func triggerAutoTag(title: String) {
        debounceTask?.cancel()
        guard title.count >= 3 else { return }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { aiSuggesting = true }
            let suggestion = await OpenAIService.shared.suggestCategory(title: title)
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selectedCategory = suggestion.category }
                aiTag = "\(suggestion.source) tagged"
                tagSource = suggestion.source
                aiSuggesting = false
            }
        }
    }

    private func saveExpense() async {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let expense = Expense(
            ownerId: authVM.currentUser?.uid ?? "",
            title: title,
            amount: amount,
            category: selectedCategory,
            date: date,
            note: note.isEmpty ? nil : note,
            isRecurring: isRecurring,
            aiTag: aiTag
        )
        isSaving = true
        saveError = nil
        do {
            try await dataStore.addExpense(expense)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { addSuccess = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onDismiss() }
        } catch {
            saveError = "Could not save this expense. Check your connection and try again."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isSaving = false
    }
}

struct NumpadKey: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button { action() } label: {
            Text(label)
                .font(.system(size: label == "⌫" ? 20 : 26, weight: .medium, design: .rounded))
                .foregroundStyle(label == "⌫" ? .appSubtext : .white)
                .frame(maxWidth: .infinity).frame(height: 60)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appSubtext.opacity(0.06))
                        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.appSubtext.opacity(0.08), lineWidth: 1) }
                }
        }.buttonStyle(PressedButtonStyle())
    }
}

struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
