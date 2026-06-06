import SwiftUI

enum AppTheme {
    static let ink = Color(hex: "3c3429")
    static let sage = Color(hex: "7d8b6f")
    static let mist = Color(hex: "c9bfb2")
    static let lilac = Color(hex: "c4a07a")
    static let blush = Color(hex: "ede6da")

    static let background = Color(hex: "f7f3ed")
    static let surface = blush
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
}
