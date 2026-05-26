import Foundation
import SwiftUI
import UIKit

extension Date {
    private static let relativeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f
    }()
    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var relativeLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self)     { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        return Self.relativeFormatter.string(from: self)
    }

    var shortFormatted: String { Self.shortFormatter.string(from: self) }

    var timeFormatted: String { Self.timeFormatter.string(from: self) }

    var monthYear: String { Self.monthYearFormatter.string(from: self) }

    static func startOfCurrentMonth() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: components) ?? now
    }
}

// MARK: - Currency formatting

extension Double {
    /// Formats as a dollar amount with two decimal places, e.g. "$1,234.56".
    var asCurrency: String { String(format: "$%.2f", self) }
}

// MARK: - Keyboard helpers

private func resignFirstResponder() {
    MainActor.assumeIsolated {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

extension View {
    /// Dismiss the keyboard when the user taps on a non-interactive area.
    /// Safe to use on containers — child Button gestures still fire normally.
    func dismissKeyboardOnTap() -> some View {
        onTapGesture { resignFirstResponder() }
    }

    /// Adds a "Done" button above the keyboard toolbar.
    /// Essential for decimal / number pads that have no Return key.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { resignFirstResponder() }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.electricBlue)
            }
        }
    }
}
