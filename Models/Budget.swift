import Foundation

struct Budget: Identifiable, Codable {
    var id: String = UUID().uuidString
    var ownerId: String = ""
    var month: Int = 0
    var year: Int = 0
    var totalBudget: Double = 3000
    var categoryLimits: [String: Double] = [:]

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case month
        case year
        case totalBudget = "total_budget"
        case categoryLimits = "category_limits"
    }

    init(
        id: String = UUID().uuidString,
        ownerId: String,
        month: Int,
        year: Int,
        totalBudget: Double = 3000,
        categoryLimits: [String: Double] = [:]
    ) {
        self.id = id
        self.ownerId = ownerId
        self.month = month
        self.year = year
        self.totalBudget = totalBudget
        self.categoryLimits = categoryLimits
    }

    static func defaultCategoryLimits() -> [String: Double] {
        return [
            ExpenseCategory.food.rawValue: 600,
            ExpenseCategory.transport.rawValue: 200,
            ExpenseCategory.shopping.rawValue: 400,
            ExpenseCategory.entertainment.rawValue: 200,
            ExpenseCategory.health.rawValue: 150,
            ExpenseCategory.utilities.rawValue: 200,
            ExpenseCategory.rent.rawValue: 1000,
            ExpenseCategory.savings.rawValue: 200,
            ExpenseCategory.other.rawValue: 50
        ]
    }
}
