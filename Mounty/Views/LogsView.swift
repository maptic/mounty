import SwiftUI

struct LogsView: View {
    var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    private var visibleEntries: [LogEntry] {
        manager.logEntries.filter { $0.level >= manager.minimumLogLevel }
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                title: "App Logs",
                backAction: { viewMode = .list }
            )

            Divider()

            if visibleEntries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(manager.logEntries.isEmpty ? "No Log Entries" : "No Entries at This Level")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 200)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(visibleEntries) { entry in
                                LogEntryRow(entry: entry)
                            }
                            Color.clear.frame(height: 1).id("logsBottom")
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 200)
                    .onChange(of: visibleEntries.count) { _, _ in
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

                Menu {
                    ForEach(LogEntry.Level.allCases, id: \.self) { level in
                        Button {
                            manager.setMinimumLogLevel(level)
                        } label: {
                            HStack {
                                if manager.minimumLogLevel == level {
                                    Image(systemName: "checkmark")
                                }
                                Text(level.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(manager.minimumLogLevel.label)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Minimum log level to display")

                Spacer()

                Button {
                    let text = visibleEntries.map { $0.formatted }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(
                            visibleEntries.isEmpty ? .secondary.opacity(0.4) : .secondary)
                }
                .iconButtonHover(cornerRadius: 5, padding: 4)
                .disabled(visibleEntries.isEmpty)
                .help("Copy visible log entries to clipboard")
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

                Text(
                    "\(entry.source.label) · "
                        + entry.timestamp.formatted(.dateTime.hour().minute().second())
                )
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }
}
