import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @ObservedObject var updates: UpdateService
    var onClose: () -> Void
    @State private var watchedText: String = ""
    @State private var loginError: String?
    @State private var launchAtLogin: Bool = false
    @State private var recordingHotKey = false
    @State private var automaticallyChecksForUpdates = true
    @Namespace private var refreshModeNS

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onClose) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(QuietIconButtonStyle())
                .help(L10n.string("settings.close"))
                .accessibilityLabel(L10n.string("settings.close"))

                Text(L10n.string("settings.title"))
                    .font(.headline)
                    .foregroundStyle(Color.primary.opacity(0.82))
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 48)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    generalSettings
                    updateSettings
                    watchedPortsSettings
                    ignoredSettings
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.automatic)
        }
        .frame(minHeight: BerthLayout.settingsMinHeight, maxHeight: .infinity, alignment: .top)
        .background(Color.primary.opacity(0.025))
        .toggleStyle(.switch)
        .onAppear {
            watchedText = settings.watchedPortsText
            launchAtLogin = settings.launchAtLogin
            automaticallyChecksForUpdates = updates.automaticallyChecksForUpdates
        }
        .onDisappear {
            HotKeyCenter.shared.isPaused = false
        }
        .onChange(of: recordingHotKey) { _, recording in
            HotKeyCenter.shared.isPaused = recording
        }
    }

    private var updateSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("settings.updates"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                settingToggle(
                    L10n.string("settings.autoCheckUpdates"),
                    isOn: $automaticallyChecksForUpdates
                )
                .onChange(of: automaticallyChecksForUpdates) { _, enabled in
                    updates.setAutomaticallyChecksForUpdates(enabled)
                }

                HStack {
                    Text(L10n.string("settings.version", appVersion))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        updates.checkForUpdates()
                    } label: {
                        Text(L10n.string("settings.checkForUpdates"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!updates.canCheckForUpdates)
                }
            }
            .font(.system(size: 12))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("settings.general"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L10n.string("settings.language"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker(L10n.string("settings.language"), selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.secondary)
                                .tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 140)
                    .help(L10n.string("settings.language.help"))
                }

                settingToggle(L10n.string("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try settings.setLaunchAtLogin(enabled)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = settings.launchAtLogin
                        }
                    }

                if let loginError {
                    Text(L10n.string("settings.loginError", loginError))
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Text(L10n.string("settings.refresh"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(RefreshMode.allCases) { mode in
                            refreshModeChip(mode)
                        }
                    }
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7),
                        value: settings.refreshMode
                    )
                }

                settingToggle(L10n.string("settings.menuBarCount"), isOn: $settings.showMenuBarCount)
                settingToggle(L10n.string("settings.showSystem"), isOn: $settings.showSystemPorts)

                HStack {
                    Text(L10n.string("settings.hotkey"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HotKeyRecorder(spec: $settings.hotKey, recording: $recordingHotKey)
                }
            }
            .font(.system(size: 12))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var watchedPortsSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("settings.watched"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(L10n.string("settings.watched"), text: $watchedText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .onChange(of: watchedText) { _, newValue in
                    settings.watchedPortsText = newValue
                }

            Text(L10n.string("settings.watchedHelp"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var ignoredSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("settings.ignore"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                if settings.ignoreRules.isEmpty {
                    Text(L10n.string("settings.ignoreEmpty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.ignoreRules) { rule in
                        HStack(spacing: 8) {
                            Text(label(for: rule))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                settings.unignore(rule)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(L10n.string("settings.ignoreRemove"))
                        }
                    }
                }
            }
            .font(.system(size: 12))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(L10n.string("settings.ignoreHelp"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func refreshModeChip(_ mode: RefreshMode) -> some View {
        let isSelected = settings.refreshMode == mode
        return Button {
            settings.refreshMode = mode
        } label: {
            Text(L10n.string("settings.refreshMode.\(mode.rawValue)"))
                .font(.caption2)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                            .matchedGeometryEffect(id: "refreshModePill", in: refreshModeNS)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                }
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(Color(.sRGB, red: 15 / 255, green: 164 / 255, blue: 251 / 255)) // #0FA4FB
                .fixedSize()
        }
    }

    private func label(for rule: IgnoreRule) -> String {
        switch rule {
        case .port(let value):
            return L10n.string("settings.ignorePort", value)
        case .process(let value):
            return L10n.string("settings.ignoreProcess", value)
        case .path(let value):
            return L10n.string("settings.ignorePath", value)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

private struct HotKeyRecorder: View {
    @Binding var spec: HotKeySpec
    @Binding var recording: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                recording.toggle()
            } label: {
                Text(recording ? L10n.string("settings.hotkey.recording") : spec.display)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.secondary)
            }
            .background(HotKeyCatcher(spec: $spec, recording: $recording))
            if spec != .defaultShortcut {
                Button {
                    spec = .defaultShortcut
                    recording = false
                } label: {
                    Text(L10n.string("settings.hotkey.reset"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct HotKeyCatcher: NSViewRepresentable {
    @Binding var spec: HotKeySpec
    @Binding var recording: Bool

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        context.coordinator.spec = $spec
        context.coordinator.recording = $recording
        nsView.coordinator = context.coordinator
        if recording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(spec: $spec, recording: $recording)
    }

    final class Coordinator {
        var spec: Binding<HotKeySpec>
        var recording: Binding<Bool>

        init(spec: Binding<HotKeySpec>, recording: Binding<Bool>) {
            self.spec = spec
            self.recording = recording
        }

        func handle(_ event: NSEvent) -> Bool {
            guard recording.wrappedValue, let next = HotKeySpec.from(event: event) else { return false }
            spec.wrappedValue = next
            recording.wrappedValue = false
            return true
        }
    }

    final class CatcherView: NSView {
        var coordinator: Coordinator?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if coordinator?.handle(event) == true { return }
            super.keyDown(with: event)
        }
    }
}
