import Foundation

struct PanelSection: Identifiable, Equatable {
    let id: String
    let title: String
    let kind: PortGroupKind
    let entries: [PortEntry]
    var hiddenCount: Int = 0
    var projectKey: String? = nil
    var isPinned: Bool = false
    var canStopAll: Bool = false
}

@MainActor
@Observable
final class PortStore {
    private(set) var entries: [PortEntry] = []
    private(set) var scanError: String?
    private(set) var isScanning = false
    private(set) var isStopping = false
    private(set) var banner: BannerMessage?
    var stopPrompt: StopPrompt?
    var stopPhase: StopPhase = .confirm
    var searchText = ""

    let settings: AppSettings
    private var pollTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        startPolling()
        Task { await refresh() }
    }

    var developmentCount: Int {
        visibleEntries.filter { $0.group == .development }.count
    }

    var occupiedWatchedCount: Int {
        visibleEntries.filter { $0.isWatched && $0.group == .development }.count
    }

    var hasConflict: Bool {
        visibleEntries.contains(where: \.isConflict)
    }

    var visibleEntries: [PortEntry] {
        entries.filter { !IgnoreMatcher.isIgnored($0, rules: settings.ignoreRules) }
    }

    var sections: [PanelSection] {
        let filtered = applySearch(visibleEntries)
        var result: [PanelSection] = []

        let development = filtered.filter { $0.group == .development }
        let byProject = Dictionary(grouping: development, by: \.projectKey)
        let keys = byProject.keys.sorted { lhs, rhs in
            let pinL = settings.isPinned(lhs)
            let pinR = settings.isPinned(rhs)
            if pinL != pinR { return pinL && !pinR }
            let timeL = PortEntry.newestStart(byProject[lhs] ?? [])
            let timeR = PortEntry.newestStart(byProject[rhs] ?? [])
            if timeL != timeR { return timeL > timeR }
            let nameL = byProject[lhs]?.first?.projectName ?? lhs
            let nameR = byProject[rhs]?.first?.projectName ?? rhs
            return nameL.localizedCaseInsensitiveCompare(nameR) == .orderedAscending
        }
        for key in keys {
            let rows = (byProject[key] ?? []).sorted(by: PortEntry.recencyDescending)
            let title = rows.first?.projectName ?? key
            result.append(
                PanelSection(
                    id: "dev-\(key)",
                    title: title,
                    kind: .development,
                    entries: rows,
                    projectKey: key,
                    isPinned: settings.isPinned(key),
                    canStopAll: rows.contains(where: \.allowsPrimaryStop)
                )
            )
        }

        func appendGroup(_ kind: PortGroupKind, title: String) {
            let rows = filtered.filter { $0.group == kind }.sorted(by: PortEntry.recencyDescending)
            if !rows.isEmpty {
                result.append(PanelSection(id: kind.rawValue, title: title, kind: kind, entries: rows))
            }
        }

        appendGroup(.database, title: L10n.string("group.database"))
        appendGroup(.container, title: L10n.string("group.container"))
        appendGroup(.other, title: L10n.string("group.other"))

        let systemRows = filtered.filter { $0.group == .system }.sorted(by: PortEntry.recencyDescending)
        let hiddenSystem = visibleEntries.filter { $0.group == .system }.count
        if settings.showSystemPorts {
            if !systemRows.isEmpty {
                result.append(
                    PanelSection(
                        id: "system",
                        title: L10n.string("group.system"),
                        kind: .system,
                        entries: systemRows
                    )
                )
            }
        } else if hiddenSystem > 0, searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(
                PanelSection(
                    id: "system-hidden",
                    title: L10n.string("group.systemHidden", hiddenSystem),
                    kind: .system,
                    entries: [],
                    hiddenCount: hiddenSystem
                )
            )
        }

        return result
    }

    var showsEmptyDevelopment: Bool {
        visibleEntries.filter { $0.group == .development }.isEmpty && scanError == nil
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let interval = UInt64(max(self.settings.refreshInterval, 1) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: interval)
                if Task.isCancelled { break }
                await self.refresh()
            }
        }
    }

    func refresh() async {
        if isStopping { return }
        isScanning = true
        let watched = settings.watchedPorts
        let result: Result<[PortEntry], Error> = await Task.detached(priority: .utility) {
            let engine = PortScanEngine(watchedPorts: watched)
            do {
                return .success(try engine.scan())
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let next):
            entries = next
            scanError = nil
        case .failure(let error):
            scanError = error.localizedDescription
        }
        isScanning = false
    }

    var isStopModalPresented: Bool { stopPrompt != nil }

    func requestStop(_ entry: PortEntry, force: Bool = false) {
        guard !entry.isProtected else {
            showBanner(.init(kind: .error, text: L10n.string("stop.protected"), port: entry.port))
            return
        }
        stopPrompt = StopPrompt(entry: entry, force: force)
        stopPhase = .confirm
    }

    func dismissStopPrompt() {
        if case .working = stopPhase { return }
        stopPrompt = nil
        stopPhase = .confirm
    }

    func confirmRequestedStop() async {
        guard let prompt = stopPrompt else { return }
        await stop(prompt.entry, force: prompt.force, includeTree: prompt.force ? true : nil, fromPrompt: true)
    }

    func stop(_ entry: PortEntry, force: Bool = false, includeTree: Bool? = nil, fromPrompt: Bool = false) async {
        guard !entry.isProtected else {
            showBanner(.init(kind: .error, text: L10n.string("stop.protected"), port: entry.port))
            return
        }
        isStopping = true
        if fromPrompt {
            stopPhase = .working
        } else {
            stopPrompt = nil
            stopPhase = .confirm
        }
        let tree = includeTree ?? entry.usesProcessTreeByDefault
        let port = entry.port
        let watched = settings.watchedPorts
        let outcome = await Task.detached(priority: .userInitiated) { () -> StopOutcome in
            let engine = PortScanEngine(watchedPorts: watched)
            let terminator = ProcessTerminator(scan: { try engine.scan() }, containers: engine.docker)
            return terminator.stop(port: port, force: force, includeTree: tree)
        }.value
        await refresh()
        isStopping = false
        if fromPrompt {
            stopPhase = .finished(outcome)
            try? await Task.sleep(nanoseconds: 900_000_000)
            stopPrompt = nil
            stopPhase = .confirm
        }
        handle(outcome, port: port, entry: entry)
    }

    func stopProject(_ key: String) async {
        let targets = visibleEntries.filter { $0.group == .development && $0.projectKey == key && $0.allowsPrimaryStop }
        guard !targets.isEmpty else { return }
        isStopping = true
        var released = 0
        var occupied: PortEntry?
        for entry in targets {
            let port = entry.port
            let watched = settings.watchedPorts
            let tree = entry.usesProcessTreeByDefault
            let outcome = await Task.detached(priority: .userInitiated) { () -> StopOutcome in
                let engine = PortScanEngine(watchedPorts: watched)
                let terminator = ProcessTerminator(scan: { try engine.scan() }, containers: engine.docker)
                return terminator.stop(port: port, force: false, includeTree: tree)
            }.value
            switch outcome {
            case .released, .alreadyGone, .processExited:
                released += 1
            case .stillOccupied:
                occupied = entry
            default:
                break
            }
        }
        await refresh()
        isStopping = false
        if let occupied {
            let current = entries.first(where: { $0.port == occupied.port }) ?? occupied
            showBanner(.init(kind: .warning, text: L10n.string("stop.stillOccupied"), port: occupied.port))
            requestStop(current, force: true)
        } else {
            showBanner(.init(kind: .success, text: L10n.string("stop.projectReleased", released, targets.first?.projectName ?? key), port: nil))
        }
    }

    func revealSystemPorts() {
        settings.showSystemPorts = true
    }

    func showBanner(_ message: BannerMessage) {
        banner = message
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if Task.isCancelled { return }
            if self?.banner?.id == message.id {
                self?.banner = nil
            }
        }
    }

    private func handle(_ outcome: StopOutcome, port: Int, entry: PortEntry) {
        switch outcome {
        case .released, .alreadyGone:
            showBanner(.init(kind: .success, text: L10n.string("stop.released", port), port: port))
        case .stillOccupied:
            showBanner(.init(kind: .warning, text: L10n.string("stop.stillOccupied"), port: port))
        case .protected:
            showBanner(.init(kind: .error, text: L10n.string("stop.protected"), port: port))
        case .permissionDenied:
            showBanner(.init(kind: .error, text: L10n.string("stop.permission"), port: port))
        case .processExited:
            showBanner(.init(kind: .success, text: L10n.string("stop.released", port), port: port))
        case .failed(let message):
            showBanner(.init(kind: .error, text: message, port: port))
        }
    }

    private func applySearch(_ source: [PortEntry]) -> [PortEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return source.filter { entry in
            if query.isEmpty { return true }
            let haystack = [
                String(entry.port),
                entry.processName,
                entry.projectName,
                entry.cwd ?? "",
                entry.commandLine,
                entry.frameworkDisplayName ?? "",
                entry.containerName ?? "",
                entry.user,
                entry.bindLabel,
            ]
            .joined(separator: " ")
            .lowercased()
            return haystack.contains(query)
        }
    }
}
