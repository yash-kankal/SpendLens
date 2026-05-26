import SwiftUI

// MARK: - Savings Card
struct SavingsInsightCard: View {
    let savedAmount: Double
    let lastMonthSavings: Double
    let tip: String

    @State private var animatedSaved: Double = 0
    @State private var appear = false

    private var isOverBudget: Bool { savedAmount < 0 }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Label("Savings Summary", systemImage: "banknote.fill")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.appText)
                    Spacer()
                    Image(systemName: "sparkles")
                        .foregroundStyle(.electricBlue)
                }

                // Saved amount
                Text("$\(Int(abs(animatedSaved)))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(isOverBudget ? Color(hex: "#FF6B6B") : Color(hex: "#34D399"))
                    .contentTransition(.numericText(value: animatedSaved))

                Text(isOverBudget ? "over budget this month" : "left in your budget")
                    .font(.caption)
                    .foregroundStyle(.appSubtext)

                // Bar comparison
                VStack(alignment: .leading, spacing: 6) {
                    Text("VS. LAST MONTH")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.appSubtext)
                        .tracking(0.8)

                    let thisMonthValue = max(savedAmount, 0)
                    let maxVal = max(thisMonthValue, lastMonthSavings, 1)
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This Month")
                                .font(.caption2)
                                .foregroundStyle(.appSubtext)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#34D399"))
                                    .frame(width: appear ? geo.size.width * CGFloat(thisMonthValue / maxVal) : 0)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: appear)
                            }
                            .frame(height: 8)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Month")
                                .font(.caption2)
                                .foregroundStyle(.appSubtext)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.appSubtext.opacity(0.2))
                                    .frame(width: appear ? geo.size.width * CGFloat(lastMonthSavings / maxVal) : 0)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: appear)
                            }
                            .frame(height: 8)
                        }
                    }
                }

                // AI Tip
                if !tip.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.electricBlue)
                        Text(tip)
                            .font(.caption)
                            .foregroundStyle(.appSubtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color.electricBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .onAppear {
            appear = true
            withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
                animatedSaved = savedAmount
            }
        }
    }
}

// MARK: - Prediction Card
struct PredictionInsightCard: View {
    let projectedSpend: Double
    let budget: Double?
    let curveData: [(day: Int, actual: Double, projected: Double)]

    @State private var appear = false

    private var isOverBudget: Bool {
        guard let budget else { return false }
        return projectedSpend > budget
    }
    private var predictionColor: Color {
        budget == nil ? Color.electricBlue : (isOverBudget ? Color(hex: "#FF6B6B") : Color(hex: "#34D399"))
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Spending Prediction", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.appText)
                    Spacer()
                    if isOverBudget {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(hex: "#FB923C"))
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$\(Int(projectedSpend))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(predictionColor)
                    Text("by month end")
                        .font(.caption)
                        .foregroundStyle(.appSubtext)
                }

                Text(isOverBudget
                     ? "You'll exceed your \((budget ?? 0).asCurrency) budget by \((projectedSpend - (budget ?? 0)).asCurrency)."
                     : budget.map { "You're on track to stay within your \($0.asCurrency) budget." } ?? "Set a budget to see exactly how much room you have.")
                    .font(.caption)
                    .foregroundStyle(.appSubtext)

                // Spend curve chart
                GeometryReader { geo in
                    spendCurveCanvas(size: geo.size)
                }
                .frame(height: 80)
            }
        }
        .onAppear { appear = true }
    }

    @ViewBuilder
    private func spendCurveCanvas(size: CGSize) -> some View {
        Canvas { context, _ in
            guard !curveData.isEmpty else { return }

            let maxDay = curveData.map { $0.day }.max() ?? 30
            let maxAmount = max(
                curveData.map { max($0.actual, $0.projected) }.max() ?? 1,
                budget ?? 1
            )

            let scaleX = size.width / CGFloat(maxDay)
            let scaleY = size.height / CGFloat(maxAmount)

            // Budget line
            if let budget {
                var budgetPath = Path()
                budgetPath.move(to: CGPoint(x: 0, y: size.height - CGFloat(budget) * scaleY))
                budgetPath.addLine(to: CGPoint(x: size.width, y: size.height - CGFloat(budget) * scaleY))
                context.stroke(budgetPath, with: .color(Color.appSubtext.opacity(0.15)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            // Actual curve
            var actualPath = Path()
            var firstActual = true
            for point in curveData where point.actual > 0 {
                let x = CGFloat(point.day) * scaleX
                let y = size.height - CGFloat(point.actual) * scaleY
                if firstActual { actualPath.move(to: CGPoint(x: x, y: y)); firstActual = false }
                else { actualPath.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(actualPath, with: .color(.electricBlue), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            // Projected curve (dashed)
            var projPath = Path()
            var firstProj = true
            for point in curveData where point.projected > 0 {
                let x = CGFloat(point.day) * scaleX
                let y = size.height - CGFloat(point.projected) * scaleY
                if firstProj { projPath.move(to: CGPoint(x: x, y: y)); firstProj = false }
                else { projPath.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(projPath, with: .color(isOverBudget ? Color(hex: "#FF6B6B") : Color(hex: "#34D399")),
                          style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4]))
        }
    }
}

// MARK: - Budget Recommendations Card
struct BudgetRecommendationsCard: View {
    let tips: [String]
    let onApply: (String) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Budget Recommendations", systemImage: "brain.head.profile")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.appText)

                VStack(spacing: 10) {
                    ForEach(Array(tips.prefix(3).enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.electricBlue)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Color.electricBlue.opacity(0.15)))

                            Text(tip)
                                .font(.caption)
                                .foregroundStyle(.appSubtext)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(Color.appSubtext.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}

// MARK: - Smart Patterns Card
struct SmartPatternsCard: View {
    let patterns: [String]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Smart Patterns", systemImage: "waveform.path.ecg")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.appText)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(patterns, id: \.self) { pattern in
                        HStack(spacing: 10) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption)
                                .foregroundStyle(.electricBlue)
                            Text(pattern)
                                .font(.caption)
                                .foregroundStyle(.appSubtext)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Saving Opportunities Card
struct SavingOpportunitiesCard: View {
    let opportunities: [String]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Where to Save", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.appText)

                VStack(spacing: 10) {
                    ForEach(Array(opportunities.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#34D399"))
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(.appSubtext)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(Color(hex: "#34D399").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}

// MARK: - Spend Less On Card
struct SpendLessOnCard: View {
    let categories: [String]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Spend Less On", systemImage: "scissors")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.appText)

                VStack(spacing: 10) {
                    ForEach(Array(categories.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "minus.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#FB923C"))
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(.appSubtext)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(Color(hex: "#FB923C").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}
