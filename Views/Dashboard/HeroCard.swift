import SwiftUI

struct HeroCard: View {
    let totalSpent: Double
    let totalBudget: Double
    let daysLeft: Int
    let monthName: String

    @State private var animatedProgress: Double = 0
    @State private var animatedSpent: Double = 0
    private var progress: Double {
        guard totalBudget > 0 else { return 0 }
        return min(totalSpent / totalBudget, 1.0)
    }

    private var progressColor: Color { progress.progressColor(good: .electricBlue) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monthName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.appSubtext)
                            .textCase(.uppercase)
                            .tracking(1.2)
                        Text("Monthly Overview")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.appText)
                    }
                    Spacer()
                    Text("\(daysLeft)d left")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.appSubtext)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.appSubtext.opacity(0.06)))
                }

                // Circular Progress Ring + Center Display
                HStack(spacing: 24) {
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(Color.appSubtext.opacity(0.08), lineWidth: 10)
                            .frame(width: 120, height: 120)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: animatedProgress)
                            .stroke(
                                AngularGradient(
                                    colors: [progressColor.opacity(0.5), progressColor],
                                    center: .center,
                                    startAngle: .degrees(-90),
                                    endAngle: .degrees(270)
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: progressColor.opacity(0.4), radius: 8)

                        // Center text
                        VStack(spacing: 2) {
                            Text("\(Int(animatedProgress * 100))%")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.appText)
                            Text("used")
                                .font(.caption2)
                                .foregroundStyle(.appSubtext)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SPENT")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.appSubtext)
                                .tracking(1)
                            Text(animatedSpent.asCurrency)
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(.appText)
                                .contentTransition(.numericText(value: animatedSpent))
                        }

                        Rectangle()
                            .fill(Color.appSubtext.opacity(0.08))
                            .frame(height: 1)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("BUDGET")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.appSubtext)
                                .tracking(1)
                            Text(totalBudget.asCurrency)
                                .font(.system(.title2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.appSubtext)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("REMAINING")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.appSubtext)
                                .tracking(1)
                            Text(max(0, totalBudget - totalSpent).asCurrency)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(progressColor)
                        }
                    }
                    Spacer()
                }
            }
        }
        .shimmer()
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.1)) {
                animatedProgress = progress
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
                animatedSpent = totalSpent
            }
        }
        .onChange(of: totalSpent) { _, new in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedSpent    = new
                animatedProgress = progress
            }
        }
    }
}
