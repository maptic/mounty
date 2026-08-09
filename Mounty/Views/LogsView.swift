import SwiftUI

struct LogsView: View {
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                title: "App Logs",
                backAction: { viewMode = .list }
            )

            Divider()

            if manager.logEntries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Log Entries")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 200)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(manager.logEntries) { entry in
                                LogEntryRow(entry: entry)
                            }
                            Color.clear.frame(height: 1).id("logsBottom")
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 200)
                    .onChange(of: manager.logEntries.count) { _, _ in
                        proxy.scrollTo("logsBottom", anchor: .bottom)
                    }
                    .onAppear {
                        proxy.scrollTo("logsBottom", anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    manager.clearLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .iconButtonHover(cornerRadius: 5, padding: 4)
                .help("Clear all log entries")

                Spacer()

                Button {
                    let text = manager.logEntries.map { $0.formatted }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(
                            manager.logEntries.isEmpty ? .secondary.opacity(0.4) : .secondary)
                }
                .iconButtonHover(cornerRadius: 5, padding: 4)
                .disabled(manager.logEntries.isEmpty)
                .help("Copy all logs to clipboard")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.level.symbol)
                .font(.system(size: 9))
                .foregroundColor(entry.level.color)
                .frame(width: 11)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }
}
