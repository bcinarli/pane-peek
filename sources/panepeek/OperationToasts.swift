import SwiftUI
import AppKit
import PanePeekCore

private typealias ViewState<Value> = SwiftUI.State<Value>

struct OperationToasts: View {
    let notifications: OperationNotifications
    let prompts: BrowserPrompts
    @ViewState<OperationNotifications.Notice?> private var details = nil

    var body: some View {
        ViewThatFits(in: .vertical) {
            rows.fixedSize(horizontal: false, vertical: true)
            ScrollViewReader { scroll in
                ScrollView { rows }
                    .onChange(of: notifications.notices.first?.id, initial: true) { _, id in
                        if let id { scroll.scrollTo(id, anchor: .top) }
                    }
            }
            .frame(height: 240)
        }
        .frame(width: 420)
        .frame(maxHeight: 240, alignment: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Operation notifications")
        .popover(item: $details, arrowEdge: .top) { notice in
            NotificationDetails(notice: notice)
        }
        .onChange(of: notifications.notices) { old, new in
            guard let window = prompts.window else { return }
            for notice in new.reversed() where !old.contains(where: { $0.id == notice.id }) {
                NSAccessibility.post(element: window, notification: .announcementRequested,
                    userInfo: [.announcement: notice.kind == .error ? "Needs attention. \(notice.summary)" : notice.summary,
                               .priority: NSAccessibilityPriorityLevel.medium.rawValue])
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 8) {
            ForEach(notifications.notices) { notice in
                HStack(spacing: 10) {
                    if notice.kind == .progress {
                        ProgressView().controlSize(.small)
                            .accessibilityLabel("Operation in progress")
                    } else {
                        Image(systemName: notice.kind == .error ? "exclamationmark.triangle" : (notice.kind == .success ? "checkmark.circle" : "info.circle"))
                            .accessibilityHidden(true)
                    }
                    Text(notice.summary)
                        .font(.callout)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(notice.kind == .error ? "Needs attention. \(notice.summary)" : notice.summary)
                    if notice.kind != .progress {
                        if notice.kind != .success {
                            Button { details = notice } label: {
                                Image(systemName: "info.circle").frame(width: 28, height: 28)
                            }
                            .accessibilityLabel("Show notification details: \(notice.summary)")
                            .help("Show full outcome and paths")
                        }
                        Button { notifications.dismiss(notice.id) } label: {
                            Image(systemName: "xmark").frame(width: 28, height: 28)
                        }
                        .accessibilityLabel("Dismiss notification: \(notice.summary)")
                        .help("Dismiss notification")
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .padding(10)
                .background(Color(nsColor: AppColours.floating), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color(nsColor: AppColours.divider)) }
                .shadow(color: .black.opacity(0.16), radius: 6, y: 2)
                .accessibilityElement(children: .contain)
            }
        }
        .padding(6)
    }
}

private struct NotificationDetails: View {
    let notice: OperationNotifications.Notice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Operation details").font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                Text(notice.message)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 320)
        }
        .padding(16)
        .frame(width: 520)
        .background(Color(nsColor: AppColours.floating))
        .onExitCommand { dismiss() }
    }
}
