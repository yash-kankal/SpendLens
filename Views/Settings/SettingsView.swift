import SwiftUI

struct SettingsView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(AuthViewModel.self) private var authVM
    @AppStorage("appTheme") private var appThemeRaw = AppThemePreference.system.rawValue

    @State private var showClearConfirm = false
    @State private var showSignOutConfirm = false
    @State private var clearError: String? = nil
    @State private var exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("SpendLens_Export.csv")

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                List {
                    Section {
                        themeRow
                    } header: { sectionHeader("Appearance") }
                    .listRowBackground(Color.appSurface.opacity(0.82))
                    .listRowSeparatorTint(Color.appSubtext.opacity(0.12))

                    Section {
                        aiInsightsRow
                    } header: { sectionHeader("AI") }
                    .listRowBackground(Color.appSurface.opacity(0.82))
                    .listRowSeparatorTint(Color.appSubtext.opacity(0.12))

                    Section {
                        exportRow
                        clearDataRow
                        if let clearError {
                            Text(clearError)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#FF6B6B"))
                        }
                    } header: { sectionHeader("Data") }
                    .listRowBackground(Color.appSurface.opacity(0.82))
                    .listRowSeparatorTint(Color.appSubtext.opacity(0.12))

                    Section {
                        accountRow
                        signOutRow
                    } header: { sectionHeader("Account") }
                    .listRowBackground(Color.appSurface.opacity(0.82))
                    .listRowSeparatorTint(Color.appSubtext.opacity(0.12))

                    Section {
                        HStack {
                            Image("SpendLensLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                            Text("SpendLens").foregroundStyle(.appText)
                            Spacer()
                            Text("v2.0").foregroundStyle(.appSubtext).font(.caption)
                        }
                    } header: { sectionHeader("About") }
                    .listRowBackground(Color.appSurface.opacity(0.82))
                    .listRowSeparatorTint(Color.appSubtext.opacity(0.12))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .onAppear {
            refreshExportFile()
        }
        .confirmationDialog("Clear all data? This cannot be undone.", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All Data", role: .destructive) { clearAllData() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Sign out of your account?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authVM.logout()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var themeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(Color.electricBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("Theme")
                    .foregroundStyle(.appText)
                Text("Choose light, dark, or follow your iPhone")
                    .font(.caption2)
                    .foregroundStyle(.appSubtext)
            }
            Spacer()
            Picker("Theme", selection: $appThemeRaw) {
                ForEach(AppThemePreference.allCases) { theme in
                    Text(theme.title).tag(theme.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.electricBlue)
        }
    }

    private var aiInsightsRow: some View {
        HStack {
            Image(systemName: "sparkles").foregroundStyle(Color.electricBlue).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("AI Insights").foregroundStyle(.appText)
                Text("Uses SpendLens' secure AI service when enabled")
                    .font(.caption2)
                    .foregroundStyle(.appSubtext)
            }
            Spacer()
            Text("Enabled")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.electricBlue)
        }
    }

    private var exportRow: some View {
        ShareLink(item: exportURL, preview: SharePreview("SpendLens Export", icon: Image("SpendLensLogo"))) {
            HStack {
                Image(systemName: "square.and.arrow.up").foregroundStyle(Color.electricBlue).frame(width: 28)
                Text("Export as CSV").foregroundStyle(.appText)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.appSubtext)
            }
        }
    }

    private var clearDataRow: some View {
        Button { showClearConfirm = true } label: {
            HStack {
                Image(systemName: "trash.fill").foregroundStyle(Color(hex: "#FF6B6B")).frame(width: 28)
                Text("Clear All Data").foregroundStyle(Color(hex: "#FF6B6B"))
                Spacer()
            }
        }
    }

    // MARK: - Account Rows
    private var accountRow: some View {
        HStack {
            Image(systemName: "person.circle.fill").foregroundStyle(Color.electricBlue).frame(width: 28)
            Text("Account").foregroundStyle(.appText)
            Spacer()
            Text(authVM.currentUser?.email ?? "—")
                .font(.caption)
                .foregroundStyle(.appSubtext)
                .lineLimit(1)
        }
    }

    private var signOutRow: some View {
        Button { showSignOutConfirm = true } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(Color(hex: "#FF6B6B"))
                    .frame(width: 28)
                Text("Sign Out").foregroundStyle(Color(hex: "#FF6B6B"))
                Spacer()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption).fontWeight(.semibold).foregroundStyle(.appSubtext)
            .textCase(.uppercase).tracking(0.8)
    }

    // MARK: - Actions
    private static let csvDateFormatter = ISO8601DateFormatter()

    private func generateCSV() -> String {
        var csv = "Date,Title,Category,Amount,Recurring,Note,AI Tag\n"
        let formatter = Self.csvDateFormatter
        for expense in dataStore.expenses {
            let row = [
                formatter.string(from: expense.date),
                escapeCSV(expense.title),
                expense.category.rawValue,
                String(format: "%.2f", expense.amount),
                expense.isRecurring ? "Yes" : "No",
                escapeCSV(expense.note ?? ""),
                escapeCSV(expense.aiTag ?? "")
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    private func refreshExportFile() {
        let csvData = generateCSV().data(using: .utf8) ?? Data()
        try? csvData.write(to: exportURL, options: .atomic)
    }

    private func escapeCSV(_ value: String) -> String {
        var sanitized = value.replacingOccurrences(of: "\"", with: "\"\"")
        if let first = sanitized.first, Set<Character>(["=", "+", "-", "@"]).contains(first) {
            sanitized = "'\(sanitized)"
        }
        return "\"\(sanitized)\""
    }

    private func clearAllData() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Task {
            do {
                try await dataStore.clearAllData()
                clearError = nil
            } catch {
                clearError = "Could not clear data. Check your connection and try again."
            }
        }
    }
}
