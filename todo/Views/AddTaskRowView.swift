import SwiftUI

struct AddTaskRowView: View {
    var autofocus: Bool
    let onSubmit: (String, Date?) -> Void
    var onDismissWhenEmpty: (() -> Void)? = nil

    @State private var title = ""
    @State private var dueDate: Date?
    @State private var isShowingDatePicker = false
    @State private var isVisible = false
    @FocusState private var isFocused: Bool

    private let presentationAnimation = Animation.spring(response: 0.38, dampingFraction: 0.82)

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

            calendarButton
            addButton
        }
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(AppTheme.card)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 14)
        .scaleEffect(isVisible ? 1 : 0.97, anchor: .bottom)
        .onAppear {
            withAnimation(presentationAnimation) {
                isVisible = true
            }
            if autofocus {
                isFocused = true
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, trimmedTitle.isEmpty {
                dismissWhenEmpty()
            }
        }
    }

    private var calendarButton: some View {
        Button {
            isShowingDatePicker = true
        } label: {
            if let dueDate {
                dueDateBadge(for: dueDate)
            } else {
                Image(systemName: "calendar")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.mist)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dueDate == nil ? "Add due date" : "Change due date")
        .popover(isPresented: $isShowingDatePicker) {
            datePickerPopover
        }
    }

    private var datePickerPopover: some View {
        CustomDatePickerView(
            selectedDate: $dueDate,
            onRemove: { dueDate = nil },
            onDismiss: { isShowingDatePicker = false }
        )
        .fixedSize()
        .presentationCompactAdaptation(.popover)
    }

    @ViewBuilder
    private func dueDateBadge(for dueDate: Date) -> some View {
        let label = DueDateFormatting.label(for: dueDate)
        Text(label.text)
            .font(.caption.weight(label.isOverdue ? .semibold : .medium))
            .foregroundStyle(label.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(label.background))
    }

    private var addButton: some View {
        Button(action: submit) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(AppTheme.blush, AppTheme.sage)
        }
        .buttonStyle(.plain)
        .disabled(trimmedTitle.isEmpty)
        .opacity(trimmedTitle.isEmpty ? 0.35 : 1)
        .accessibilityLabel("Add task")
    }

    private func submit() {
        guard !trimmedTitle.isEmpty else { return }

        onSubmit(trimmedTitle, dueDate)
        title = ""
        dueDate = nil
        isFocused = true
    }

    private func dismissWhenEmpty() {
        onDismissWhenEmpty?()
    }
}

#Preview {
    AddTaskRowView(autofocus: true) { _, _ in }
        .padding(20)
        .themedBackground()
}
