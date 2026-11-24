import SwiftUI

/// A page's two halves side by side, above it (Clipboard / Shelf, Events / Reminders): quiet
/// capsules, the selected one lit.
struct PageSwitch: View {
    struct Option: Identifiable {
        let title: LocalizedStringKey
        var count: Int? = nil
        let selected: Bool
        let action: () -> Void
        var id: String { "\(title)" }
    }

    let options: [Option]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                PageSwitchButton(option: option)
            }
            Spacer()
        }
        .frame(height: IslandLayout.pageSwitchHeight)
    }
}

private struct PageSwitchButton: View {
    let option: PageSwitch.Option

    var body: some View {
        Button(action: option.action) {
            HStack(spacing: 4) {
                Text(option.title)
                if let count = option.count {
                    Text("\(count)")
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(option.selected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 10)
            .frame(height: IslandLayout.pageSwitchHeight)
            .background(Capsule().fill(Color.white.opacity(option.selected ? 0.14 : 0)))
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(.normal, hoverWash: !option.selected))
    }
}
