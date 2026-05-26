import Foundation

struct Expense: Identifiable, Codable {
    var id: String = UUID().uuidString
    var ownerId: String = ""
    var title: String = ""
    var amount: Double = 0
    var category: ExpenseCategory = .other
    var date: Date = Date()
    var note: String? = nil
    var isRecurring: Bool = false
    var aiTag: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case amount
        case category
        case date
        case note
        case isRecurring = "is_recurring"
        case aiTag = "ai_tag"
    }

    init(
        id: String = UUID().uuidString,
        ownerId: String,
        title: String,
        amount: Double,
        category: ExpenseCategory,
        date: Date = Date(),
        note: String? = nil,
        isRecurring: Bool = false,
        aiTag: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
        self.note = note
        self.isRecurring = isRecurring
        self.aiTag = aiTag
    }
}
