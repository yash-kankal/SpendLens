import SwiftUI

struct SpendingHeatmapCard: View {
    let expenses: [Expense]

    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var dailyTotals: [String: Double] {
        var totals: [String: Double] = [:]
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        for expense in expenses {
            let wd = cal.component(.weekday, from: expense.date)
            let index = (wd + 5) % 7
            let key = days[index]
            totals[key, default: 0] += expense.amount
        }
        return totals
    }

    private var maxTotal: Double { dailyTotals.values.max() ?? 1 }

    private var peakDay: String {
        dailyTotals.max(by: { $0.value < $1.value })?.key ?? ""
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Spending by Day", systemImage: "calendar.day.timeline.left")
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(.appText)
                    Spacer()
                    if !peakDay.isEmpty {
                        Text("Peak: \(peakDay)")
                            .font(.caption).foregroundStyle(.appSubtext)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let amount = dailyTotals[day] ?? 0
                        let intensity = maxTotal > 0 ? amount / maxTotal : 0

                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.electricBlue.opacity(0.15 + 0.85 * intensity),
                                            Color.electricBlue.opacity(0.05 + 0.6 * intensity)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.electricBlue.opacity(intensity * 0.5), lineWidth: 1)
                                )

                            Text(day)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.appSubtext)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                HStack(spacing: 8) {
                    Text("Less")
                        .font(.caption2).foregroundStyle(.appSubtext)
                    LinearGradient(
                        colors: [Color.electricBlue.opacity(0.15), Color.electricBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 6)
                    .clipShape(Capsule())
                    Text("More")
                        .font(.caption2).foregroundStyle(.appSubtext)
                }

                if !dailyTotals.isEmpty {
                    let sorted = days.compactMap { day -> (String, Double)? in
                        guard let val = dailyTotals[day], val > 0 else { return nil }
                        return (day, val)
                    }.sorted { $0.1 > $1.1 }

                    if let top = sorted.first {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.caption).foregroundStyle(Color(hex: "#FB923C"))
                            Text("You spend most on \(top.0)s — avg $\(Int(top.1 / max(Double(weekCount(for: top.0)), 1)))/week")
                                .font(.caption).foregroundStyle(.appSubtext)
                        }
                        .padding(10)
                        .background(Color(hex: "#FB923C").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func weekCount(for day: String) -> Int {
        let cal = Calendar.current
        let now = Date()
        let cutoff = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let recent = expenses.filter { $0.date >= cutoff }
        let index = days.firstIndex(of: day) ?? 0
        return Set(recent.compactMap { e -> String? in
            let wd = (cal.component(.weekday, from: e.date) + 5) % 7
            guard wd == index else { return nil }
            return cal.component(.weekOfYear, from: e.date).description
        }).count
    }
}
