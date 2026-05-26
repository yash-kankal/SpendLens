import SwiftUI

struct AppBadge {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isEarned: Bool
}

struct BadgesCard: View {
    let expenses: [Expense]
    let budget: Budget?

    private var badges: [AppBadge] {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let monthStart = cal.date(from: comps) ?? now
        let thisMonthExpenses = expenses.filter { $0.date >= monthStart }
        let totalThisMonth = thisMonthExpenses.reduce(0) { $0 + $1.amount }
        let budgetLimit = budget?.totalBudget ?? 3000

        // Under budget this month
        let underBudget = totalThisMonth < budgetLimit

        // Has savings category expense
        let hasSavings = expenses.contains { $0.category == .savings }

        // No single expense over $200
        let noSplurge = !expenses.filter {
            cal.date(byAdding: .day, value: -7, to: now)! <= $0.date
        }.contains { $0.amount > 200 }

        // Spent less than 50% of budget
        let lightSpender = totalThisMonth < budgetLimit * 0.5

        // Has expenses on 5+ different days this month
        let activeDays = Set(thisMonthExpenses.map { cal.startOfDay(for: $0.date) }).count
        let consistent = activeDays >= 5

        // No entertainment or shopping in last 7 days
        let frugalWeek = !expenses.filter {
            (cal.date(byAdding: .day, value: -7, to: now) ?? now) <= $0.date
        }.contains { $0.category == .entertainment || $0.category == .shopping }

        return [
            AppBadge(title: "Budget Hero", description: "Stayed under budget this month", icon: "trophy.fill", color: Color(hex: "#F59E0B"), isEarned: underBudget),
            AppBadge(title: "Super Saver", description: "Added to your savings", icon: "banknote.fill", color: Color(hex: "#34D399"), isEarned: hasSavings),
            AppBadge(title: "No Splurge", description: "No expense over $200 this week", icon: "hand.raised.fill", color: Color(hex: "#818CF8"), isEarned: noSplurge),
            AppBadge(title: "Light Spender", description: "Used under 50% of your budget", icon: "leaf.fill", color: Color(hex: "#4ADE80"), isEarned: lightSpender),
            AppBadge(title: "Consistent", description: "Tracked expenses 5+ days this month", icon: "checkmark.seal.fill", color: Color.electricBlue, isEarned: consistent),
            AppBadge(title: "Frugal Week", description: "No entertainment or shopping this week", icon: "bolt.fill", color: Color(hex: "#FB923C"), isEarned: frugalWeek),
        ]
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Badges", systemImage: "medal.fill")
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(.appText)
                    Spacer()
                    Text("\(badges.filter(\.isEarned).count)/\(badges.count)")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.appSubtext)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(badges, id: \.title) { badge in
                        BadgeTile(badge: badge)
                    }
                }
            }
        }
    }
}

private struct BadgeTile: View {
    let badge: AppBadge
    @State private var appear = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.isEarned ? badge.color.opacity(0.18) : Color.appSubtext.opacity(0.05))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().strokeBorder(badge.isEarned ? badge.color.opacity(0.4) : Color.clear, lineWidth: 1.5))

                Image(systemName: badge.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(badge.isEarned ? badge.color : Color.appSubtext.opacity(0.2))
                    .scaleEffect(appear ? 1 : 0.6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1), value: appear)

                if !badge.isEarned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appSubtext.opacity(0.3))
                        .offset(x: 16, y: -16)
                }
            }

            Text(badge.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(badge.isEarned ? .white : .appSubtext)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .onAppear { appear = true }
    }
}
