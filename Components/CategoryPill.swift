import SwiftUI

struct CategoryPill: View {
    let category: ExpenseCategory
    var isSelected: Bool = false
    var size: PillSize = .medium
    var action: (() -> Void)? = nil

    enum PillSize {
        case small, medium, large
        var iconSize: CGFloat { self == .small ? 12 : self == .medium ? 16 : 20 }
        var fontSize: Font { self == .small ? .caption : self == .medium ? .subheadline : .body }
        var padding: EdgeInsets {
            switch self {
            case .small: return .init(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium: return .init(top: 8, leading: 14, bottom: 8, trailing: 14)
            case .large: return .init(top: 12, leading: 18, bottom: 12, trailing: 18)
            }
        }
    }

    var body: some View {
        Button {
            action?()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundStyle(category.color)
                Text(category.displayName)
                    .font(size.fontSize)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .appSubtext)
            }
            .padding(size.padding)
            .background {
                Capsule()
                    .fill(isSelected ? category.color.opacity(0.3) : Color.appSubtext.opacity(0.06))
                    .overlay {
                        Capsule()
                            .stroke(
                                isSelected ? category.color.opacity(0.6) : Color.appSubtext.opacity(0.1),
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Category Icon Pill (compact, for transaction rows)
struct CategoryIconPill: View {
    let category: ExpenseCategory
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(category.color.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: category.icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(category.color)
        }
    }
}
