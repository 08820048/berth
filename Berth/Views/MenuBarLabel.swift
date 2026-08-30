import SwiftUI

struct MenuBarLabel: View {
    var store: PortStore
    var settings: AppSettings

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: store.isStopping ? "arrow.triangle.2.circlepath" : (store.hasConflict ? "exclamationmark.triangle" : "network"))
                .symbolRenderingMode(.monochrome)
            if settings.showMenuBarCount, store.developmentCount > 0, !store.isStopping {
                Text("\(store.developmentCount)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }
        }
        .accessibilityLabel(
            store.isStopping
                ? L10n.string("menu.busy")
                : L10n.string("menu.count", store.developmentCount)
        )
    }
}
