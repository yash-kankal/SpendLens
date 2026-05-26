import Foundation

struct SplitExpense: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String = ""
    var totalAmount: Double = 0
    var paidByUserId: String = ""
    var paidByName: String = ""
    var participantIds: [String] = []
    /// What each non-payer owes the payer: [userId: amount]
    var shares: [String: Double] = [:]
    /// Whether each non-payer has settled with the payer: [userId: Bool]
    var settled: [String: Bool] = [:]
    var date: Date = Date()
    var note: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case totalAmount = "total_amount"
        case paidByUserId = "paid_by_user_id"
        case paidByName = "paid_by_name"
        case participantIds = "participant_ids"
        case shares
        case settled
        case date
        case note
    }

    func amountOwed(by userId: String) -> Double {
        guard userId != paidByUserId else { return 0 }
        return shares[userId] ?? 0
    }

    func isSettled(by userId: String) -> Bool {
        guard userId != paidByUserId else { return true }
        return settled[userId] ?? false
    }

    func unsettledAmount(for userId: String) -> Double {
        isSettled(by: userId) ? 0 : amountOwed(by: userId)
    }
}
