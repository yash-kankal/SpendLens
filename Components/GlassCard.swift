import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 20
    var material: Material = .ultraThinMaterial

    init(
        padding: CGFloat = 20,
        cornerRadius: CGFloat = 20,
        material: Material = .ultraThinMaterial,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.material = material
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.appSurface.opacity(0.86))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.appSubtext.opacity(0.18),
                                        Color.appSubtext.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.06), radius: 12, y: 6)
            }
    }
}

// MARK: - Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        Color.appSubtext.opacity(0),
                        Color.appSubtext.opacity(0.08),
                        Color.appSubtext.opacity(0)
                    ],
                    startPoint: UnitPoint(x: phase - 0.5, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.5, y: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func glowEffect(color: Color = .electricBlue, radius: CGFloat = 12) -> some View {
        self.shadow(color: color.opacity(0.3), radius: radius)
    }
}
