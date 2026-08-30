import AppKit
import SwiftUI

struct MenuBarPanel: View {
    @Bindable var store: PortStore
    var settings: AppSettings
    var onOpenSettings: () -> Void
    var onSizeChange: ((CGSize) -> Void)? = nil

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchBar
                MenuHairline()
                content
                MenuHairline()
                footer
            }
            .disabled(store.isStopModalPresented)
            .opacity(store.isStopModalPresented ? 0.28 : 1)

            if store.isStopModalPresented {
                Color.black.opacity(0.38)
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
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeOut(duration: 0.15), value: store.stopPrompt?.id)
        .onAppear {
            Task { await store.refresh() }
            reportSize()
        }
        .onChange(of: panelHeight) { _, _ in
            reportSize()
        }
    }

    private var visibleRowCount: Int {
        store.sections.reduce(0) { $0 + $1.entries.count }
    }

    private var isEmptyList: Bool {
        if store.scanError != nil { return true }
        return store.sections.allSatisfy { $0.entries.isEmpty && $0.hiddenCount == 0 }
    }

    private var listHeight: CGFloat {
        BerthLayout.listHeight(rows: visibleRowCount, groups: store.sections.count, empty: isEmptyList)
    }

    private var bannerHeight: CGFloat {
        (store.isStopping || store.banner != nil) ? 33 : 0
    }

    private var panelHeight: CGFloat {
        BerthLayout.headerHeight + BerthLayout.searchHeight + listHeight + bannerHeight + (BerthLayout.footerRowHeight * 2)
    }

    private func reportSize() {
        onSizeChange?(CGSize(width: BerthLayout.panelWidth, height: panelHeight))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Berth")
                .font(.headline)
            Spacer()
            Text(L10n.string("header.count", store.visibleEntries.count))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            filterMenu
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: BerthLayout.headerHeight)
    }

    private var filterMenu: some View {
        Menu {
            Picker(L10n.string("filter.all"), selection: $store.filter) {
                ForEach(QuickFilter.allCases) { item in
                    Text(chipTitle(item)).tag(item)
                }
            }
        } label: {
            Image(systemName: store.filter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help(L10n.string("filter.all"))
        .accessibilityLabel(chipTitle(store.filter))
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField(L10n.string("search.placeholder"), text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(height: BerthLayout.searchHeight)
    }

    private var content: some View {
        Group {
            if let scanError = store.scanError {
                VStack(spacing: 8) {
                    Text(L10n.string("scan.failed"))
                        .font(.subheadline)
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(store.sections) { section in
                            sectionView(section)
                        }
                    }
                }
                .scrollIndicators(.automatic)
                .background(Color(nsColor: .windowBackgroundColor))
                .background(PanelScrollFix())
                .frame(height: listHeight)
            }
        }
    }

    private func sectionView(_ section: PanelSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            footerMessage
            footerButton(icon: "gearshape", title: L10n.string("settings.title"), shortcut: "⌘,") {
                onOpenSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            footerButton(icon: "power", title: L10n.string("settings.quit"), shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    @ViewBuilder
    private var footerMessage: some View {
        if store.isStopping {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.string("menu.busy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
        }
    }

    private func footerButton(icon: String, title: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(title)
                Spacer()
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(height: BerthLayout.footerRowHeight)
    }

    private func chipTitle(_ filter: QuickFilter) -> String {
        switch filter {
        case .all: return L10n.string("filter.all")
        case .development: return L10n.string("filter.development")
        case .database: return L10n.string("filter.database")
        case .exposed: return L10n.string("filter.exposed")
        }
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
