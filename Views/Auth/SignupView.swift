import SwiftUI

struct SignupView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, confirm }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 8)

                        // Header
                        VStack(spacing: 8) {
                            Text("Create Account")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.appText)
                            Text("Start tracking your spending from $0")
                                .font(.subheadline)
                                .foregroundStyle(.appSubtext)
                        }

                        // Form
                        VStack(spacing: 14) {
                            inputField(
                                icon: "envelope.fill",
                                placeholder: "Email",
                                text: Binding(get: { email }, set: { email = $0 }),
                                isSecure: false,
                                field: .email
                            )

                            inputField(
                                icon: "lock.fill",
                                placeholder: "Password (min. 6 characters)",
                                text: Binding(get: { password }, set: { password = $0 }),
                                isSecure: true,
                                field: .password
                            )

                            inputField(
                                icon: "lock.fill",
                                placeholder: "Confirm Password",
                                text: Binding(get: { confirmPassword }, set: { confirmPassword = $0 }),
                                isSecure: true,
                                field: .confirm
                            )

                            // Password match indicator
                            if !confirmPassword.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(passwordsMatch ? Color(hex: "#34D399") : Color(hex: "#FF6B6B"))
                                    Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                                        .font(.caption)
                                        .foregroundStyle(passwordsMatch ? Color(hex: "#34D399") : Color(hex: "#FF6B6B"))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            }

                            if let error = authVM.errorMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "#FF6B6B"))
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "#FF6B6B"))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            }

                            if let success = authVM.successMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "#34D399"))
                                    Text(success)
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "#34D399"))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            }

                            // Create Account button
                            Button {
                                focusedField = nil
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Task {
                                    await authVM.signup(email: email, password: password)
                                    if authVM.isLoggedIn { dismiss() }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if authVM.isLoading {
                                        ProgressView().tint(.white).scaleEffect(0.85)
                                    } else {
                                        Text("Create Account")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                    }
                                }
                                .foregroundStyle(isFormValid ? .appOnAccent : .appSubtext)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(isFormValid ? Color.electricBlue : Color.appSubtext.opacity(0.08))
                                        .shadow(color: isFormValid ? .electricBlue.opacity(0.4) : .clear, radius: 12)
                                }
                            }
                            .disabled(!isFormValid || authVM.isLoading)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFormValid)
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .foregroundStyle(.appSubtext)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .onTapGesture { focusedField = nil }
    }

    private var passwordsMatch: Bool { password == confirmPassword }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        passwordsMatch
    }

    @ViewBuilder
    private func inputField(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool, field: Field) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.appSubtext)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: text)
                    .font(.body)
                    .foregroundStyle(.appText)
                    .tint(Color.electricBlue)
                    .focused($focusedField, equals: field)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                TextField(placeholder, text: text)
                    .font(.body)
                    .foregroundStyle(.appText)
                    .tint(Color.electricBlue)
                    .focused($focusedField, equals: field)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSubtext.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            focusedField == field ? Color.electricBlue.opacity(0.5) : Color.appSubtext.opacity(0.08),
                            lineWidth: 1
                        )
                }
        }
        .animation(.easeInOut(duration: 0.2), value: focusedField == field)
    }
}
