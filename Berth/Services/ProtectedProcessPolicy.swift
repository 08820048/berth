import Foundation

enum ProtectionReason: String, Sendable {
    case systemProcess
    case systemDaemon
}

enum ProtectedProcessPolicy {
    static let names: Set<String> = [
        "kernel_task",
        "launchd",
        "WindowServer",
        "syslogd",
        "mDNSResponder",
        "configd",
        "opendirectoryd",
        "UserEventAgent",
        "cfprefsd",
        "loginwindow",
        "coreservicesd",
        "distnoted",
        "notifyd",
        "securityd",
        "sandboxd",
        "syspolicyd",
        "amfid",
        "coreaudiod",
        "bluetoothd",
        "airportd",
        "ControlCenter",
        "Dock",
        "Finder",
        "SystemUIServer",
        "universalaccessd",
        "secd",
        "trustd",
        "locationd",
        "logd",
        "runningboardd",
        "dasd",
        "cloudd",
        "rapportd",
        "sharingd",
        "coreauthd",
        "diskarbitrationd",
        "powerd",
        "watchdogd",
        "fseventsd",
        "launchservicesd",
    ]

    static let pathPrefixes: [String] = [
        "/System/",
        "/usr/libexec/",
        "/usr/sbin/",
        "/sbin/",
    ]

    static func inspect(processName: String, executablePath: String?, uid: uid_t) -> ProtectionReason? {
        if names.contains(processName) {
            return .systemProcess
        }
        if let executablePath {
            if pathPrefixes.contains(where: { executablePath.hasPrefix($0) }) {
                return uid == 0 ? .systemDaemon : .systemProcess
            }
        }
        if processName.hasPrefix("com.apple.") {
            return .systemProcess
        }
        // 兜底：root 用户且可执行文件位于真正的系统目录
        if uid == 0, let path = executablePath {
            let strictSystemRoots = ["/System/", "/sbin/", "/bin/"]
            if strictSystemRoots.contains(where: { path.hasPrefix($0) }) {
                return .systemDaemon
            }
        }
        return nil
    }
}
