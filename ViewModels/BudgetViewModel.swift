import SwiftUI

@MainActor
@Observable
class BudgetViewModel {
    var editingCategory: ExpenseCategory? = nil
    var tempBudgetInput = ""

    func categorySpent(_ category: ExpenseCategory, from expenses: [Expense]) -> Double {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year  = calendar.component(.year,  from: now)
        return expenses
            .filter {
                $0.category == category &&
                calendar.component(.month, from: $0.date) == month &&
                calendar.component(.year,  from: $0.date) == year
            }
            .reduce(0) { $0 + $1.amount }
    }

    func categoryProgress(_ category: ExpenseCategory, budget: Budget, from expenses: [Expense]) -> Double {
        let limit = budget.categoryLimits[category.rawValue] ?? 0
        guard limit > 0 else { return 0 }
        return min(categorySpent(category, from: expenses) / limit, 1.0)
    }

    func progressColor(for progress: Double) -> Color {
        progress.progressColor()
    }

    func commitCategoryLimit(_ category: ExpenseCategory, dataStore: DataStore) {
        guard let value = Double(tempBudgetInput), value > 0 else { return }
        dataStore.updateCategoryLimit(category, value: value)
        editingCategory = nil
        tempBudgetInput = ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
