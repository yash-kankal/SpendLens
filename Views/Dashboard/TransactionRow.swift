import SwiftUI

struct TransactionRow: View {
    let expense: Expense
    let onDelete: () -> Void
    let onToggleRecurring: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDeleteConfirm = false

    private let actionThreshold: CGFloat = 70

    var body: some View {
        ZStack {
            HStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#22D3EE").opacity(0.25))
                    .overlay(
                        HStack {
                            Image(systemName: expense.isRecurring ? "arrow.2.circlepath.circle.fill" : "arrow.2.circlepath")
                                .font(.title3).foregroundStyle(Color(hex: "#22D3EE"))
                            Text(expense.isRecurring ? "Remove" : "Recurring")
                                .font(.caption).fontWeight(.semibold).foregroundStyle(Color(hex: "#22D3EE"))
                            Spacer()
                        }.padding(.leading, 16)
                    )
                    .opacity(offset > 20 ? Double(min(offset / actionThreshold, 1.0)) : 0)

                Spacer()

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#FF6B6B").opacity(0.25))
                    .overlay(
                        HStack {
                            Spacer()
                            Text("Delete").font(.caption).fontWeight(.semibold).foregroundStyle(Color(hex: "#FF6B6B"))
                            Image(systemName: "trash.fill").font(.title3).foregroundStyle(Color(hex: "#FF6B6B"))
                        }.padding(.trailing, 16)
                    )
                    .opacity(offset < -20 ? Double(min(-offset / actionThreshold, 1.0)) : 0)
            }

            rowContent
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let t = value.translation.width
                            offset = abs(t) > actionThreshold
                                ? (t > 0 ? actionThreshold + (t - actionThreshold) * 0.2 : -actionThreshold + (t + actionThreshold) * 0.2)
                                : t
                        }
                        .onEnded { value in
                            let t = value.translation.width
                            if t < -actionThreshold {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showDeleteConfirm = true
                            } else if t > actionThreshold {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onToggleRecurring()
                            }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { offset = 0 }
                        }
                )
        }
        .frame(maxWidth: .infinity)
        .confirmationDialog("Delete \"\(expense.title)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            CategoryIconPill(category: expense.category, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(expense.title)
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.appText).lineLimit(1)
                    if expense.isRecurring {
                        Image(systemName: "arrow.2.circlepath").font(.caption2).foregroundStyle(.appSubtext)
                    }
                }
                HStack(spacing: 6) {
                    Text(expense.date.timeFormatted).font(.caption).foregroundStyle(.appSubtext)
                    if let tag = expense.aiTag {
                        Text(tag).font(.caption2).fontWeight(.semibold).foregroundStyle(Color.electricBlue)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.electricBlue.opacity(0.12)))
                    }
                }
            }

            Spacer()

            Text("-\(expense.amount.asCurrency)")
                .font(.subheadline).fontWeight(.bold).foregroundStyle(Color(hex: "#FF6B6B"))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSubtext.opacity(0.04))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.appSubtext.opacity(0.06), lineWidth: 1) }
        }
    }
}
