import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var watchedText: String = ""
    @State private var loginError: String?
    @State private var launchAtLogin: Bool = false
    @State private var recordingHotKey = false

    var body: some View {
        Form {
            Section(L10n.string("settings.general")) {
                Toggle(L10n.string("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try settings.setLaunchAtLogin(enabled)
                            loginError = nil
                        } catch {
                            loginError = L10n.string("settings.loginError", error.localizedDescription)
                            launchAtLogin = settings.launchAtLogin
                        }
                    }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                LabeledContent(L10n.string("settings.refresh")) {
                    Stepper(value: $settings.refreshInterval, in: 1...15, step: 1) {
                        Text(L10n.string("settings.refreshUnit", Int(settings.refreshInterval)))
                            .monospacedDigit()
                    }
                    .frame(width: 140)
                }

                Toggle(L10n.string("settings.menuBarCount"), isOn: $settings.showMenuBarCount)
                Toggle(L10n.string("settings.showSystem"), isOn: $settings.showSystemPorts)

                LabeledContent(L10n.string("settings.hotkey")) {
                    HotKeyRecorder(spec: $settings.hotKey, recording: $recordingHotKey)
                }
            }

            Section {
                TextField(L10n.string("settings.watched"), text: $watchedText, axis: .vertical)
                    .lineLimit(2...4)
                    .onChange(of: watchedText) { _, newValue in
                        settings.watchedPortsText = newValue
                    }
            } header: {
                Text(L10n.string("settings.watched"))
            } footer: {
                Text(L10n.string("settings.watchedHelp"))
            }

            Section {
                if settings.ignoreRules.isEmpty {
                    Text(L10n.string("settings.ignoreEmpty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.ignoreRules) { rule in
                        HStack {
                            Text(label(for: rule))
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                settings.unignore(rule)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(L10n.string("settings.ignoreRemove"))
                        }
                    }
                }
            } header: {
                Text(L10n.string("settings.ignore"))
            } footer: {
                Text(L10n.string("settings.ignoreHelp"))
            }

            Section {
                Button(L10n.string("settings.quit"), role: .destructive) {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 520)
        .navigationTitle(L10n.string("settings.title"))
        .onAppear {
            watchedText = settings.watchedPortsText
            launchAtLogin = settings.launchAtLogin
            BerthAppDelegate.shared?.revealForSettings()
        }
        .onDisappear {
            HotKeyCenter.shared.isPaused = false
            BerthAppDelegate.shared?.returnToAccessory()
        }
        .onChange(of: recordingHotKey) { _, recording in
            HotKeyCenter.shared.isPaused = recording
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
}

private struct HotKeyRecorder: View {
    @Binding var spec: HotKeySpec
    @Binding var recording: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button(recording ? L10n.string("settings.hotkey.recording") : spec.display) {
                recording.toggle()
            }
            .background(HotKeyCatcher(spec: $spec, recording: $recording))
            if spec != .defaultShortcut {
                Button(L10n.string("settings.hotkey.reset")) {
                    spec = .defaultShortcut
                    recording = false
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
