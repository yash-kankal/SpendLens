import SwiftUI
import Charts

private struct WeekBar: Identifiable {
    let id = UUID()
    let day: String
    let amount: Double
    let week: String
    let order: Int
}

struct WeekComparisonCard: View {
    let expenses: [Expense]

    private var data: [WeekBar] {
        let cal = Calendar.current
        let now = Date()
        let abbr = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var result: [WeekBar] = []

        for offset in 0..<7 {
            let date = cal.date(byAdding: .day, value: -(6 - offset), to: now)!
            let wd = (cal.component(.weekday, from: date) + 5) % 7
            let start = cal.startOfDay(for: date)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            let total = expenses.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.amount }
            result.append(WeekBar(day: abbr[wd], amount: total, week: "This Week", order: offset))
        }
        for offset in 0..<7 {
            let date = cal.date(byAdding: .day, value: -(13 - offset), to: now)!
            let wd = (cal.component(.weekday, from: date) + 5) % 7
            let start = cal.startOfDay(for: date)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            let total = expenses.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.amount }
            result.append(WeekBar(day: abbr[wd], amount: total, week: "Last Week", order: offset))
        }
        return result
    }

    private var thisWeekTotal: Double { data.filter { $0.week == "This Week" }.reduce(0) { $0 + $1.amount } }
    private var lastWeekTotal: Double { data.filter { $0.week == "Last Week" }.reduce(0) { $0 + $1.amount } }
    private var change: Double { lastWeekTotal > 0 ? ((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100 : 0 }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Week over Week", systemImage: "calendar.badge.clock")
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(.appText)
                    Spacer()
                    if lastWeekTotal > 0 {
                        Text(change >= 0 ? "+\(Int(change))%" : "\(Int(change))%")
                            .font(.caption).fontWeight(.bold)
                            .foregroundStyle(change <= 0 ? Color(hex: "#34D399") : Color(hex: "#FF6B6B"))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background((change <= 0 ? Color(hex: "#34D399") : Color(hex: "#FF6B6B")).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Chart(data) { bar in
                    BarMark(x: .value("Day", bar.day), y: .value("$", bar.amount))
                        .foregroundStyle(by: .value("Week", bar.week))
                        .position(by: .value("Week", bar.week))
                        .cornerRadius(4)
                }
                .chartForegroundStyleScale(["This Week": Color.electricBlue, "Last Week": Color.appSubtext.opacity(0.2)])
                .chartLegend(position: .top, alignment: .trailing)
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
                    statPill(label: "This Week", value: thisWeekTotal, color: .electricBlue)
                    Spacer()
                    statPill(label: "Last Week", value: lastWeekTotal, color: Color.appSubtext.opacity(0.4))
                }
            }
        }
    }

    private func statPill(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.appSubtext)
            Text("$\(Int(value))").font(.subheadline).fontWeight(.bold).foregroundStyle(color)
        }
    }
}
