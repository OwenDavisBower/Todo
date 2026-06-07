import SwiftUI

struct UndoToastView: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.blush)

            Spacer(minLength: 8)

            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.blush)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.fillDark)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). Undo available.")
        .accessibilityAction(named: "Undo", onUndo)
    }
}

#Preview {
    UndoToastView(message: "Task completed") {}
        .padding(20)
        .themedBackground()
}
