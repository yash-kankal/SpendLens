import SwiftUI
import UIKit

enum AppThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    static let appBackground = Color.dynamic(light: "#F6F8FC", dark: "#0A0A0F")
    static let appSurface = Color.dynamic(light: "#FFFFFF", dark: "#12121A")
    static let appSurface2 = Color.dynamic(light: "#EAF0FA", dark: "#1A1A26")
    static let electricBlue = Color(hex: "#4F8EF7")
    static let appText = Color.dynamic(light: "#101827", dark: "#FFFFFF")
    static let appSubtext = Color.dynamic(light: "#64748B", dark: "#94A3B8")
    static let appHairline = Color.dynamic(light: "#D7DFEC", dark: "#FFFFFF").opacity(0.14)
    static let appMutedFill = Color.dynamic(light: "#DDE6F4", dark: "#FFFFFF").opacity(0.18)
    static let appPressedFill = Color.dynamic(light: "#CBD7EA", dark: "#FFFFFF").opacity(0.24)
    static let appOnAccent = Color.white
}

extension ShapeStyle where Self == Color {
    static var appBackground: Color { .appBackground }
    static var appSurface: Color { .appSurface }
    static var appSurface2: Color { .appSurface2 }
    static var electricBlue: Color { .electricBlue }
    static var appText: Color { .appText }
    static var appSubtext: Color { .appSubtext }
    static var appHairline: Color { .appHairline }
    static var appMutedFill: Color { .appMutedFill }
    static var appPressedFill: Color { .appPressedFill }
    static var appOnAccent: Color { .appOnAccent }
}

extension Color {

    static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.hasPrefix("#") ? String(cleaned.dropFirst()) : cleaned

        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Progress color helper
extension Double {
    /// Returns a traffic-light Color based on a 0–1 progress value.
    /// - Parameter good: colour used when progress < 0.7. Defaults to green (#34D399).
    func progressColor(good: Color = Color(hex: "#34D399")) -> Color {
        if self < 0.7 { return good }
        if self < 0.9 { return Color(hex: "#FB923C") }
        return Color(hex: "#FF6B6B")
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.hasPrefix("#") ? String(cleaned.dropFirst()) : cleaned

        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
