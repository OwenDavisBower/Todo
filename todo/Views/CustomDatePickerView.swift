import SwiftUI

struct CustomDatePickerView: View {
    @Binding var selectedDate: Date?
    var onRemove: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @State private var displayedMonth: Date

    private let calendar = Calendar.current
    private let weekdaySymbols: [String]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private struct QuickPick: Identifiable {
        let id: Int
        let label: String
        let dayOffset: Int
    }

    private let quickPicks = [
        QuickPick(id: 0, label: "Today", dayOffset: 0),
        QuickPick(id: 1, label: "Tomorrow", dayOffset: 1),
        QuickPick(id: 2, label: "3 days", dayOffset: 3),
        QuickPick(id: 3, label: "1 week", dayOffset: 7),
    ]

    init(
        selectedDate: Binding<Date?>,
        onRemove: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        _selectedDate = selectedDate
        self.onRemove = onRemove
        self.onDismiss = onDismiss
        let calendar = Calendar.current
        let anchor = selectedDate.wrappedValue ?? Date()
        _displayedMonth = State(initialValue: calendar.startOfMonth(for: anchor))
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        weekdaySymbols = Array(symbols[start...]) + Array(symbols[..<start])
    }

    var body: some View {
        VStack(spacing: 16) {
            quickPickRow
            monthHeader
            weekdayHeader
            dayGrid

            if selectedDate != nil, let onRemove {
                Button("Remove date") {
                    onRemove()
                    onDismiss?()
                }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.sage)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            if let selectedDate {
                displayedMonth = calendar.startOfMonth(for: selectedDate)
            }
        }
    }

    private var quickPickRow: some View {
        HStack(spacing: 8) {
            ForEach(quickPicks) { pick in
                Button {
                    selectDay(offset: pick.dayOffset)
                } label: {
                    Text(pick.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isQuickPickSelected(pick) ? AppTheme.ink : AppTheme.sage)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isQuickPickSelected(pick) ? AppTheme.lilac : AppTheme.surface)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button(action: { shiftMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.sage)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Spacer()

            Button(action: { shiftMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.sage)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.mist)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(for: day)
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectedDate = calendar.startOfDay(for: date)
            onDismiss?()
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .frame(width: 36, height: 36)
                .foregroundStyle(isSelected ? AppTheme.blush : AppTheme.ink)
                .background {
                    if isSelected {
                        Circle().fill(AppTheme.fillDark)
                    } else if isToday {
                        Circle().stroke(AppTheme.sage, lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var monthDays: [Date?] {
        let daysCount = calendar.daysInMonth(for: displayedMonth)
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in 1...daysCount {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: displayedMonth) {
                days.append(date)
            }
        }
        return days
    }

    private func selectDay(offset: Int) {
        let today = calendar.startOfDay(for: Date())
        selectedDate = calendar.date(byAdding: .day, value: offset, to: today)
        if let selectedDate {
            displayedMonth = calendar.startOfMonth(for: selectedDate)
        }
        onDismiss?()
    }

    private func shiftMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = calendar.startOfMonth(for: newMonth)
        }
    }

    private func isQuickPickSelected(_ pick: QuickPick) -> Bool {
        guard let selectedDate else { return false }
        let today = calendar.startOfDay(for: Date())
        guard let target = calendar.date(byAdding: .day, value: pick.dayOffset, to: today) else { return false }
        return calendar.isDate(selectedDate, inSameDayAs: target)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }

    func daysInMonth(for date: Date) -> Int {
        range(of: .day, in: .month, for: date)?.count ?? 30
    }
}

#Preview {
    @Previewable @State var date: Date? = Date()
    CustomDatePickerView(selectedDate: $date, onRemove: {
        date = nil
    })
    .themedBackground()
}
