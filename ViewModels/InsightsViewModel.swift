import SwiftUI

// MARK: - Chat Message
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

// MARK: - ViewModel
@MainActor
@Observable
class InsightsViewModel {
    var insightResult: InsightResult? = nil
    var isLoading = false
    var showChat = false
    var chatMessages: [ChatMessage] = []
    var chatInput = ""
    var isChatLoading = false

    func loadInsights(expenses: [Expense], budget: Budget?) async {
        guard !isLoading else { return }
        isLoading = true
        let result = await OpenAIService.shared.generateInsights(expenses: expenses, budget: budget)
        insightResult = result
        isLoading = false
    }

    func sendChatMessage(expenses: [Expense]) async {
        let message = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isChatLoading else { return }

        chatMessages.append(ChatMessage(role: "user", content: message))
        chatInput = ""
        isChatLoading = true

        let reply = await OpenAIService.shared.chatWithData(userMessage: message, expenses: expenses)

        chatMessages.append(ChatMessage(role: "assistant", content: reply))
        isChatLoading = false
    }

    func spendingCurveData(from expenses: [Expense]) -> [(day: Int, actual: Double, projected: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let currentDay = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30

        let currentMonth = calendar.component(.month, from: now)
        let currentYear  = calendar.component(.year,  from: now)
        let monthExpenses = expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year,  from: $0.date) == currentYear
        }

        var dailyTotals: [Int: Double] = [:]
        for expense in monthExpenses {
            let day = calendar.component(.day, from: expense.date)
            dailyTotals[day, default: 0] += expense.amount
        }

        var cumulative = 0.0
        var result: [(day: Int, actual: Double, projected: Double)] = []
        var totalSoFar = 0.0

        for day in 1...daysInMonth {
            totalSoFar += dailyTotals[day] ?? 0
            if day <= currentDay {
                cumulative = totalSoFar
                result.append((day: day, actual: cumulative, projected: 0))
            } else {
                let dailyAvg = currentDay > 0 ? cumulative / Double(currentDay) : 0
                let proj = cumulative + dailyAvg * Double(day - currentDay)
                result.append((day: day, actual: 0, projected: proj))
            }
        }

        return result
    }
}
