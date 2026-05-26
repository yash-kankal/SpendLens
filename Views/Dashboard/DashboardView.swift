import SwiftUI

struct DashboardView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(AuthViewModel.self) private var authVM

    @State private var viewModel = DashboardViewModel()
    @State private var showAddExpense = false
    @State private var fabScale: CGFloat = 1.0
    @State private var actionError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        HeroCard(
                            totalSpent: viewModel.totalSpent(from: dataStore.expenses),
                            totalBudget: dataStore.budget?.totalBudget ?? 3000,
                            daysLeft: viewModel.daysLeftInMonth,
                            monthName: viewModel.currentMonthName
                        )
                        .padding(.horizontal)

                        let breakdown = viewModel.categoryBreakdown(from: dataStore.expenses)
                        if !breakdown.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Spending Breakdown")
                                        .font(.headline).fontWeight(.bold).foregroundStyle(.appText)
                                    DonutChartView(
                                        breakdown: breakdown,
                                        selectedCategory: viewModel.selectedCategory,
                                        onTap: { viewModel.toggleCategoryFilter($0) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        transactionSection
                        Color.clear.frame(height: 90)
                    }
                    .padding(.top, 8)
                }

                fabButton
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 5) {
                        Image("SpendLensLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                        Text("SpendLens")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.appText)
                    }
                    .padding(.top, 12)
                    .frame(height: 52)
                }
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(onDismiss: { showAddExpense = false })
                .environment(dataStore)
                .environment(authVM)
        }
    }

    private var transactionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.selectedCategory == nil ? "Recent Transactions" : "\(viewModel.selectedCategory!.displayName) Transactions")
                    .font(.headline).fontWeight(.bold).foregroundStyle(.appText)
                Spacer()
            if viewModel.selectedCategory != nil {
                Button("Clear") { viewModel.selectedCategory = nil }
                    .font(.caption).foregroundStyle(Color.electricBlue)
            }
        }
        .padding(.horizontal)

            if let actionError {
                Text(actionError)
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#FF6B6B"))
                    .padding(.horizontal)
            }

            let grouped = viewModel.groupedExpenses(from: dataStore.expenses)

            if grouped.isEmpty {
                emptyState
            } else {
                ForEach(Array(grouped.enumerated()), id: \.offset) { index, group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.0)
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.appSubtext)
                            .textCase(.uppercase).tracking(0.8).padding(.horizontal)

                        ForEach(group.1) { expense in
                            TransactionRow(
                                expense: expense,
                                onDelete: { Task { await deleteExpense(expense) } },
                                onToggleRecurring: { dataStore.toggleRecurring(expense) }
                            )
                            .padding(.horizontal)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05), value: grouped.count)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 36)).foregroundStyle(.appSubtext)
            Text("No transactions yet").font(.subheadline).foregroundStyle(.appSubtext)
            Text("Tap + to add your first expense").font(.caption).foregroundStyle(.appSubtext.opacity(0.6))
        }
        .frame(maxWidth: .infinity).padding(40)
    }

    private var fabButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { fabScale = 0.9 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { fabScale = 1.0 }
                showAddExpense = true
            }
        } label: {
            ZStack {
                Circle().fill(Color.electricBlue).frame(width: 60, height: 60)
                    .shadow(color: Color.electricBlue.opacity(0.5), radius: 16)
                Image(systemName: "plus").font(.system(size: 24, weight: .bold)).foregroundStyle(.appOnAccent)
            }
        }
        .scaleEffect(fabScale).padding(.trailing, 20).padding(.bottom, 20)
    }

    private func deleteExpense(_ expense: Expense) async {
        do {
            try await dataStore.deleteExpense(expense)
            actionError = nil
        } catch {
            actionError = "Could not delete this expense. Try again."
        }
    }
}

// TransactionRow needs Task-based delete
extension DashboardView {
    // onDelete/onToggleRecurring wrappers handled inline above via DataStore
}
