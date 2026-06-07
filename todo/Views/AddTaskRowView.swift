import SwiftUI

struct AddTaskRowView: View {
    var autofocus: Bool
    let onSubmit: (String) -> Void
    var onDismissWhenEmpty: (() -> Void)? = nil

    @State private var title = ""
    @FocusState private var isFocused: Bool

    private let cardCornerRadius: CGFloat = 18

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 14) {
            TextField(
                "",
                text: $title,
                prompt: Text("Add task…").foregroundStyle(AppTheme.ink.opacity(0.5))
            )
            .font(.body.weight(.medium))
            .foregroundStyle(AppTheme.ink)
            .focused($isFocused)
            .submitLabel(.done)
            .onSubmit(submit)
            .frame(maxWidth: .infinity, alignment: .leading)

            addButton
        }
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.white)
                .shadow(color: AppTheme.ink.opacity(0.07), radius: 10, y: 3)
        }
        .onAppear {
            if autofocus {
                isFocused = true
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, trimmedTitle.isEmpty {
                onDismissWhenEmpty?()
            }
        }
    }

    private var addButton: some View {
        Button(action: submit) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(AppTheme.blush, AppTheme.sage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task")
    }

    private func submit() {
        guard !trimmedTitle.isEmpty else { return }

        onSubmit(trimmedTitle)
        title = ""
        isFocused = true
    }
}

#Preview {
    AddTaskRowView(autofocus: true) { _ in }
        .padding(20)
        .themedBackground()
}
