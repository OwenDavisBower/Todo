import SwiftUI
import UIKit

enum AppTheme {
    static let ink = Color.adaptive(light: "3c3429", dark: "e8e2d8")
    static let sage = Color.adaptive(light: "7d8b6f", dark: "94a386")
    static let mist = Color.adaptive(light: "c9bfb2", dark: "6e665c")
    static let lilac = Color.adaptive(light: "b8c9ab", dark: "3a4534")
    static let blush = Color(hex: "ede6da")

    static let background = Color.adaptive(light: "f7f3ed", dark: "1a1814")
    static let surface = Color.adaptive(light: "ede6da", dark: "252219")
    static let card = Color.adaptive(light: "ffffff", dark: "2c2822")
    static let fillDark = Color(hex: "3c3429")
    static let divider = mist.opacity(0.45)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }

    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.background)
            .tint(AppTheme.ink)
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }

    func themedNavigationBar() -> some View {
        toolbarBackground(AppTheme.background, for: .navigationBar)
    }

    func themedForm() -> some View {
        scrollContentBackground(.hidden)
            .themedBackground()
    }
}
