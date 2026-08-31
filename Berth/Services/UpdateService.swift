import Combine
import Sparkle

@MainActor
final class UpdateService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case checking
        case downloading
        case readyToInstall
    }

    private let controller: SPUStandardUpdaterController
    private let delegate: UpdaterDelegate
    private var pendingInstall: (() -> Void)?

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var phase: Phase = .idle

    init() {
        let delegate = UpdaterDelegate()
        self.delegate = delegate
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        // 自动下载更新始终开启，且不向用户暴露任何开关。
        controller.updater.automaticallyDownloadsUpdates = true

        delegate.onPhaseChange = { [weak self] phase in
            MainActor.assumeIsolated { self?.applyPhase(phase) }
        }
        delegate.onReadyToInstall = { [weak self] installHandler in
            MainActor.assumeIsolated {
                self?.pendingInstall = installHandler
                self?.phase = .readyToInstall
            }
        }
    }

    var automaticallyChecksForUpdates: Bool {
        controller.updater.automaticallyChecksForUpdates
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        guard phase != .readyToInstall else { return }
        phase = .checking
        controller.checkForUpdates(nil)
    }

    /// 静默安装已下载的更新并重启应用。
    func restartToUpdate() {
        guard let installHandler = pendingInstall else { return }
        pendingInstall = nil
        installHandler()
    }

    private func applyPhase(_ phase: Phase) {
        // 已拿到安装控制权后，后续周期回调不得覆盖“待重启”状态。
        guard self.phase != .readyToInstall else { return }
        self.phase = phase
    }
}

/// Sparkle 回调都发生在主线程；这里把事件同步转发给 `UpdateService`。
private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var onPhaseChange: (UpdateService.Phase) -> Void = { _ in }
    var onReadyToInstall: (@escaping () -> Void) -> Void = { _ in }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        MainActor.assumeIsolated { onPhaseChange(.downloading) }
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {}

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        MainActor.assumeIsolated { onPhaseChange(.downloading) }
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: any Error) {
        MainActor.assumeIsolated { onPhaseChange(.idle) }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock installHandler: @escaping () -> Void) -> Bool {
        MainActor.assumeIsolated {
            onReadyToInstall(installHandler)
        }
        return true
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        MainActor.assumeIsolated { onPhaseChange(.idle) }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        MainActor.assumeIsolated { onPhaseChange(.idle) }
    }
}
