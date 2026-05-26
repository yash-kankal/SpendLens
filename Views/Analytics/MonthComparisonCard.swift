import SwiftUI
import Charts

private struct MonthBar: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let order: Int
}

struct MonthComparisonCard: View {
    let expenses: [Expense]

    private var data: [MonthBar] {
        let cal = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var result: [MonthBar] = []

        for i in 0..<4 {
            let date = cal.date(byAdding: .month, value: -i, to: now)!
            let comps = cal.dateComponents([.year, .month], from: date)
            let start = cal.date(from: comps)!
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            let total = expenses.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.amount }
            result.append(MonthBar(label: formatter.string(from: date), amount: total, order: 3 - i))
        }
        return result.sorted { $0.order < $1.order }
    }

    private var currentMonthTotal: Double { data.last?.amount ?? 0 }
    private var previousMonthTotal: Double { data.dropLast().last?.amount ?? 0 }
    private var change: Double {
        previousMonthTotal > 0 ? ((currentMonthTotal - previousMonthTotal) / previousMonthTotal) * 100 : 0
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Month over Month", systemImage: "chart.bar.xaxis")
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(.appText)
                    Spacer()
                    if previousMonthTotal > 0 {
                        Text(change >= 0 ? "+\(Int(change))%" : "\(Int(change))%")
                            .font(.caption).fontWeight(.bold)
                            .foregroundStyle(change <= 0 ? Color(hex: "#34D399") : Color(hex: "#FF6B6B"))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background((change <= 0 ? Color(hex: "#34D399") : Color(hex: "#FF6B6B")).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Chart(data) { bar in
                    BarMark(x: .value("Month", bar.label), y: .value("$", bar.amount))
                        .foregroundStyle(
                            bar.order == 3
                                ? LinearGradient(colors: [Color.electricBlue, Color.electricBlue.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [Color.appSubtext.opacity(0.25), Color.appSubtext.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(6)
                    if bar.amount > 0 {
                        RuleMark(y: .value("avg", data.filter { $0.amount > 0 }.map(\.amount).reduce(0, +) / Double(max(data.filter { $0.amount > 0 }.count, 1))))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.appSubtext.opacity(0.2))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("avg").font(.caption2).foregroundStyle(.appSubtext)
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisValueLabel().foregroundStyle(Color.appSubtext).font(.caption2)
                        AxisGridLine().foregroundStyle(Color.appSubtext.opacity(0.06))
                    }
                }
                .chartXAxis {
                    AxisMarks { AxisValueLabel().foregroundStyle(Color.appSubtext).font(.caption2) }
                }
                .frame(height: 160)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This Month").font(.caption2).foregroundStyle(.appSubtext)
                        Text("$\(Int(currentMonthTotal))").font(.subheadline).fontWeight(.bold).foregroundStyle(.electricBlue)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last Month").font(.caption2).foregroundStyle(.appSubtext)
                        Text("$\(Int(previousMonthTotal))").font(.subheadline).fontWeight(.bold).foregroundStyle(Color.appSubtext.opacity(0.5))
                    }
                }
            }
        }
    }
}
