import SwiftUI

struct DonutChartView: View {
    let breakdown: [(ExpenseCategory, Double)]
    let selectedCategory: ExpenseCategory?
    let onTap: (ExpenseCategory) -> Void

    @State private var tappedSegment: ExpenseCategory? = nil

    private var total: Double { breakdown.reduce(0) { $0 + $1.1 } }

    private struct Segment {
        let category: ExpenseCategory
        let amount: Double
        let startAngle: Double
        let endAngle: Double
    }

    private var segments: [Segment] {
        guard total > 0 else { return [] }
        var currentAngle = -90.0
        return breakdown.map { (cat, amount) in
            let fraction = amount / total
            let sweep = fraction * 360
            let seg = Segment(
                category: cat,
                amount: amount,
                startAngle: currentAngle,
                endAngle: currentAngle + sweep
            )
            currentAngle += sweep
            return seg
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Chart
            ZStack {
                // Draw segments using Canvas
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 8
                    let innerRadius = radius * 0.55
                    for seg in segments {
                        let isSelected = selectedCategory == seg.category
                        let effectiveRadius = isSelected ? radius + 6 : radius
                        let effectiveInner = isSelected ? innerRadius + 2 : innerRadius

                        var path = Path()
                        path.addArc(
                            center: center,
                            radius: effectiveRadius,
                            startAngle: .degrees(seg.startAngle),
                            endAngle: .degrees(seg.endAngle),
                            clockwise: false
                        )
                        path.addArc(
                            center: center,
                            radius: effectiveInner,
                            startAngle: .degrees(seg.endAngle),
                            endAngle: .degrees(seg.startAngle),
                            clockwise: true
                        )
                        path.closeSubpath()

                        let opacity = selectedCategory == nil || isSelected ? 1.0 : 0.3
                        context.fill(path, with: .color(seg.category.color.opacity(opacity)))

                        if isSelected {
                            context.stroke(path, with: .color(seg.category.color), lineWidth: 2)
                        }
                    }
                }
                .frame(width: 180, height: 180)
                .onTapGesture { location in
                    handleTap(at: location, in: CGSize(width: 180, height: 180))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedCategory)

                // Center label
                VStack(spacing: 2) {
                    if let selected = selectedCategory,
                       let item = breakdown.first(where: { $0.0 == selected }) {
                        Image(systemName: selected.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selected.color)
                        Text("$\(Int(item.1))")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.appText)
                        Text(selected.displayName)
                            .font(.caption2)
                            .foregroundStyle(.appSubtext)
                    } else {
                        Text("Total")
                            .font(.caption2)
                            .foregroundStyle(.appSubtext)
                        Text(total.asCurrency)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.appText)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedCategory)
            }

            // Legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(breakdown, id: \.0) { category, amount in
                        let pct = total > 0 ? Int((amount / total) * 100) : 0
                        let isSelected = selectedCategory == category

                        Button {
                            onTap(category)
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(category.displayName)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(isSelected ? .white : .appSubtext)
                                    Text("\(amount.asCurrency) · \(pct)%")
                                        .font(.caption2)
                                        .foregroundStyle(isSelected ? category.color : .appSubtext.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background {
                                Capsule()
                                    .fill(isSelected ? category.color.opacity(0.15) : Color.appSubtext.opacity(0.05))
                                    .overlay {
                                        Capsule()
                                            .stroke(
                                                isSelected ? category.color.opacity(0.4) : Color.clear,
                                                lineWidth: 1
                                            )
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let radius = min(size.width, size.height) / 2 - 8
        let innerRadius = radius * 0.55

        guard distance > innerRadius && distance < radius + 8 else { return }

        var angle = atan2(dy, dx) * 180 / .pi
        if angle < -90 { angle += 360 }
        angle += 90

        for seg in segments {
            let start = seg.startAngle + 90
            let end = seg.endAngle + 90
            if angle >= start && angle <= end {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap(seg.category)
                return
            }
        }
    }
}
