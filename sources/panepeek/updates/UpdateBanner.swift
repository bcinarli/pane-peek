import SwiftUI
import AppKit

struct UpdateBanner: View {
    let updates: AppUpdates
    let window: NSWindow?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) { information; Spacer(minLength: 0); actions }
            VStack(alignment: .leading, spacing: 12) { information; actions }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: AppColours.chrome))
        .overlay(alignment: .bottom) { Rectangle().fill(Color(nsColor: AppColours.divider)).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("PanePeek updates")
        .onAppear { announce() }
        .onChange(of: updates.phase) { _, _ in announce() }
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            if let message { Text(message).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            if updates.phase == .downloading {
                ProgressView(value: updates.progress).frame(maxWidth: 280)
                    .accessibilityLabel("Update download")
            }
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 8) {
            switch updates.phase {
            case .hidden: EmptyView()
            case .checking, .opening:
                ProgressView().controlSize(.small).accessibilityLabel(title)
            case .current:
                Button("Done", action: updates.dismiss)
            case .available:
                Button("Later", action: updates.dismiss).disabled(updates.isBusy)
                if let offer = updates.offer {
                    Button(offer.actionTitle, action: updates.download)
                        .buttonStyle(.borderedProminent).disabled(updates.isBusy)
                        .help(offer.actionHelp).accessibilityHint(offer.actionHelp)
                }
            case .downloading:
                Button("Cancel", action: updates.cancel)
            case .completed:
                Button("Done", action: updates.dismiss)
                if let completion = updates.completion {
                    Button(completion.reopenTitle, action: updates.reopen).buttonStyle(.borderedProminent)
                }
            case .failed:
                Button("Later", action: updates.dismiss)
                Button("Try again", action: updates.retry).buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.large)
        .fixedSize()
    }

    private var title: String {
        switch updates.phase {
        case .hidden: ""
        case .checking: "Checking for updates…"
        case .current: "PanePeek is up to date"
        case .available: "PanePeek \(updates.offer?.version ?? "") is available"
        case .downloading: updates.offer?.progressTitle ?? "Preparing update…"
        case .opening: "Preparing update…"
        case .completed: updates.completion?.title ?? "Update ready"
        case .failed: "Update needs attention"
        }
    }

    private var message: String? {
        switch updates.phase {
        case .available: updates.offer.map { "Installed version: \($0.installedVersion)" }
        case .completed: updates.completion?.message
        case .failed: updates.errorMessage
        default: nil
        }
    }

    private func announce() {
        guard let window else { return }
        NSAccessibility.post(element: window, notification: .announcementRequested,
            userInfo: [.announcement: [title, message].compactMap { $0 }.joined(separator: ". "),
                       .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }
}
