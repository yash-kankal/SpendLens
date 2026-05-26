import SwiftUI

struct InsightsView: View {
    @Environment(DataStore.self) private var dataStore

    @State private var viewModel = InsightsViewModel()
    @State private var appear = false

    private var currentBudget: Budget? { dataStore.budget }

    private var currentMonthExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        return dataStore.expenses.filter {
            calendar.component(.month, from: $0.date) == month &&
                calendar.component(.year, from: $0.date) == year
        }
    }

    private var recentExpenses: [Expense] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return dataStore.expenses.filter { $0.date >= cutoff }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.appBackground.ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else {
                    contentView
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.showChat = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Ask AI")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.appText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(Color.electricBlue)
                            .shadow(color: Color.electricBlue.opacity(0.5), radius: 12)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await viewModel.loadInsights(expenses: dataStore.expenses, budget: currentBudget) }
                    } label: {
                        Image(systemName: "arrow.clockwise").foregroundStyle(Color.electricBlue)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .task {
            await viewModel.loadInsights(expenses: dataStore.expenses, budget: currentBudget)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appear = true }
        }
        .sheet(isPresented: $viewModel.showChat) {
            AIChatSheet(viewModel: viewModel, expenses: recentExpenses)
        }
        .refreshable {
            await viewModel.loadInsights(expenses: dataStore.expenses, budget: currentBudget)
        }
    }

    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let result = viewModel.insightResult {
                    SavingsInsightCard(
                        savedAmount: result.savedAmount,
                        lastMonthSavings: result.lastMonthSavings,
                        tip: result.budgetTips.first ?? ""
                    )
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appear)

                    PredictionInsightCard(
                        projectedSpend: result.projectedSpend,
                        budget: currentBudget?.totalBudget,
                        curveData: viewModel.spendingCurveData(from: currentMonthExpenses)
                    )
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appear)

                    if !result.budgetTips.isEmpty {
                        BudgetRecommendationsCard(tips: Array(result.budgetTips.dropFirst()), onApply: { _ in })
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appear)
                    }

                    if !result.savingOpportunities.isEmpty {
                        SavingOpportunitiesCard(opportunities: result.savingOpportunities)
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appear)
                    }

                    if !result.spendLessOn.isEmpty {
                        SpendLessOnCard(categories: result.spendLessOn)
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.22), value: appear)
                    }

                    if !result.patterns.isEmpty {
                        SmartPatternsCard(patterns: result.patterns)
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.26), value: appear)
                    }
                } else {
                    noDataView
                }

                Color.clear.frame(height: 90)
            }
            .padding(.top, 8)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5).tint(Color.electricBlue)
            Text("Analyzing your spending...").font(.subheadline).foregroundStyle(.appSubtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(Color.electricBlue.opacity(0.5))
            Text("No insights yet")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.appText)
            Text("Add some expenses and tap the refresh button to generate AI-powered insights.")
                .font(.subheadline)
                .foregroundStyle(.appSubtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
