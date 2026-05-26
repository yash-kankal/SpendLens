import SwiftUI

struct AIChatSheet: View {
    @Bindable var viewModel: InsightsViewModel
    let expenses: [Expense]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                // Welcome message
                                chatBubble(
                                    role: "assistant",
                                    content: "Hi! I'm your AI finance assistant. Ask me anything about your spending — like \"How much did I spend on food last week?\" or \"What's my biggest expense category?\""
                                )

                                ForEach(viewModel.chatMessages) { msg in
                                    chatBubble(role: msg.role, content: msg.content)
                                        .id(msg.id)
                                }

                                if viewModel.isChatLoading {
                                    typingIndicator
                                }

                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 20)
                        }
                        .onChange(of: viewModel.chatMessages.count) { _, _ in
                            withAnimation { proxy.scrollTo("bottom") }
                        }
                        .onChange(of: viewModel.isChatLoading) { _, loading in
                            if loading { withAnimation { proxy.scrollTo("bottom") } }
                        }
                    }

                    // Input bar
                    inputBar
                }
            }
            .navigationTitle("AI Finance Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    @ViewBuilder
    private func chatBubble(role: String, content: String) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if role == "user" { Spacer(minLength: 50) }

            if role == "assistant" {
                Circle()
                    .fill(Color.electricBlue.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.electricBlue)
                    }
            }

            Text(content)
                .font(.subheadline)
                .foregroundStyle(role == "user" ? .white : Color.appSubtext.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(role == "user"
                              ? Color.electricBlue
                              : Color.appSubtext.opacity(0.08))
                        .overlay {
                            if role == "assistant" {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.appSubtext.opacity(0.08), lineWidth: 1)
                            }
                        }
                }
                .fixedSize(horizontal: false, vertical: true)

            if role == "assistant" { Spacer(minLength: 50) }
        }
    }

    private var typingIndicator: some View {
        TypingIndicatorView()
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about your spending...", text: $viewModel.chatInput)
                .font(.subheadline)
                .foregroundStyle(.appText)
                .tint(.electricBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(Color.appSubtext.opacity(0.06))
                        .overlay { Capsule().stroke(Color.appSubtext.opacity(0.1), lineWidth: 1) }
                }
                .onSubmit { sendMessage() }

            Button { sendMessage() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(viewModel.chatInput.isEmpty ? Color.appSubtext : Color.electricBlue)
                    .shadow(color: viewModel.chatInput.isEmpty ? .clear : .electricBlue.opacity(0.4), radius: 8)
            }
            .disabled(viewModel.chatInput.isEmpty || viewModel.isChatLoading)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.chatInput.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appSubtext.opacity(0.06))
                .frame(height: 1)
        }
    }

    private func sendMessage() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { await viewModel.sendChatMessage(expenses: expenses) }
    }
}

// MARK: - Typing indicator (needs its own @State for animation)

private struct TypingIndicatorView: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.electricBlue.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.electricBlue)
                }

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.appSubtext.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .scaleEffect(phase ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.18),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appSubtext.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()
        }
        .onAppear { phase = true }
    }
}
