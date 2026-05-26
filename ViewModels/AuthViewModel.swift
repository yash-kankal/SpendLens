import SwiftUI

@MainActor
@Observable
class AuthViewModel {
    var currentUser: AppUser? = nil
    var isLoading = false
    var errorMessage: String? = nil
    var successMessage: String? = nil

    var isLoggedIn: Bool { currentUser != nil }

    func setup() {
        currentUser = SupabaseService.shared.currentUser
    }

    func login(email: String, password: String) async {
        isLoading = true; errorMessage = nil; successMessage = nil
        do {
            let user = try await SupabaseService.shared.login(email: email, password: password)
            try await saveProfile(for: user)
            currentUser = user
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func signup(email: String, password: String) async {
        isLoading = true; errorMessage = nil; successMessage = nil
        do {
            let user = try await SupabaseService.shared.signup(email: email, password: password)
            currentUser = user
        } catch {
            if isEmailConfirmationRequired(error) {
                successMessage = "Check your email to confirm your account, then sign in."
                errorMessage = nil
            } else {
                errorMessage = friendlyError(error)
            }
        }
        isLoading = false
    }

    func logout() {
        Task {
            do {
                try await SupabaseService.shared.logout()
                currentUser = nil
                errorMessage = nil
                successMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func isEmailConfirmationRequired(_ error: Error) -> Bool {
        if let supabaseError = error as? SupabaseServiceError,
           case .emailConfirmationRequired = supabaseError {
            return true
        }
        let message = error.localizedDescription
        return message.localizedCaseInsensitiveContains("check your email") ||
               message.localizedCaseInsensitiveContains("confirm your account")
    }

    private func saveProfile(for user: AppUser) async throws {
        let email = (user.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty else { return }
        let displayName = user.displayName?.isEmpty == false
            ? user.displayName!
            : String(email.split(separator: "@").first ?? "User")
        let profile = UserProfile(id: user.uid, displayName: displayName, email: email)
        try await SupabaseService.shared.upsert(profile, table: "profiles")
    }

    private func friendlyError(_ error: Error) -> String {
        if let supabaseError = error as? SupabaseServiceError {
            return supabaseError.localizedDescription
        }
        let nsError = error as NSError
        if nsError.code == -1009 { return "No internet connection." }

        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("invalid login") ||
           message.localizedCaseInsensitiveContains("invalid credentials") {
            return "Incorrect email or password."
        }
        if message.localizedCaseInsensitiveContains("email not confirmed") ||
           message.localizedCaseInsensitiveContains("email_not_confirmed") {
            return "Confirm your email first, then sign in."
        }
        if message.localizedCaseInsensitiveContains("already registered") ||
           message.localizedCaseInsensitiveContains("already exists") {
            return "An account with this email already exists."
        }
        if message.localizedCaseInsensitiveContains("over_email_send_rate_limit") ||
           message.localizedCaseInsensitiveContains("security purposes") {
            return "Please wait a minute before requesting another signup email."
        }
        return message
    }
}
