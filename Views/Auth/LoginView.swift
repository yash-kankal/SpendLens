import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var email = ""
    @State private var password = ""
    @State private var showSignup = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // Logo / title
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image("SpendLensLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 58, height: 58)

                            Text("SpendLens")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.appText)
                        }

                        Text("Track smarter, spend better.")
                            .font(.subheadline)
                            .foregroundStyle(.appSubtext)
                    }

                    Spacer().frame(height: 48)

                    // Form
                    VStack(spacing: 16) {
                        inputField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: Binding(
                                get: { email },
                                set: { email = $0 }
                            ),
                            isSecure: false,
                            field: .email
                        )

                        inputField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: Binding(
                                get: { password },
                                set: { password = $0 }
                            ),
                            isSecure: true,
                            field: .password
                        )

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

                        // Sign In button
                        Button {
                            focusedField = nil
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task { await authVM.login(email: email, password: password) }
                        } label: {
                            HStack(spacing: 8) {
                                if authVM.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                } else {
                                    Text("Sign In")
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
                    .padding(.horizontal)

                    Spacer().frame(height: 32)

                    // Divider
                    HStack {
                        Rectangle().fill(Color.appSubtext.opacity(0.08)).frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.appSubtext)
                            .padding(.horizontal, 12)
                        Rectangle().fill(Color.appSubtext.opacity(0.08)).frame(height: 1)
                    }
                    .padding(.horizontal)

                    Spacer().frame(height: 24)

                    // Sign up link
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showSignup = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(.appSubtext)
                            Text("Create one")
                                .foregroundStyle(Color.electricBlue)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
        .sheet(isPresented: $showSignup) {
            SignupView()
                .environment(authVM)
        }
        .onTapGesture { focusedField = nil }
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6
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
