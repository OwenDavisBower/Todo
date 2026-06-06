import SwiftUI

struct AddTaskBottomSheet: View {
    @Binding var isExpanded: Bool

    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.startOfDay(for: Date())
    @FocusState private var isTitleFocused: Bool

    let onAdd: (String, Date?) -> Void

    private let cardCornerRadius: CGFloat = 18

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showAddButton: Bool {
        !trimmedTitle.isEmpty
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

    private var inputRow: some View {
        HStack(spacing: 12) {
            TextField("Add task…", text: $title)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.ink)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit(submit)

            if showAddButton {
                Button(action: submit) {
                    Text("Add")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.blush)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(AppTheme.ink))
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.75).combined(with: .opacity))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.white)
                .shadow(color: AppTheme.ink.opacity(0.07), radius: 10, y: 3)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showAddButton)
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

#Preview {
    VStack {
        Spacer()
        AddTaskBottomSheet(isExpanded: .constant(false)) { _, _ in }
    }
    .themedBackground()
}
