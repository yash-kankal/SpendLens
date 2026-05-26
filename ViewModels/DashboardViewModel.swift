import SwiftUI

@MainActor
@Observable
class DashboardViewModel {
    var selectedCategory: ExpenseCategory? = nil
    var showAddExpense = false
    var isLoading = false

    var currentMonthName: String { Date().monthYear }

    var daysLeftInMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return 0 }
        return range.count - calendar.component(.day, from: now)
    }

    func totalSpent(from expenses: [Expense]) -> Double {
        currentMonthExpenses(from: expenses).reduce(0) { $0 + $1.amount }
    }

    func filteredExpenses(from expenses: [Expense]) -> [Expense] {
        let monthly = currentMonthExpenses(from: expenses)
        if let cat = selectedCategory {
            return monthly.filter { $0.category == cat }
        }
        return monthly
    }

    func groupedExpenses(from expenses: [Expense]) -> [(String, [Expense])] {
        let filtered = filteredExpenses(from: expenses)
        let sorted = filtered.sorted { $0.date > $1.date }

        var groups: [(String, [Expense])] = []
        var seen: [String: Int] = [:]

        for expense in sorted {
            let label = expense.date.relativeLabel
            if let idx = seen[label] {
                groups[idx].1.append(expense)
            } else {
                seen[label] = groups.count
                groups.append((label, [expense]))
            }
        }
        return groups
    }

    func categoryBreakdown(from expenses: [Expense]) -> [(ExpenseCategory, Double)] {
        let monthly = currentMonthExpenses(from: expenses)
        var totals: [ExpenseCategory: Double] = [:]
        for expense in monthly {
            totals[expense.category, default: 0] += expense.amount
        }
        return totals.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    func spendProgress(from expenses: [Expense], budget: Budget?) -> Double {
        guard let budget = budget, budget.totalBudget > 0 else { return 0 }
        return min(totalSpent(from: expenses) / budget.totalBudget, 1.0)
    }

    func currentMonthExpenses(from expenses: [Expense]) -> [Expense] {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year  = calendar.component(.year,  from: now)
        return expenses.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year,  from: $0.date) == year
        }
    }

    func toggleCategoryFilter(_ category: ExpenseCategory) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedCategory = selectedCategory == category ? nil : category
    }
}
