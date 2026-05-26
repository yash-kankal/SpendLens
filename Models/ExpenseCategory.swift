import SwiftUI

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "food"
    case transport = "transport"
    case shopping = "shopping"
    case entertainment = "entertainment"
    case health = "health"
    case utilities = "utilities"
    case rent = "rent"
    case savings = "savings"
    case other = "other"

    var displayName: String {
        switch self {
        case .food: return "Food"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .health: return "Health"
        case .utilities: return "Utilities"
        case .rent: return "Rent"
        case .savings: return "Savings"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .entertainment: return "tv.fill"
        case .health: return "heart.fill"
        case .utilities: return "bolt.fill"
        case .rent: return "house.fill"
        case .savings: return "banknote.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return Color(hex: "#FF6B6B")
        case .transport: return Color(hex: "#4ECDC4")
        case .shopping: return Color(hex: "#FFE66D")
        case .entertainment: return Color(hex: "#A855F7")
        case .health: return Color(hex: "#22D3EE")
        case .utilities: return Color(hex: "#FB923C")
        case .rent: return Color(hex: "#34D399")
        case .savings: return Color(hex: "#4F8EF7")
        case .other: return Color(hex: "#94A3B8")
        }
    }
}
