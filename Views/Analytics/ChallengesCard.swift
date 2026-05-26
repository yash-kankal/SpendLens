import SwiftUI

struct SpendingChallenge {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let progress: Double
    let isCompleted: Bool
    let detail: String
}

struct ChallengesCard: View {
    let expenses: [Expense]

    private var challenges: [SpendingChallenge] {
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let thisWeek = expenses.filter { $0.date >= weekAgo }

        // Challenge 1: No eating out this week (food under $30 total)
        let foodSpend = thisWeek.filter { $0.category == .food }.reduce(0) { $0 + $1.amount }
        let foodTarget: Double = 30
        let foodProgress = min(foodSpend / foodTarget, 1.0)
        let foodDone = foodSpend <= foodTarget

        // Challenge 2: Weekly spend under $300
        let weekTotal = thisWeek.reduce(0) { $0 + $1.amount }
        let weekTarget: Double = 300
        let weekProgress = min(weekTotal / weekTarget, 1.0)
        let weekDone = weekTotal <= weekTarget

        // Challenge 3: No entertainment this week
        let entSpend = thisWeek.filter { $0.category == .entertainment }.reduce(0) { $0 + $1.amount }
        let entDone = entSpend == 0

        // Challenge 4: Save something this week
        let savedThisWeek = thisWeek.filter { $0.category == .savings }.reduce(0) { $0 + $1.amount }
        let saveTarget: Double = 50
        let saveProgress = min(savedThisWeek / saveTarget, 1.0)
        let saveDone = savedThisWeek >= saveTarget

        // Challenge 5: No shopping this week
        let shopSpend = thisWeek.filter { $0.category == .shopping }.reduce(0) { $0 + $1.amount }
        let shopDone = shopSpend == 0

        return [
            SpendingChallenge(
                title: "Meal Prep Week",
                description: "Keep food spending under $30",
                icon: "fork.knife",
                color: Color(hex: "#FF6B6B"),
                progress: foodDone ? 1 : foodProgress,
                isCompleted: foodDone,
                detail: foodDone ? "Completed! \(foodSpend.asCurrency) spent" : "\(foodSpend.asCurrency) of \(foodTarget.asCurrency) used"
            ),
            SpendingChallenge(
                title: "Budget Week",
                description: "Spend under $300 total this week",
                icon: "dollarsign.circle",
                color: Color.electricBlue,
                progress: weekDone ? 1 : weekProgress,
                isCompleted: weekDone,
                detail: weekDone ? "On track — \(weekTotal.asCurrency) spent" : "\(weekTotal.asCurrency) of \(weekTarget.asCurrency)"
            ),
            SpendingChallenge(
                title: "Entertainment Fast",
                description: "No entertainment spending this week",
                icon: "tv.slash",
                color: Color(hex: "#818CF8"),
                progress: entDone ? 1 : 0,
                isCompleted: entDone,
                detail: entDone ? "Clean week so far!" : "\(entSpend.asCurrency) spent on entertainment"
            ),
            SpendingChallenge(
                title: "Save $50",
                description: "Add $50+ to savings this week",
                icon: "arrow.up.circle.fill",
                color: Color(hex: "#34D399"),
                progress: saveProgress,
                isCompleted: saveDone,
                detail: saveDone ? "Goal reached!" : "\(savedThisWeek.asCurrency) of \(saveTarget.asCurrency) saved"
            ),
            SpendingChallenge(
                title: "No Shopping",
                description: "Avoid all shopping this week",
                icon: "bag.slash.fill",
                color: Color(hex: "#FB923C"),
                progress: shopDone ? 1 : 0,
                isCompleted: shopDone,
                detail: shopDone ? "No shopping yet!" : "\(shopSpend.asCurrency) spent on shopping"
            ),
        ]
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Weekly Challenges", systemImage: "flag.checkered")
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(.appText)
                    Spacer()
                    Text("\(challenges.filter(\.isCompleted).count)/\(challenges.count) done")
                        .font(.caption).foregroundStyle(.appSubtext)
                }

                VStack(spacing: 10) {
                    ForEach(challenges, id: \.title) { challenge in
                        ChallengeTile(challenge: challenge)
                    }
                }
            }
        }
    }
}

private struct ChallengeTile: View {
    let challenge: SpendingChallenge
    @State private var animatedProgress: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(challenge.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: challenge.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(challenge.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(challenge.title)
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.appText)
                    Spacer()
                    if challenge.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(hex: "#34D399"))
                            .font(.caption)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.appSubtext.opacity(0.08))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(challenge.isCompleted ? Color(hex: "#34D399") : challenge.color)
                            .frame(width: geo.size.width * animatedProgress, height: 5)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1), value: animatedProgress)
                    }
                }
                .frame(height: 5)

                Text(challenge.detail)
                    .font(.caption2).foregroundStyle(.appSubtext)
            }
        }
        .padding(12)
        .background(Color.appSubtext.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { animatedProgress = challenge.progress }
    }
}
