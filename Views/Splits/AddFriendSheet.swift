import SwiftUI

struct AddFriendSheet: View {
    @Environment(SplitsViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var addError: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Search field
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.appSubtext)
                        TextField("Friend's email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .foregroundStyle(.appText)
                            .focused($focused)
                        if !email.isEmpty {
                            Button { email = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.appSubtext)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.appSubtext.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await vm.searchUser(email: email) }
                    } label: {
                        Group {
                            if vm.isSearching {
                                ProgressView().tint(.white)
                            } else {
                                Text("Search")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(email.isEmpty ? Color.appSubtext.opacity(0.08) : Color.electricBlue)
                        .foregroundStyle(email.isEmpty ? .appSubtext : .appOnAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(email.isEmpty || vm.isSearching)

                    // Error
                    if let err = vm.searchError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(Color(hex: "#FF6B6B"))
                            Text(err).font(.subheadline).foregroundStyle(Color(hex: "#FF6B6B"))
                        }
                        .padding(14)
                        .background(Color(hex: "#FF6B6B").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let addError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(Color(hex: "#FF6B6B"))
                            Text(addError).font(.subheadline).foregroundStyle(Color(hex: "#FF6B6B"))
                        }
                        .padding(14)
                        .background(Color(hex: "#FF6B6B").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Result
                    if let result = vm.searchResult {
                        HStack(spacing: 14) {
                            FriendAvatar(initials: result.initials, id: result.id, size: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.displayName)
                                    .font(.headline).foregroundStyle(.appText)
                                Text(result.email)
                                    .font(.caption).foregroundStyle(.appSubtext)
                            }

                            Spacer()

                            if vm.isFriend(result.id) {
                                Label("Added", systemImage: "checkmark.circle.fill")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(splitGreen)
                            } else {
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    Task {
                                        do {
                                            try await vm.addFriend(result)
                                            dismiss()
                                        } catch {
                                            addError = error.localizedDescription
                                        }
                                    }
                                } label: {
                                    Text("Add")
                                        .font(.subheadline).fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 18).padding(.vertical, 9)
                                        .background(splitGreen)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.appSubtext.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.appSubtext.opacity(0.08), lineWidth: 1)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.appSubtext)
                }
            }
            .onAppear {
                vm.searchResult = nil
                vm.searchError = nil
                addError = nil
                focused = true
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.appBackground)
    }
}

