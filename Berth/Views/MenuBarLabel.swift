import SwiftUI

struct MenuBarLabel: View {
    var store: PortStore
    var settings: AppSettings

    var body: some View {
        HStack(spacing: 3) {
            BerthMenuBarIcon(state: iconState)
            if settings.showMenuBarCount, store.occupiedWatchedCount > 0, !store.isStopping {
                Text("\(store.occupiedWatchedCount)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }
        }
        .accessibilityLabel(
            store.isStopping
                ? L10n.string("menu.busy")
                : L10n.string("menu.count", store.occupiedWatchedCount)
        )
    }

    private var iconState: BerthMenuBarIconState {
        if store.isStopping { return .working }
        if store.hasConflict { return .conflict }
        return .normal
    }
}
