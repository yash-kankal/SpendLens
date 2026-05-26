import SwiftUI

@main
struct SpendLensApp: App {
    @AppStorage("appTheme") private var appThemeRaw = AppThemePreference.system.rawValue
    @State private var authVM = AuthViewModel()
    @State private var dataStore = DataStore()
    @State private var splitsVM = SplitsViewModel()
    @State private var showLaunchSplash = true

    init() {
        // Make every scroll view in the app dismiss the keyboard interactively
        // (follows the user's finger down, same feel as Messages / Mail).
        UIScrollView.appearance().keyboardDismissMode = .interactive
    }

    private var appTheme: AppThemePreference {
        AppThemePreference(rawValue: appThemeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authVM.isLoggedIn, let user = authVM.currentUser {
                        signedInContent(user: user)
                    } else {
                        LoginView()
                            .environment(authVM)
                            .onAppear {
                                dataStore.stopListening()
                                splitsVM.stopListening()
                            }
                    }
                }
                .opacity(showLaunchSplash ? 0 : 1)

                if showLaunchSplash {
                    LogoLaunchSplashView {
                        showLaunchSplash = false
                    }
                }
            }
            .preferredColorScheme(appTheme.colorScheme)
            .animation(.easeInOut(duration: 0.3), value: authVM.isLoggedIn)
            .task { authVM.setup() }
        }
    }

    @ViewBuilder
    private func signedInContent(user: AppUser) -> some View {
        Group {
            if dataStore.isLoadingInitialData || !dataStore.hasLoadedInitialData {
                LaunchLoadingView()
            } else if dataStore.budget == nil {
                BudgetOnboardingView()
            } else {
                ContentView()
            }
        }
        .environment(authVM)
        .environment(dataStore)
        .environment(splitsVM)
        .onAppear {
            dataStore.startListening(userId: user.uid)
            splitsVM.startListening(user: user)
        }
        .onChange(of: user.uid) { _, _ in
            dataStore.startListening(userId: user.uid)
            splitsVM.startListening(user: user)
        }
    }
}

private struct LogoLaunchSplashView: View {
    let onFinished: () -> Void

    @State private var logoScale = 0.82
    @State private var logoOpacity = 1.0
    @State private var backgroundOpacity = 1.0

    var body: some View {
        ZStack {
            Color.appBackground
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            Image("SpendLensLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 164, height: 164)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                logoScale = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                withAnimation(.easeInOut(duration: 0.42)) {
                    logoScale = 18
                    logoOpacity = 0
                    backgroundOpacity = 0
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.02) {
                onFinished()
            }
        }
    }
}

private struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.electricBlue.opacity(0.14))
                        .frame(width: 76, height: 76)
                    ProgressView()
                        .tint(Color.electricBlue)
                        .scaleEffect(1.2)
                }
                HStack(spacing: 8) {
                    Image("SpendLensLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("Loading SpendLens")
                }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.appSubtext)
            }
        }
    }
}

private struct BudgetOnboardingView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(DataStore.self) private var dataStore

    @State private var monthlyBudget: Double = 3000
    @State private var selectedPreset: Double? = 3000
    @State private var appear = false
    @State private var isSaving = false
    @State private var saveError: String?

    private let presets: [Double] = [1500, 3000, 5000]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    budgetDial
                    presetSelector
                    categoryPreview
                    continueButton

                    if let saveError {
                        Text(saveError)
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#FF6B6B"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 44)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                appear = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.electricBlue.opacity(0.14))
                    .frame(width: 96, height: 96)
                    .scaleEffect(appear ? 1 : 0.82)
                Circle()
                    .stroke(Color.electricBlue.opacity(0.28), lineWidth: 1)
                    .frame(width: 96, height: 96)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.electricBlue)
            }

            VStack(spacing: 8) {
                Text("Set your monthly budget")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.appText)
                    .multilineTextAlignment(.center)
                Text("Start with a target. You can tune categories anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.appSubtext)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 18)
    }

    private var budgetDial: some View {
        GlassCard {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("Monthly limit")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.appSubtext)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text("$\(Int(monthlyBudget))")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.appText)
                        .contentTransition(.numericText(value: monthlyBudget))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: monthlyBudget)
                }

                Slider(value: $monthlyBudget, in: 500...10000, step: 50) {
                    Text("Budget")
                }
                .tint(Color.electricBlue)
                .onChange(of: monthlyBudget) { _, value in
                    selectedPreset = presets.first(where: { abs($0 - value) < 1 })
                }

                HStack {
                    Text("$500")
                    Spacer()
                    Text("$10,000")
                }
                .font(.caption2)
                .foregroundStyle(.appSubtext)
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.08), value: appear)
    }

    private var presetSelector: some View {
        HStack(spacing: 10) {
            ForEach(presets, id: \.self) { preset in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedPreset = preset
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        monthlyBudget = preset
                    }
                } label: {
                    Text("$\(Int(preset))")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(selectedPreset == preset ? .appOnAccent : .appSubtext)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedPreset == preset ? Color.electricBlue : Color.appSubtext.opacity(0.06))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 18)
        .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.16), value: appear)
    }

    private var categoryPreview: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Suggested split")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.appText)
                    Spacer()
                    Text("Editable later")
                        .font(.caption)
                        .foregroundStyle(.appSubtext)
                }

                ForEach(previewCategories, id: \.0) { category, amount in
                    HStack(spacing: 12) {
                        CategoryIconPill(category: category, size: 36)
                        Text(category.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.appText)
                        Spacer()
                        Text("$\(Int(amount))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.appSubtext)
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(x: appear ? 0 : -12)
                }
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 18)
        .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.24), value: appear)
    }

    private var continueButton: some View {
        Button {
            Task { await saveBudget() }
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Start tracking")
                        .fontWeight(.bold)
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
            }
            .foregroundStyle(.appOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.electricBlue)
                    .shadow(color: Color.electricBlue.opacity(0.42), radius: 16)
            }
        }
        .disabled(isSaving)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 18)
        .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.32), value: appear)
    }

    private var previewCategories: [(ExpenseCategory, Double)] {
        let limits = scaledCategoryLimits()
        return [.rent, .food, .shopping, .transport, .savings].map {
            ($0, limits[$0.rawValue] ?? 0)
        }
    }

    private func scaledCategoryLimits() -> [String: Double] {
        let defaults = Budget.defaultCategoryLimits()
        let defaultTotal = defaults.values.reduce(0, +)
        guard defaultTotal > 0 else { return defaults }
        return defaults.mapValues { value in
            (value / defaultTotal) * monthlyBudget
        }
    }

    private func saveBudget() async {
        guard let userId = authVM.currentUser?.uid else { return }
        await MainActor.run {
            isSaving = true
            saveError = nil
        }

        let calendar = Calendar.current
        let now = Date()
        let budget = Budget(
            ownerId: userId,
            month: calendar.component(.month, from: now),
            year: calendar.component(.year, from: now),
            totalBudget: monthlyBudget,
            categoryLimits: scaledCategoryLimits()
        )

        do {
            try await dataStore.saveBudget(budget)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            await MainActor.run {
                saveError = "Could not save your budget. Check your connection and try again."
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        await MainActor.run { isSaving = false }
    }
}

// MARK: - ContentView (Tab Container)
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "brain.head.profile.fill") }
                .tag(1)

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
                .tag(2)

            SplitsView()
                .tabItem { Label("Splits", systemImage: "person.2.fill") }
                .tag(3)

            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }
                .tag(4)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(5)
        }
        .tint(Color.electricBlue)
    }
}
