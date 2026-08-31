import AppKit
import SwiftUI

struct MenuBarPanel: View {
    @Bindable var store: PortStore
    var settings: AppSettings
    var onSettingsTransition: () -> Void
    @State private var selectedPort: Int?
    @State private var isPortsExpanded = false
    @State private var isSettingsPresented = false

    var body: some View {
        HStack(spacing: 0) {
            if isSettingsPresented {
                SettingsView(settings: settings) {
                    setSettingsPresented(false)
                }
                .frame(width: BerthLayout.settingsWidth)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            portPanel
        }
        .frame(
            width: BerthLayout.panelWidth + (isSettingsPresented ? BerthLayout.settingsWidth : 0),
            alignment: .trailing
        )
        .clipped()
        .animation(.smooth(duration: 0.28), value: isSettingsPresented)
        .onAppear {
            if selectedPort == nil {
                selectedPort = watchedPorts.first(where: { port in store.entries.contains { $0.port == port } }) ?? watchedPorts.first
            }
            Task { await store.refresh() }
        }
    }

    private var portPanel: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchBar
                berthStrip
                MenuHairline()
                content
                MenuHairline()
                footer
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(store.isStopModalPresented)
            .opacity(store.isStopModalPresented ? 0.28 : 1)

            if store.isStopModalPresented {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
            }

            if let prompt = store.stopPrompt {
                StopConfirmPanel(
                    prompt: prompt,
                    phase: store.stopPhase,
                    onConfirm: { Task { await store.confirmRequestedStop() } },
                    onDismiss: { store.dismissStopPrompt() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(width: BerthLayout.panelWidth)
        .animation(.easeOut(duration: 0.15), value: store.stopPrompt?.id)
    }

    private var isEmptyList: Bool {
        if store.scanError != nil { return true }
        return store.sections.allSatisfy { $0.entries.isEmpty && $0.hiddenCount == 0 }
    }

    private var listHeight: CGFloat {
        if isEmptyList { return BerthLayout.emptyListHeight }
        let estimated = store.sections.reduce(CGFloat.zero) { total, section in
            if section.kind == .development {
                return total + 52 + CGFloat(section.entries.count) * BerthLayout.rowHeight
            }
            return total + BerthLayout.groupHeaderHeight
                + CGFloat(section.entries.count) * BerthLayout.rowHeight
                + (section.hiddenCount > 0 ? 28 : 0)
        }
        return min(BerthLayout.maxListHeight, max(BerthLayout.minListHeight, estimated))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Berth")
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.82))
            Spacer()
            Text(L10n.string("header.count", store.visibleEntries.count))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: BerthLayout.headerHeight)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField(L10n.string("search.placeholder"), text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.82))
                .onSubmit(submitCommand)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(height: BerthLayout.searchHeight)
    }

    private var watchedPorts: [Int] {
        settings.watchedPorts.sorted()
    }

    private var berthStrip: some View {
        Group {
            if isPortsExpanded {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 48, maximum: 64), spacing: 6), count: 6),
                    spacing: 6
                ) {
                    ForEach(watchedPorts, id: \.self) { port in
                        berthSlot(port)
                    }
                }
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { isPortsExpanded = false }
                } label: {
                    Label(L10n.string("ports.showLess"), systemImage: "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(watchedPorts.prefix(6)), id: \.self) { port in
                        berthSlot(port)
                            .frame(width: 48)
                    }
                    if watchedPorts.count > 6 {
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { isPortsExpanded = true }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.semibold))
                                Text("+\(watchedPorts.count - 6)")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                            }
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 38)
                        }
                        .buttonStyle(.plain)
                        .help(L10n.string("ports.showMore"))
                        .accessibilityLabel(L10n.string("ports.showMore"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.025))
        .accessibilityLabel("Watched ports")
    }

    @ViewBuilder
    private func berthSlot(_ port: Int) -> some View {
        let entry = store.entries.first(where: { $0.port == port })
        BerthSlotView(port: port, entry: entry, isSelected: selectedPort == port, isReleasing: store.isStopping && store.stopPrompt?.entry.port == port)
            .onTapGesture {
                selectPort(port)
            }
    }

    private func selectPort(_ port: Int) {
        selectedPort = port
        store.searchText = ""
        if !watchedPorts.prefix(6).contains(port) {
            isPortsExpanded = true
        }
    }

    private func submitCommand() {
        let raw = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let tokens = raw.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        if let port = Int(tokens.first ?? ""), settings.watchedPorts.contains(port) {
            selectPort(port)
            return
        }
        guard tokens.count > 1, let port = Int(tokens[1]), let entry = store.entries.first(where: { $0.port == port }) else { return }
        switch tokens[0].lowercased() {
        case "release", "stop":
            store.searchText = ""
            store.requestStop(entry)
        case "force":
            store.searchText = ""
            store.requestStop(entry, force: true)
        case "open":
            store.searchText = ""
            if let url = entry.localhostURL { WorkspaceActions.openInBrowser(url) }
        default: break
        }
    }

    private var content: some View {
        Group {
            if let scanError = store.scanError {
                VStack(spacing: 8) {
                    Text(L10n.string("scan.failed"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(scanError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(L10n.string("empty.retry")) {
                        Task { await store.refresh() }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
                .frame(maxWidth: .infinity, minHeight: listHeight, maxHeight: listHeight)
                .padding(.horizontal, 16)
            } else if isEmptyList {
                Text(L10n.string("empty.development"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: listHeight, maxHeight: listHeight)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(store.sections) { section in
                                sectionView(section)
                                    .id(section.id)
                            }
                        }
                    }
                    .scrollIndicators(.automatic)
                    .frame(height: listHeight)
                    .onChange(of: selectedPort) { _, port in
                        guard let port,
                              let entry = store.entries.first(where: { $0.port == port }) else { return }
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo(entry.group == .development ? "dev-\(entry.projectKey)" : entry.group.rawValue, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private func sectionView(_ section: PanelSection) -> some View {
        if section.kind == .development {
            return AnyView(ProjectCardView(section: section, store: store, settings: settings, selectedPort: $selectedPort))
        }
        return AnyView(VStack(alignment: .leading, spacing: 0) {
            GroupHeaderView(section: section, store: store, settings: settings)
            if section.hiddenCount > 0 {
                Button(L10n.string("settings.showSystem")) {
                    store.revealSystemPorts()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            ForEach(section.entries) { entry in
                PortRowView(entry: entry, store: store, settings: settings)
            }
        })
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                setSettingsPresented(!isSettingsPresented)
            } label: {
                Image(systemName: isSettingsPresented ? "gearshape.fill" : "gearshape")
            }
            .buttonStyle(QuietIconButtonStyle())
            .help(L10n.string("settings.title"))
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(QuietIconButtonStyle())
            .help(L10n.string("settings.quit"))
            Spacer(minLength: 8)
            footerStatus
        }
        .padding(.horizontal, 12)
        .frame(height: BerthLayout.footerRowHeight)
    }

    @ViewBuilder
    private var footerStatus: some View {
        if store.isStopping {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.string("menu.busy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let banner = store.banner {
            HStack(spacing: 8) {
                Text(banner.text)
                    .font(.caption)
                    .foregroundStyle(banner.kind == .error ? Color.red : Color.secondary)
                    .lineLimit(1)
                Spacer()
                if banner.kind == .warning, let port = banner.port,
                   let entry = store.entries.first(where: { $0.port == port }) {
                    Button(L10n.string("stop.forceAction")) {
                        store.requestStop(entry, force: true)
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
                }
            }
        }
    }

    private func setSettingsPresented(_ presented: Bool) {
        onSettingsTransition()
        isSettingsPresented = presented
    }

}

private struct BerthSlotView: View {
    let port: Int
    let entry: PortEntry?
    let isSelected: Bool
    let isReleasing: Bool

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Circle()
                    .fill(entry == nil ? Color.secondary.opacity(0.35) : (entry?.isConflict == true ? Color.orange : Color.green))
                    .frame(width: 5, height: 5)
                Text("\(port)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
            if isReleasing {
                ProgressView().controlSize(.mini)
            } else if entry != nil {
                Text(entry?.bindScope == .allInterfaces ? "LAN" : L10n.string("row.local"))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 48, height: 38)
        .padding(.horizontal, 3)
        .background(isSelected ? Color.accentColor.opacity(0.17) : (entry == nil ? Color.clear : Color.primary.opacity(0.07)), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(entry == nil ? 0.14 : 0.06), lineWidth: isSelected ? 1 : 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .accessibilityLabel(entry == nil ? "Port \(port), empty" : "Port \(port), occupied")
    }
}

private struct ProjectCardView: View {
    let section: PanelSection
    var store: PortStore
    var settings: AppSettings
    @Binding var selectedPort: Int?

    private var isSelected: Bool {
        section.entries.contains { $0.port == selectedPort }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                selectedPort = section.entries.first?.port
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(section.entries.contains(where: \.isConflict) ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)
                    if let icon = section.entries.first?.frameworkDisplayName {
                        FrameworkIcon(name: icon, size: 14)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(section.title)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.82))
                            .lineLimit(1)
                        Text(summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 4)
                    if section.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ForEach(section.entries) { entry in
                PortRowView(entry: entry, store: store, settings: settings)
            }
        }
        .background(isSelected ? Color.accentColor.opacity(0.045) : Color.clear)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: String {
        let ports = section.entries.map { String($0.port) }.joined(separator: ", ")
        let scope = section.entries.contains(where: { $0.bindScope == .allInterfaces }) ? L10n.string("row.lan") : L10n.string("row.local")
        return "\(ports) · \(scope)"
    }
}

private struct GroupHeaderView: View {
    let section: PanelSection
    var store: PortStore
    var settings: AppSettings
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 5) {
            if let iconName = iconName {
                FrameworkIcon(name: iconName, size: 14)
            }
            Text(section.title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.82))
                .lineLimit(1)
            if let path = compactPath {
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            if hovered || section.isPinned, let key = section.projectKey {
                Button {
                    settings.togglePin(key)
                } label: {
                    Image(systemName: section.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(QuietIconButtonStyle())
                .help(section.isPinned ? L10n.string("row.unpin") : L10n.string("row.pin"))
            }
            if hovered, section.canStopAll, let key = section.projectKey {
                Button {
                    Task { await store.stopProject(key) }
                } label: {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(QuietIconButtonStyle(color: .red))
                .disabled(store.isStopping || store.isStopModalPresented)
                .help(L10n.string("row.stopAll"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .onHover { hovered = $0 }
    }

    private var iconName: String? {
        if let framework = section.entries.first?.frameworkDisplayName {
            return framework
        }
        if section.kind == .container { return "Docker" }
        if section.kind == .database { return "PostgreSQL" }
        return section.kind == .development ? section.title : nil
    }

    private var compactPath: String? {
        guard let path = section.entries.first?.projectPath else { return nil }
        return PathDisplay.compact(path)
    }
}
