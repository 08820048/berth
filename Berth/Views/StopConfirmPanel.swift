import AppKit
import SwiftUI

struct StopConfirmPanel: View {
    let prompt: StopPrompt
    let phase: StopPhase
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    private var name: String {
        prompt.entry.frameworkDisplayName ?? prompt.entry.processName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(L10n.string("confirm.detail", prompt.entry.port, prompt.entry.primaryPID))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            switch phase {
            case .confirm:
                confirmBody
            case .working:
                workingBody
            case .finished(let outcome):
                resultBody(outcome)
            }
        }
        .padding(18)
        .frame(width: 300, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 22, y: 10)
    }

    private var title: String {
        prompt.force
            ? L10n.string("confirm.forceTitle", name)
            : L10n.string("confirm.stopTitle", name)
    }

    @ViewBuilder
    private var confirmBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if prompt.entry.group == .database {
                Text(L10n.string("database.confirm.body", prompt.entry.port))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if prompt.entry.group == .container {
                Text(L10n.string("container.confirm.body", prompt.entry.containerName ?? prompt.entry.projectName, prompt.entry.port))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(prompt.force ? L10n.string("confirm.killHelp") : L10n.string("confirm.termHelp"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        HStack(spacing: 8) {
            Button(action: onDismiss) {
                Text(L10n.string("force.cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ConfirmButtonStyle(kind: .cancel))
            .keyboardShortcut(.cancelAction)

            Button(action: onConfirm) {
                Text(prompt.force ? L10n.string("force.confirm") : L10n.string("row.stop"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ConfirmButtonStyle(kind: .destructive))
            .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 4)
    }

    private var workingBody: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(L10n.string("confirm.stopping"))
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func resultBody(_ outcome: StopOutcome) -> some View {
        HStack(spacing: 8) {
            switch outcome {
            case .released, .alreadyGone, .processExited:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                Text(L10n.string("confirm.stopped"))
                    .font(.callout.weight(.medium))
            case .stillOccupied:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(L10n.string("stop.stillOccupied"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .protected:
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                Text(L10n.string("stop.protected"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .permissionDenied:
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                Text(L10n.string("stop.permission"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

private struct ConfirmButtonStyle: ButtonStyle {
    enum Kind { case cancel, destructive }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(kind == .destructive ? Color.white : Color.primary)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var fill: Color {
        switch kind {
        case .cancel: Color.primary.opacity(0.08)
        case .destructive: Color.red.opacity(0.9)
        }
    }
}
