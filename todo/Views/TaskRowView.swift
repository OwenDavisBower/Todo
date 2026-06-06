import SwiftUI

struct TaskRowView: View {
    let task: Task
    var filter: TaskFilter = .active
    var showDragHandle: Bool = true
    var isDragging: Bool = false
    var isSettling: Bool = false
    var reorderOffset: CGFloat = 0
    var reorderShift: CGFloat = 0
    var listCoordinateSpace: String = "taskList"
    var onTap: () -> Void
    var onComplete: () -> Void = {}
    var onRestore: () -> Void = {}
    var onDelete: () -> Void = {}
    var onReorderDragChanged: (CGFloat) -> Void = { _ in }
    var onReorderDragEnded: () -> Void = {}

    @State private var horizontalOffset: CGFloat = 0
    @State private var isPerformingAction = false
    @State private var isHorizontalSwipe = false
    @State private var isReorderDragging = false
    @State private var isCollapsing = false

    private let actionThreshold: CGFloat = 80
    private let cardCornerRadius: CGFloat = 18

    private var shouldAnimateReorder: Bool {
        !isDragging && !isSettling && !isReorderDragging
    }

    private var leadingSwipeProgress: CGFloat {
        min(max(horizontalOffset / actionThreshold, 0), 1)
    }

    private var trailingSwipeProgress: CGFloat {
        min(max(-horizontalOffset / actionThreshold, 0), 1)
    }

    private var isCompletingSwipe: Bool {
        filter == .active && leadingSwipeProgress > 0
    }

    var body: some View {
        ZStack {
            leadingActionBackground
            trailingActionBackground

            cardContent
                .offset(x: horizontalOffset)
                .scaleEffect(isDragging && !isSettling ? 1.03 : 1)
                .shadow(
                    color: AppTheme.ink.opacity(isDragging && !isSettling ? 0.12 : 0),
                    radius: isDragging && !isSettling ? 12 : 0,
                    y: isDragging && !isSettling ? 6 : 0
                )
        }
        .offset(y: reorderOffset + reorderShift)
        .scaleEffect(y: isCollapsing ? 0.01 : 1, anchor: .top)
        .opacity(isCollapsing ? 0 : 1)
        .frame(maxHeight: isCollapsing ? 0 : nil)
        .contentShape(Rectangle())
        .simultaneousGesture(horizontalDragGesture)
        .animation(shouldAnimateReorder ? .spring(response: 0.32, dampingFraction: 0.86) : nil, value: isDragging)
        .animation(shouldAnimateReorder ? .interactiveSpring(response: 0.28, dampingFraction: 0.86) : nil, value: reorderShift)
        .transaction { transaction in
            if !shouldAnimateReorder {
                transaction.animation = nil
            }
        }
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            if showDragHandle {
                reorderHandle
            } else {
                leadingSpacer
            }

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
            .opacity(completingSwipeTextOpacity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            if filter == .done {
                restoreButton
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
    }

    private var completingSwipeTextOpacity: Double {
        guard isCompletingSwipe else { return 1 }
        return 1 - Double(leadingSwipeProgress) * 0.65
    }

    @ViewBuilder
    private var leadingActionBackground: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(filter == .active ? AppTheme.sage : AppTheme.ink)
                .overlay(alignment: .leading) {
                    Image(systemName: filter == .active ? "checkmark.circle.fill" : "trash.circle.fill")
                        .font(.title)
                        .foregroundStyle(filter == .active ? .white.opacity(0.95) : AppTheme.blush.opacity(0.95))
                        .padding(.leading, 24)
                        .scaleEffect(0.72 + leadingSwipeProgress * 0.28)
                        .symbolEffect(.bounce, value: leadingSwipeProgress >= 1)
                }

            Spacer(minLength: 0)
        }
        .opacity(horizontalOffset > 0 ? leadingSwipeProgress : 0)
    }

    @ViewBuilder
    private var trailingActionBackground: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(filter == .active ? AppTheme.ink : AppTheme.sage)
                .overlay(alignment: .trailing) {
                    Image(systemName: filter == .active ? "trash.circle.fill" : "arrow.uturn.backward.circle.fill")
                        .font(.title)
                        .foregroundStyle(filter == .active ? AppTheme.blush.opacity(0.95) : .white.opacity(0.95))
                        .padding(.trailing, 24)
                        .scaleEffect(0.72 + trailingSwipeProgress * 0.28)
                        .symbolEffect(.bounce, value: trailingSwipeProgress >= 1)
                }
        }
        .opacity(horizontalOffset < 0 ? trailingSwipeProgress : 0)
    }

    private var leadingSpacer: some View {
        Color.clear
            .frame(width: 24, height: 36)
            .accessibilityHidden(true)
    }

    private var restoreButton: some View {
        Button {
            guard !isPerformingAction else { return }
            performAction(offset: -500, haptic: .medium) { onRestore() }
        } label: {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.sage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Restore to active")
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
        DragGesture(minimumDistance: 2, coordinateSpace: .named(listCoordinateSpace))
            .onChanged { value in
                isReorderDragging = true
                horizontalOffset = 0
                onReorderDragChanged(value.translation.height)
            }
            .onEnded { _ in
                isReorderDragging = false
                onReorderDragEnded()
            }
    }

    private var horizontalDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isPerformingAction, !isDragging, !isReorderDragging else { return }

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
                guard !isPerformingAction, !isDragging, !isReorderDragging, isHorizontalSwipe else { return }
                handleHorizontalDragEnd(translation: value.translation.width)
            }
    }

    private func handleHorizontalDragEnd(translation: CGFloat) {
        if translation > actionThreshold {
            if filter == .active {
                performAction(offset: 500, haptic: .medium) { onComplete() }
            } else {
                performAction(offset: 500, haptic: .rigid) { onDelete() }
            }
        } else if translation < -actionThreshold {
            if filter == .done {
                performAction(offset: -500, haptic: .medium) { onRestore() }
            } else {
                performAction(offset: -500, haptic: .rigid) { onDelete() }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                horizontalOffset = 0
            }
        }
    }

    private func performAction(offset: CGFloat, haptic: UIImpactFeedbackGenerator.FeedbackStyle, action: @escaping () -> Void) {
        isPerformingAction = true
        UIImpactFeedbackGenerator(style: haptic).impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            horizontalOffset = offset
        } completion: {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                isCollapsing = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                action()
                isPerformingAction = false
            }
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
                onTap: {},
                onRestore: {}
            )
        }
        .padding(20)
    }
    .themedBackground()
}
