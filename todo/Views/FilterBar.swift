import SwiftUI

struct FilterBar: View {
    @Binding var selection: TaskFilter
    let counts: (TaskFilter) -> Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TaskFilter.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = tab
                    }
                } label: {
                    Text("\(tab.title) · \(counts(tab))")
                        .font(.subheadline.weight(selection == tab ? .medium : .regular))
                        .foregroundStyle(selection == tab ? AppTheme.ink : AppTheme.sage)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(selection == tab ? AppTheme.lilac : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()

            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(AppTheme.sage)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
