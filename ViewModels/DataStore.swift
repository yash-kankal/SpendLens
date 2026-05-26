import Foundation

@MainActor
@Observable
class DataStore {
    var expenses: [Expense] = []
    var budget: Budget? = nil
    var isLoadingInitialData = false
    var hasLoadedInitialData = false
    var refreshError: Error? = nil

    private let supabase = SupabaseService.shared
    private var userId: String = ""

    // MARK: - Start / Stop
    func startListening(userId: String) {
        if self.userId == userId, hasLoadedInitialData { return }
        self.userId = userId
        isLoadingInitialData = true
        hasLoadedInitialData = false
        Task { await refresh() }
    }

    func stopListening() {
        expenses = []
        budget = nil
        isLoadingInitialData = false
        hasLoadedInitialData = false
        userId = ""
        refreshError = nil
    }

    // MARK: - Refresh
    func refresh() async {
        guard !userId.isEmpty else { return }
        refreshError = nil
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year  = calendar.component(.year,  from: now)

        do {
            let loadedExpenses: [Expense] = try await supabase.select(
                table: "expenses",
                queryItems: [
                    URLQueryItem(name: "owner_id", value: "eq.\(userId)"),
                    URLQueryItem(name: "order",    value: "date.desc")
                ]
            )
            let loadedBudgets: [Budget] = try await supabase.select(
                table: "budgets",
                queryItems: [
                    URLQueryItem(name: "owner_id", value: "eq.\(userId)"),
                    URLQueryItem(name: "month",    value: "eq.\(month)"),
                    URLQueryItem(name: "year",     value: "eq.\(year)"),
                    URLQueryItem(name: "limit",    value: "1")
                ]
            )
            expenses = loadedExpenses
            budget   = loadedBudgets.first
        } catch {
            refreshError = error
        }
        isLoadingInitialData = false
        hasLoadedInitialData = true
    }

    // MARK: - Expenses
    func addExpense(_ expense: Expense) async throws {
        try await supabase.upsert(expense, table: "expenses")
        await refresh()
    }

    func deleteExpense(_ expense: Expense) async throws {
        try await supabase.delete(
            table: "expenses",
            queryItems: [
                URLQueryItem(name: "id",       value: "eq.\(expense.id)"),
                URLQueryItem(name: "owner_id", value: "eq.\(userId)")
            ]
        )
        await refresh()
    }

    func updateExpense(_ expense: Expense) async throws {
        try await supabase.upsert(expense, table: "expenses")
        await refresh()
    }

    func toggleRecurring(_ expense: Expense) {
        var updated = expense
        updated.isRecurring.toggle()
        Task { try? await updateExpense(updated) }
    }

    // MARK: - Budget
    func saveBudget(_ budget: Budget) async throws {
        try await supabase.upsert(budget, table: "budgets")
        await refresh()
    }

    func createDefaultBudget(ownerId: String) {
        let calendar = Calendar.current
        let now = Date()
        let newBudget = Budget(
            ownerId: ownerId,
            month: calendar.component(.month, from: now),
            year:  calendar.component(.year,  from: now),
            totalBudget: 3000,
            categoryLimits: Budget.defaultCategoryLimits()
        )
        Task { try? await saveBudget(newBudget) }
    }

    func updateBudgetTotal(_ newTotal: Double) {
        guard var updated = budget else { return }
        updated.totalBudget = newTotal
        Task { try? await saveBudget(updated) }
    }

    func updateCategoryLimit(_ category: ExpenseCategory, value: Double) {
        guard var updated = budget else { return }
        updated.categoryLimits[category.rawValue] = value
        Task { try? await saveBudget(updated) }
    }

    // MARK: - Clear all
    func clearAllData() async throws {
        try await supabase.delete(table: "expenses", queryItems: [URLQueryItem(name: "owner_id", value: "eq.\(userId)")])
        try await supabase.delete(table: "budgets",  queryItems: [URLQueryItem(name: "owner_id", value: "eq.\(userId)")])
        await refresh()
    }
}
