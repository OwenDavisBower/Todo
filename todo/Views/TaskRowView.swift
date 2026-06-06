import SwiftUI

struct TaskRowView: View {
    let task: Task
    var filter: TaskFilter = .active
    var showDragHandle: Bool = true
    var isDragging: Bool = false
    var reorderOffset: CGFloat = 0
    var onTap: () -> Void
    var onComplete: () -> Void = {}
    var onRestore: () -> Void = {}
    var onDelete: () -> Void = {}
    var onReorderDragChanged: (CGFloat) -> Void = { _ in }
    var onReorderDragEnded: () -> Void = {}

    @State private var horizontalOffset: CGFloat = 0
    @State private var isPerformingAction = false
    @State private var isHorizontalSwipe = false

    private let actionThreshold: CGFloat = 80
    private let cardCornerRadius: CGFloat = 18

    var body: some View {
        ZStack {
            leadingActionBackground
            trailingActionBackground

            cardContent
                .offset(x: horizontalOffset)
                .offset(y: isDragging ? reorderOffset : 0)
                .scaleEffect(isDragging ? 1.02 : 1)
                .shadow(
                    color: AppTheme.ink.opacity(isDragging ? 0.14 : 0),
                    radius: isDragging ? 16 : 0,
                    y: isDragging ? 8 : 0
                )
        }
        .contentShape(Rectangle())
        .simultaneousGesture(horizontalDragGesture)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isDragging)
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            if showDragHandle {
                reorderHandle
            }

            completionIndicator

            HStack(spacing: 12) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let dueDate = task.dueDate {
                    dueDateBadge(for: dueDate)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .padding(.leading, showDragHandle ? 14 : 18)
        .padding(.trailing, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.white)
                .shadow(color: AppTheme.ink.opacity(0.07), radius: 10, y: 3)
        }
    }

    private var completionIndicator: some View {
        let progress = min(max(horizontalOffset / actionThreshold, 0), 1)

        return ZStack {
            Circle()
                .stroke(AppTheme.mist.opacity(0.6), lineWidth: 2)
                .frame(width: 22, height: 22)

            if filter == .active {
                Circle()
                    .fill(AppTheme.sage.opacity(progress))
                    .frame(width: 22, height: 22)

                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .scaleEffect(progress)
                    .opacity(progress)
            }
        }
        .animation(.easeOut(duration: 0.15), value: progress)
    }

    @ViewBuilder
    private var leadingActionBackground: some View {
        let progress = min(max(horizontalOffset / actionThreshold, 0), 1)

        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(AppTheme.sage)
                .overlay(alignment: .leading) {
                    Image(systemName: filter == .active ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.leading, 24)
                        .scaleEffect(0.85 + progress * 0.15)
                }

            Spacer(minLength: 0)
        }
        .opacity(horizontalOffset > 0 ? progress : 0)
    }

    @ViewBuilder
    private var trailingActionBackground: some View {
        let progress = min(max(-horizontalOffset / actionThreshold, 0), 1)

        HStack(spacing: 0) {
            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(AppTheme.ink)
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppTheme.blush.opacity(0.95))
                        .padding(.trailing, 24)
                        .scaleEffect(0.85 + progress * 0.15)
                }
        }
        .opacity(horizontalOffset < 0 ? progress : 0)
    }

    private var reorderHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.body.weight(.medium))
            .foregroundStyle(AppTheme.mist)
            .frame(width: 24, height: 36)
            .contentShape(Rectangle())
            .highPriorityGesture(reorderGesture)
            .accessibilityLabel("Reorder")
    }

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    onReorderDragChanged(drag.translation.height)
                default:
                    break
                }
            }
            .onEnded { _ in
                onReorderDragEnded()
            }
    }

    private var horizontalDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isPerformingAction else { return }

                if !isHorizontalSwipe {
                    let width = abs(value.translation.width)
                    let height = abs(value.translation.height)
                    guard width > 8, width > height else { return }
                    isHorizontalSwipe = true
                }

                horizontalOffset = value.translation.width
            }
            .onEnded { value in
                defer { isHorizontalSwipe = false }
                guard !isPerformingAction, isHorizontalSwipe else { return }
                handleHorizontalDragEnd(translation: value.translation.width)
            }
    }

    private func handleHorizontalDragEnd(translation: CGFloat) {
        if translation > actionThreshold {
            if filter == .active {
                performAction(offset: 500, haptic: .medium) { onComplete() }
            } else {
                performAction(offset: 500, haptic: .medium) { onRestore() }
            }
        } else if translation < -actionThreshold {
            performAction(offset: -500, haptic: .rigid) { onDelete() }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                horizontalOffset = 0
            }
        }
    }

    private func performAction(offset: CGFloat, haptic: UIImpactFeedbackGenerator.FeedbackStyle, action: @escaping () -> Void) {
        isPerformingAction = true
        UIImpactFeedbackGenerator(style: haptic).impactOccurred()

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            horizontalOffset = offset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            action()
            isPerformingAction = false
            horizontalOffset = 0
        }
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
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            TaskRowView(
                task: Task(title: "Buy groceries", sortOrder: 0, dueDate: Date()),
                onTap: {}
            )
            TaskRowView(
                task: Task(title: "Call dentist", sortOrder: 1),
                filter: .done,
                showDragHandle: false,
                onTap: {}
            )
        }
        .padding(20)
    }
    .themedBackground()
}
