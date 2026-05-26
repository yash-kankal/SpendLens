import SwiftUI

struct AnalyticsView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var appear = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    endOfMonthBanner
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appear)

                    WeekComparisonCard(expenses: dataStore.expenses)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appear)

                    MonthComparisonCard(expenses: dataStore.expenses)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appear)

                    SpendingHeatmapCard(expenses: dataStore.expenses)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appear)

                    BadgesCard(expenses: dataStore.expenses, budget: dataStore.budget)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: appear)

                    ChallengesCard(expenses: dataStore.expenses)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appear)

                    Color.clear.frame(height: 20)
                }
                .padding(.top, 8)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appear = true }
        }
    }

    // MARK: - End of Month Prediction Banner
    private var endOfMonthBanner: some View {
        let cal = Calendar.current
        let now = Date()
        let range = cal.range(of: .day, in: .month, for: now)!
        let totalDays = range.count
        let currentDay = cal.component(.day, from: now)
        let daysLeft = totalDays - currentDay

        let comps = cal.dateComponents([.year, .month], from: now)
        let monthStart = cal.date(from: comps) ?? now
        let thisMonthExpenses = dataStore.expenses.filter { $0.date >= monthStart }
        let spentSoFar = thisMonthExpenses.reduce(0) { $0 + $1.amount }
        let dailyAvg = currentDay > 0 ? spentSoFar / Double(currentDay) : 0
        let projected = spentSoFar + dailyAvg * Double(daysLeft)
        let budgetLimit = dataStore.budget?.totalBudget ?? 3000
        let isOver = projected > budgetLimit
        let accentColor: Color = isOver ? Color(hex: "#FF6B6B") : Color(hex: "#34D399")

        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("End of Month Prediction", systemImage: "wand.and.stars")
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(.appText)
                    Spacer()
                    Text("\(daysLeft)d left")
                        .font(.caption).foregroundStyle(.appSubtext)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("$\(Int(projected))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                    Text("projected")
                        .font(.caption).foregroundStyle(.appSubtext)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.appSubtext.opacity(0.08))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(accentColor)
                            .frame(width: min(geo.size.width * CGFloat(projected / max(budgetLimit, projected)), geo.size.width), height: 8)
                        // Budget marker
                        if projected > budgetLimit {
                            Rectangle()
                                .fill(Color.appSubtext.opacity(0.5))
                                .frame(width: 2, height: 14)
                                .offset(x: geo.size.width * CGFloat(budgetLimit / max(budgetLimit, projected)) - 1, y: -3)
                        }
                    }
                }
                .frame(height: 8)

                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(accentColor).frame(width: 6, height: 6)
                        Text(isOver ? "Over budget by \((projected - budgetLimit).asCurrency)" : "Under budget by \((budgetLimit - projected).asCurrency)")
                            .font(.caption).foregroundStyle(.appSubtext)
                    }
                    Spacer()
                    Text("\(dailyAvg.asCurrency)/day avg")
                        .font(.caption).foregroundStyle(.appSubtext)
                }
            }
        }
    }
}
