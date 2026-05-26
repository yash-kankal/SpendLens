import SwiftUI

struct BudgetView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(AuthViewModel.self) private var authVM

    @State private var viewModel = BudgetViewModel()
    @State private var totalBudgetInput = ""
    @State private var editingTotal = false
    @State private var appear = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if let budget = dataStore.budget {
                    budgetContent(budget: budget)
                } else {
                    noBudgetView
                }
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .keyboardDoneButton()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) { appear = true }
        }
    }

    @ViewBuilder
    private func budgetContent(budget: Budget) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                monthlyOverviewCard(budget: budget).padding(.horizontal)

                Text("Category Budgets")
                    .font(.headline).fontWeight(.bold).foregroundStyle(.appText)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)

                ForEach(Array(ExpenseCategory.allCases.enumerated()), id: \.element) { index, category in
                    categoryBudgetRow(category: category, budget: budget)
                        .padding(.horizontal)
                        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05), value: appear)
                }
                Color.clear.frame(height: 20)
            }
            .padding(.top, 8)
        }
    }

    private func monthlyOverviewCard(budget: Budget) -> some View {
        let total = ExpenseCategory.allCases.reduce(0.0) { $0 + viewModel.categorySpent($1, from: dataStore.expenses) }
        let progress = budget.totalBudget > 0 ? min(total / budget.totalBudget, 1.0) : 0

        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Monthly Budget").font(.headline).fontWeight(.bold).foregroundStyle(.appText)
                    Spacer()
                    Button {
                        totalBudgetInput = String(Int(budget.totalBudget))
                        editingTotal = true
                    } label: {
                        Image(systemName: "pencil").font(.subheadline).foregroundStyle(Color.electricBlue)
                    }
                }

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(total.asCurrency).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.appText)
                        Text("of \(budget.totalBudget.asCurrency) spent").font(.caption).foregroundStyle(.appSubtext)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.appSubtext.opacity(0.08), lineWidth: 8)
                        Circle().trim(from: 0, to: appear ? progress : 0)
                            .stroke(viewModel.progressColor(for: progress), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: appear)
                        Text("\(Int(progress * 100))%").font(.caption).fontWeight(.bold).foregroundStyle(.appText)
                    }.frame(width: 70, height: 70)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.appSubtext.opacity(0.08)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.progressColor(for: progress))
                            .frame(width: appear ? geo.size.width * CGFloat(progress) : 0, height: 6)
                            .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.15), value: appear)
                    }
                }.frame(height: 6)
            }
        }
        .alert("Edit Monthly Budget", isPresented: $editingTotal) {
            TextField("Amount", text: $totalBudgetInput).keyboardType(.numberPad)
            Button("Save") {
                if let value = Double(totalBudgetInput), value > 0 {
                    dataStore.updateBudgetTotal(value)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func categoryBudgetRow(category: ExpenseCategory, budget: Budget) -> some View {
        let spent = viewModel.categorySpent(category, from: dataStore.expenses)
        let limit = budget.categoryLimits[category.rawValue] ?? 0
        let progress = viewModel.categoryProgress(category, budget: budget, from: dataStore.expenses)
        let progressColor = viewModel.progressColor(for: progress)
        let isEditing = viewModel.editingCategory == category

        GlassCard(padding: 14) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    CategoryIconPill(category: category, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.displayName).font(.subheadline).fontWeight(.semibold).foregroundStyle(.appText)
                        Text("\(spent.asCurrency) of \(limit.asCurrency)").font(.caption).foregroundStyle(.appSubtext)
                    }
                    Spacer()
                    if isEditing {
                        HStack(spacing: 6) {
                            TextField("$", text: $viewModel.tempBudgetInput)
                                .keyboardType(.numberPad).font(.subheadline).foregroundStyle(.appText)
                                .tint(Color.electricBlue).frame(width: 70)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .background(Color.appSubtext.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Button {
                                viewModel.commitCategoryLimit(category, dataStore: dataStore)
                            } label: {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.electricBlue).font(.title3)
                            }
                        }
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.tempBudgetInput = limit > 0 ? String(Int(limit)) : ""
                            viewModel.editingCategory = category
                        } label: {
                            Image(systemName: "pencil.circle").foregroundStyle(.appSubtext).font(.title3)
                        }
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.appSubtext.opacity(0.06)).frame(height: 4)
                        RoundedRectangle(cornerRadius: 3).fill(progressColor)
                            .frame(width: limit > 0 ? geo.size.width * CGFloat(progress) : 0, height: 4)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appear)
                    }
                }.frame(height: 4)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditing)
    }

    private var noBudgetView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie").font(.system(size: 56)).foregroundStyle(Color.electricBlue.opacity(0.5))
            Text("No Budget Set").font(.title2).fontWeight(.bold).foregroundStyle(.appText)
            Text("Set a monthly budget to track your spending limits.")
                .font(.subheadline).foregroundStyle(.appSubtext).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dataStore.createDefaultBudget(ownerId: authVM.currentUser?.uid ?? "")
            } label: {
                Text("Set Monthly Budget").font(.headline).fontWeight(.bold).foregroundStyle(.appOnAccent)
                    .padding(.horizontal, 32).padding(.vertical, 16)
                    .background { Capsule().fill(Color.electricBlue).shadow(color: Color.electricBlue.opacity(0.4), radius: 12) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
