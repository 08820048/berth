import SwiftUI

struct PortRowView: View {
    let entry: PortEntry
    var store: PortStore
    var settings: AppSettings
    @State private var hovered = false

    private var isReleasing: Bool {
        store.isStopping && store.stopPrompt?.entry.port == entry.port
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(entry.isConflict ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                    .help(entry.isConflict ? L10n.string("row.conflict") : L10n.string("row.listening"))

                Text(rowTitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let startedAt = entry.startedAt {
                    Text(DurationFormat.short(from: startedAt))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .help(metricsHelp)
                }

                Text("\(entry.port)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                actionButtons
            }

            HStack(spacing: 6) {
                Text("pid \(entry.primaryPID)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Text(secondaryDetail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.leading, 13)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(hovered ? Color.primary.opacity(0.05) : Color.clear)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.string("a11y.portRow", entry.port, entry.title))
    }

    private var rowTitle: String {
        if let containerName = entry.containerName {
            return containerName
        }
        return entry.frameworkDisplayName ?? entry.processName
    }

    private var secondaryDetail: String {
        if let container = entry.containerEngine, entry.containerName != nil {
            return "\(entry.bindLabel) · \(container)"
        }
        if let command = truncatedCommand {
            return "\(entry.bindLabel) · \(command)"
        }
        return entry.bindLabel
    }

    private var truncatedCommand: String? {
        let command = entry.commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, command != entry.processName else { return nil }
        return command
    }

    private var metricsHelp: String {
        var parts: [String] = []
        if let startedAt = entry.startedAt {
            parts.append(DurationFormat.short(from: startedAt))
        }
        if let cpu = entry.cpuPercent {
            parts.append("\(Int(cpu.rounded()))%")
        }
        if let memory = entry.memoryBytes {
            parts.append(MemoryFormat.short(memory))
        }
        return parts.joined(separator: " · ")
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if entry.canOpenInBrowser, let url = entry.localhostURL {
                Button {
                    WorkspaceActions.openInBrowser(url)
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(QuietIconButtonStyle())
                .help(L10n.string("row.open"))
                .accessibilityLabel(L10n.string("a11y.open", entry.port))
            }

            Menu {
                moreMenu
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(QuietIconButtonStyle())
            .menuIndicator(.hidden)
            .fixedSize()
            .help(L10n.string("row.more"))
            .accessibilityLabel(L10n.string("a11y.more", entry.port))

            if entry.allowsPrimaryStop {
                Button {
                    store.requestStop(entry)
                } label: {
                    if isReleasing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text(L10n.string("row.release"))
                            .font(.caption.weight(.medium))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
                .disabled(store.isStopping || store.isStopModalPresented)
                .help(L10n.string("row.release"))
                .accessibilityLabel(L10n.string("a11y.stop", entry.port))
            }
        }
    }

    @ViewBuilder
    private var moreMenu: some View {
        if entry.canOpenInBrowser, let url = entry.localhostURL {
            Button(L10n.string("row.copyURL")) { Clipboard.copy(url.absoluteString) }
        }
        Button(L10n.string("row.copyPort")) { Clipboard.copy(String(entry.port)) }
        Button(L10n.string("row.copyPID")) {
            Clipboard.copy(entry.pids.map(String.init).joined(separator: ", "))
        }
        if let cwd = entry.cwd {
            Button(L10n.string("row.copyCWD")) { Clipboard.copy(cwd) }
        }
        Button(L10n.string("row.copyCommand")) { Clipboard.copy(entry.commandLine) }
        if let path = entry.projectPath ?? entry.cwd {
            Button(L10n.string("row.reveal")) { WorkspaceActions.revealInFinder(path) }
        }
        if let name = entry.containerName {
            Button(L10n.string("row.copyContainer")) { Clipboard.copy(name) }
        }

        Divider()

        if !entry.isProtected {
            Button(L10n.string("row.release")) {
                store.requestStop(entry)
            }
            Button(L10n.string("row.tree")) {
                Task { await store.stop(entry, includeTree: true) }
            }
            Button(L10n.string("row.force"), role: .destructive) {
                store.requestStop(entry, force: true)
            }
        }

        Divider()
        Button(L10n.string("row.ignore")) {
            settings.ignore(.port(entry.port))
        }
        Button(L10n.string("row.ignoreProcess")) {
            settings.ignore(.process(entry.processName))
        }
        if let path = entry.projectPath ?? entry.cwd {
            Button(L10n.string("row.ignorePath")) {
                settings.ignore(.path(path))
            }
        }
    }
}
