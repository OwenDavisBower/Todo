import SwiftUI

struct AddTaskBottomSheet: View {
    @Binding var isExpanded: Bool

    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.startOfDay(for: Date())
    @State private var textFieldCardHeight: CGFloat = 0
    @FocusState private var isTitleFocused: Bool

    let onAdd: (String, Date?) -> Void

    private let cardCornerRadius: CGFloat = 18

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 12) {
            if isTitleFocused {
                expandedOptions
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            inputRow
        }
        .padding(.horizontal, 20)
        .padding(.top, isTitleFocused ? 20 : 12)
        .padding(.bottom, 12)
        .background(alignment: .top) {
            if isTitleFocused {
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
                .fill(AppTheme.background)
                .shadow(color: AppTheme.ink.opacity(0.1), radius: 24, y: -8)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isTitleFocused)
        .onChange(of: isTitleFocused) { _, focused in
            isExpanded = focused
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                isTitleFocused = false
            }
        }
    }

    private var addButtonSize: CGFloat {
        textFieldCardHeight > 0 ? textFieldCardHeight : 64
    }

    private var inputRow: some View {
        HStack(spacing: 12) {
            TextField(
                "",
                text: $title,
                prompt: Text("Add task…").foregroundStyle(AppTheme.ink.opacity(0.5))
            )
            .font(.body.weight(.medium))
            .foregroundStyle(AppTheme.ink)
            .focused($isTitleFocused)
            .submitLabel(.done)
            .onSubmit(submit)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(.white)
                    .shadow(color: AppTheme.ink.opacity(0.07), radius: 10, y: 3)
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: TextFieldCardHeightKey.self,
                        value: geometry.size.height
                    )
                }
            }
            .frame(maxWidth: .infinity)

            if isTitleFocused {
                Button(action: submit) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.blush)
                        .opacity(trimmedTitle.isEmpty ? 0.45 : 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                                .fill(AppTheme.sage)
                                .shadow(color: AppTheme.ink.opacity(0.07), radius: 10, y: 3)
                        }
                }
                .buttonStyle(.plain)
                .disabled(trimmedTitle.isEmpty)
                .frame(width: addButtonSize, height: addButtonSize)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onPreferenceChange(TextFieldCardHeightKey.self) { height in
            if height > 0 {
                textFieldCardHeight = height
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isTitleFocused)
    }

    private var expandedOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Due date", isOn: $hasDueDate.animation())
                .tint(AppTheme.ink)
                .foregroundStyle(AppTheme.ink)

            if hasDueDate {
                DatePicker(
                    "Due",
                    selection: $dueDate,
                    displayedComponents: .date
                )
                .tint(AppTheme.ink)
                .foregroundStyle(AppTheme.ink)
            }
        }
        .padding(.horizontal, 14)
    }

    private func submit() {
        guard !trimmedTitle.isEmpty else { return }

        onAdd(trimmedTitle, hasDueDate ? dueDate : nil)
        title = ""
        hasDueDate = false
        dueDate = Calendar.current.startOfDay(for: Date())
        isTitleFocused = false
    }
}

private struct TextFieldCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    VStack {
        Spacer()
        AddTaskBottomSheet(isExpanded: .constant(false)) { _, _ in }
    }
    .themedBackground()
}
