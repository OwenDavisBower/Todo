import SwiftUI

struct AddTaskBottomSheet: View {
    @Binding var isExpanded: Bool

    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.startOfDay(for: Date())
    @FocusState private var isTitleFocused: Bool

    let onAdd: (String, Date?) -> Void

    private let cardCornerRadius: CGFloat = 18

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

    private var inputRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "plus")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.mist)
                .frame(width: 24, height: 36)

            TextField("Add task…", text: $title)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.ink)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit(submit)
        }
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.white)
                .shadow(color: AppTheme.ink.opacity(0.07), radius: 10, y: 3)
        }
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

            HStack {
                Spacer()
                Button(action: submit) {
                    Text("Add Task")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.blush)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.ink)
                        )
                }
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 14)
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        onAdd(trimmed, hasDueDate ? dueDate : nil)
        title = ""
        hasDueDate = false
        dueDate = Calendar.current.startOfDay(for: Date())
        isTitleFocused = false
    }
}

#Preview {
    VStack {
        Spacer()
        AddTaskBottomSheet(isExpanded: .constant(false)) { _, _ in }
    }
    .themedBackground()
}
