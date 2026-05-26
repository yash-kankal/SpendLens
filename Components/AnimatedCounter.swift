import SwiftUI

struct AnimatedCounter: View, Animatable {
    var value: Double
    var prefix: String
    var suffix: String
    var decimals: Int
    var font: Font
    var color: Color

    init(
        value: Double,
        prefix: String = "$",
        suffix: String = "",
        decimals: Int = 0,
        font: Font = .system(.title, design: .rounded, weight: .bold),
        color: Color = .white
    ) {
        self.value = value
        self.prefix = prefix
        self.suffix = suffix
        self.decimals = decimals
        self.font = font
        self.color = color
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(formattedValue)
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: value))
    }

    private var formattedValue: String {
        if decimals == 0 {
            return "\(prefix)\(Int(value))\(suffix)"
        } else {
            return String(format: "\(prefix)%.2f\(suffix)", value)
        }
    }
}

// MARK: - Counting Number Modifier
struct CountingNumberModifier: AnimatableModifier {
    var number: Double
    var prefix: String
    var decimals: Int

    var animatableData: Double {
        get { number }
        set { number = newValue }
    }

    func body(content: Content) -> some View {
        if decimals == 0 {
            Text("\(prefix)\(Int(number))")
        } else {
            Text(String(format: "\(prefix)%.2f", number))
        }
    }
}
