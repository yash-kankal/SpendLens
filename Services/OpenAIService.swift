import Foundation

// MARK: - Models
struct InsightResult: Codable {
    var savedAmount: Double
    var projectedSpend: Double
    var budgetTips: [String]
    var patterns: [String]
    var lastMonthSavings: Double
    var savingOpportunities: [String]
    var spendLessOn: [String]
}

struct ExpenseCategorySuggestion {
    let category: ExpenseCategory
    let source: String
}

private struct AIFunctionRequest: Encodable {
    var task: String
    var title: String? = nil
    var userMessage: String? = nil
    var expensesJSON: String? = nil
    var localSummary: String? = nil
    var budgetTotal: Double? = nil
    var currentDay: Int? = nil
    var daysInMonth: Int? = nil
}

private struct AIFunctionResponse: Decodable {
    var category: String?
    var source: String?
    var content: String?
    var insight: InsightResult?
}

class OpenAIService {
    static let shared = OpenAIService()
    private init() {}

    private static let iso8601 = ISO8601DateFormatter()

    // MARK: - Auto Tag Expense (gpt-4o-mini)
    func autoTagExpense(title: String) async -> String {
        await suggestCategory(title: title).category.rawValue
    }

    func suggestCategory(title: String) async -> ExpenseCategorySuggestion {
        do {
            let response: AIFunctionResponse = try await SupabaseService.shared.invokeFunction(
                "ai",
                body: AIFunctionRequest(task: "categorize", title: title)
            )
            let category = ExpenseCategory.allCases.first { $0.rawValue == normalizeCategory(response.category ?? "") } ?? localCategory(for: title)
            return ExpenseCategorySuggestion(category: category, source: response.source ?? "AI")
        } catch {
            return ExpenseCategorySuggestion(category: localCategory(for: title), source: "Smart")
        }
    }

    // MARK: - Generate Insights (gpt-4o)
    func generateInsights(expenses: [Expense], budget: Budget?) async -> InsightResult {
        let snapshot = buildSnapshot(expenses: expenses, budget: budget)
        var result = localInsightResult(snapshot: snapshot)

        do {
            let response: AIFunctionResponse = try await SupabaseService.shared.invokeFunction(
                "ai",
                body: AIFunctionRequest(
                    task: "insights",
                    expensesJSON: expensesToJSON(snapshot.currentMonthExpenses),
                    localSummary: snapshot.promptSummary,
                    budgetTotal: budget?.totalBudget,
                    currentDay: snapshot.currentDay,
                    daysInMonth: snapshot.daysInMonth
                )
            )
            if let aiInsight = response.insight {
                result.budgetTips = cleanList(aiInsight.budgetTips, fallback: result.budgetTips)
                result.patterns = cleanList(aiInsight.patterns, fallback: result.patterns)
                result.savingOpportunities = cleanList(aiInsight.savingOpportunities, fallback: result.savingOpportunities)
                result.spendLessOn = cleanList(aiInsight.spendLessOn, fallback: result.spendLessOn)
            }
        } catch {
            return result
        }

        return result
    }

    // MARK: - Chat With Data (gpt-4o)
    func chatWithData(userMessage: String, expenses: [Expense]) async -> String {
        let expenseJSON = expensesToJSON(expenses)
        do {
            let response: AIFunctionResponse = try await SupabaseService.shared.invokeFunction(
                "ai",
                body: AIFunctionRequest(task: "chat", userMessage: userMessage, expensesJSON: expenseJSON)
            )
            return response.content ?? "Sorry, I couldn't process that. Please try again."
        } catch {
            return "Sorry, I couldn't process that. Please try again."
        }
    }

    // MARK: - Helpers
    private func expensesToJSON(_ expenses: [Expense]) -> String {
        let items = expenses.map { e -> [String: Any] in
            var item: [String: Any] = [
                "title": e.title,
                "amount": e.amount,
                "category": e.category.rawValue,
                "date": Self.iso8601.string(from: e.date)
            ]
            if let note = e.note { item["note"] = note }
            return item
        }
        guard let data = try? JSONSerialization.data(withJSONObject: items, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private struct InsightSnapshot {
        let currentMonthExpenses: [Expense]
        let lastMonthExpenses: [Expense]
        let currentSpent: Double
        let lastMonthSpent: Double
        let projectedSpend: Double
        let budgetTotal: Double?
        let currentDay: Int
        let daysInMonth: Int
        let categoryTotals: [(ExpenseCategory, Double)]

        var promptSummary: String {
            let budgetText = budgetTotal.map { "$\(Int($0))" } ?? "not set"
            let categoryText = categoryTotals
                .prefix(5)
                .map { "\($0.0.displayName): $\(Int($0.1))" }
                .joined(separator: ", ")
            return [
                "Current month spent: $\(Int(currentSpent))",
                "Projected month-end spend: $\(Int(projectedSpend))",
                "Budget: \(budgetText)",
                "Last month spend: $\(Int(lastMonthSpent))",
                "Top categories: \(categoryText.isEmpty ? "none yet" : categoryText)",
            ].joined(separator: "\n")
        }
    }

    private func buildSnapshot(expenses: [Expense], budget: Budget?) -> InsightSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = max(1, calendar.component(.day, from: now))
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let lastMonth = calendar.component(.month, from: lastMonthDate)
        let lastMonthYear = calendar.component(.year, from: lastMonthDate)

        let currentMonthExpenses = expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
                calendar.component(.year, from: $0.date) == currentYear
        }
        let lastMonthExpenses = expenses.filter {
            calendar.component(.month, from: $0.date) == lastMonth &&
                calendar.component(.year, from: $0.date) == lastMonthYear
        }
        let currentSpent = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        let lastMonthSpent = lastMonthExpenses.reduce(0) { $0 + $1.amount }
        let projected = currentSpent == 0 ? 0 : (currentSpent / Double(currentDay)) * Double(daysInMonth)

        var totalsByCategory: [ExpenseCategory: Double] = [:]
        for expense in currentMonthExpenses {
            totalsByCategory[expense.category, default: 0] += expense.amount
        }
        let categoryTotals = totalsByCategory
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }

        return InsightSnapshot(
            currentMonthExpenses: currentMonthExpenses,
            lastMonthExpenses: lastMonthExpenses,
            currentSpent: currentSpent,
            lastMonthSpent: lastMonthSpent,
            projectedSpend: projected,
            budgetTotal: budget?.totalBudget,
            currentDay: currentDay,
            daysInMonth: daysInMonth,
            categoryTotals: categoryTotals
        )
    }

    private func localInsightResult(snapshot: InsightSnapshot) -> InsightResult {
        let remainingBudget = (snapshot.budgetTotal ?? snapshot.projectedSpend) - snapshot.currentSpent
        let projectedRemaining = (snapshot.budgetTotal ?? snapshot.projectedSpend) - snapshot.projectedSpend
        let topCategory = snapshot.categoryTotals.first
        let dailyAverage = snapshot.currentSpent / Double(max(1, snapshot.currentDay))
        let safeDailySpend = snapshot.budgetTotal.map {
            max(0, ($0 - snapshot.currentSpent) / Double(max(1, snapshot.daysInMonth - snapshot.currentDay)))
        }

        var tips: [String] = []
        if let safeDailySpend {
            tips.append("You can spend about $\(Int(safeDailySpend)) per day for the rest of the month and stay on budget.")
        }
        if let topCategory {
            tips.append("\(topCategory.0.displayName) is your biggest category at $\(Int(topCategory.1)); trim 10% there to save about $\(Int(topCategory.1 * 0.1)).")
        }
        if snapshot.projectedSpend > (snapshot.budgetTotal ?? .greatestFiniteMagnitude) {
            tips.append("Your current pace is over budget. Pause non-essential purchases for 48 hours and re-check the forecast.")
        } else if snapshot.currentSpent > 0 {
            tips.append("Your current pace is $\(Int(dailyAverage)) per day. Keep weekly spending under $\(Int(dailyAverage * 7)) to hold this trend.")
        }

        return InsightResult(
            savedAmount: remainingBudget,
            projectedSpend: snapshot.projectedSpend,
            budgetTips: tips.isEmpty ? ["Add a few expenses this month and SpendLens will build a useful plan."] : tips,
            patterns: localPatterns(snapshot: snapshot),
            lastMonthSavings: max(0, (snapshot.budgetTotal ?? snapshot.lastMonthSpent) - snapshot.lastMonthSpent),
            savingOpportunities: localSavingOpportunities(snapshot: snapshot, projectedRemaining: projectedRemaining),
            spendLessOn: localSpendLessOn(snapshot: snapshot)
        )
    }

    private func localPatterns(snapshot: InsightSnapshot) -> [String] {
        guard snapshot.currentSpent > 0 else { return ["No spending pattern yet for this month."] }
        var patterns: [String] = []
        if snapshot.lastMonthSpent > 0 {
            let delta = snapshot.projectedSpend - snapshot.lastMonthSpent
            let direction = delta >= 0 ? "higher" : "lower"
            patterns.append("At this pace, you will finish $\(Int(abs(delta))) \(direction) than last month.")
        }
        if let top = snapshot.categoryTotals.first {
            let share = top.1 / max(snapshot.currentSpent, 1)
            patterns.append("\(top.0.displayName) makes up \(Int(share * 100))% of this month's spending.")
        }
        return patterns
    }

    private func localSavingOpportunities(snapshot: InsightSnapshot, projectedRemaining: Double) -> [String] {
        guard snapshot.currentSpent > 0 else { return [] }
        var opportunities: [String] = []
        if projectedRemaining < 0 {
            opportunities.append("You need to reduce the month-end pace by about $\(Int(abs(projectedRemaining))) to land on budget.")
        }
        for (category, total) in snapshot.categoryTotals.prefix(3) where total >= 25 {
            opportunities.append("Cut \(category.displayName) by 15% for the rest of the month to save roughly $\(Int(total * 0.15)).")
        }
        return opportunities
    }

    private func localSpendLessOn(snapshot: InsightSnapshot) -> [String] {
        snapshot.categoryTotals
            .prefix(3)
            .map { "\($0.0.displayName) — $\(Int($0.1)) spent this month" }
    }

    private func cleanList(_ items: [String], fallback: [String]) -> [String] {
        let cleaned = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? fallback : Array(cleaned.prefix(4))
    }

    private func normalizeCategory(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    private func localCategory(for title: String) -> ExpenseCategory {
        let text = title.lowercased()
        let rules: [(ExpenseCategory, [String])] = [
            (.food, ["restaurant", "coffee", "starbucks", "dunkin", "mcdonald", "chipotle", "taco", "pizza", "burger", "doordash", "uber eats", "grocery", "walmart food", "costco", "trader joe", "whole foods"]),
            (.transport, ["uber", "lyft", "gas", "fuel", "shell", "chevron", "exxon", "parking", "metro", "bus", "train", "airline", "flight", "taxi"]),
            (.shopping, ["amazon", "target", "walmart", "nike", "adidas", "store", "clothes", "mall", "best buy", "apple store"]),
            (.entertainment, ["netflix", "spotify", "hulu", "disney", "movie", "cinema", "concert", "game", "xbox", "playstation", "steam"]),
            (.health, ["pharmacy", "cvs", "walgreens", "doctor", "dentist", "hospital", "clinic", "medical", "health"]),
            (.utilities, ["electric", "water", "internet", "wifi", "phone", "verizon", "at&t", "t-mobile", "utility", "gas bill"]),
            (.rent, ["rent", "apartment", "mortgage", "lease"]),
            (.savings, ["savings", "investment", "brokerage", "roth", "ira", "deposit"])
        ]

        for (category, keywords) in rules where keywords.contains(where: { text.contains($0) }) {
            return category
        }
        return .other
    }
}
