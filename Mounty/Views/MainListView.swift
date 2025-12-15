import SwiftUI

struct MainListView: View {
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    private let rowHeight: CGFloat = 50
    private let maxVisibleRows = 5

    private var listHeight: CGFloat {
        let count = manager.filteredAndSortedVolumes.count
        if count == 0 { return 120 }
        return min(CGFloat(count), CGFloat(maxVisibleRows)) * rowHeight
    }

    private var isSearchVisible: Bool {
        manager.showSearch || !manager.searchText.isEmpty
    }

    var body: some View {
        ZStack {
            // Main Content Layer
            VStack(spacing: 0) {
                // Hidden shortcut trigger
                Button("") { withAnimation { manager.showSearch.toggle() } }
                    .keyboardShortcut("f", modifiers: .command)
                    .frame(width: 0, height: 0)
                    .opacity(0)

                HeaderView(
                    title: "Mounty",
                    showLogo: true,
                    trailingAction: { viewMode = .settings },
                    trailingIcon: ("gearshape.fill", .secondary),
                    trailingHelp: "Settings"
                )
                .transaction { $0.animation = nil }

                // Search Bar - Background matches Window Header
                if isSearchVisible {
                    VStack(spacing: 0) {
                        HStack(alignment: .center) {
                            TextField("Search...", text: $manager.searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(height: 28)

                            Menu {
                                Picker("Sort By", selection: $manager.sortOrder)
                                {
                                    ForEach(
                                        VolumeManager.SortOrder.allCases,
                                        id: \.self
                                    ) {
                                        Text($0.rawValue).tag($0)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down.circle")
                            }
                            .pickerStyle(.inline)
                            .menuStyle(.borderlessButton)
                            .frame(width: 28, height: 28)
                            .help("Sort By")

                            Button {
                                manager.sortDirection =
                                    (manager.sortDirection == .ascending)
                                    ? .descending : .ascending
                            } label: {
                                Image(
                                    systemName: manager.sortDirection
                                        == .ascending
                                        ? "arrow.down" : "arrow.up"
                                )
                            }
                            .buttonStyle(.borderless)
                            .frame(width: 28, height: 28)
                            .help("Toggle Sort Direction")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }

                Divider()

                // List
                if manager.filteredAndSortedVolumes.isEmpty {
                    VStack {
                        Spacer()
                        Text(
                            manager.volumes.isEmpty
                                ? "No Volumes Configured"
                                : "No Matching Volumes"
                        )
                        .foregroundColor(.secondary)
                        Spacer()
                    }.frame(height: listHeight)
                } else {
                    ScrollViewReader { _ in
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(manager.filteredAndSortedVolumes) {
                                    volume in
                                    VolumeRow(volume: volume, manager: manager)
                                        .frame(height: rowHeight)
                                    Divider()
                                }
                            }
                        }
                        .frame(height: listHeight)
                        .scrollDisabled(
                            manager.filteredAndSortedVolumes.count
                                <= maxVisibleRows
                        )
                    }
                }

                Divider()

                // Footer
                HStack {
                    Button {
                        withAnimation { manager.showSearch.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(
                                isSearchVisible ? .accentColor : .secondary
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Search Volumes (⌘F)")

                    Spacer()

                    Button {
                        viewMode = .add
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Add Volume")
                }
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .blur(radius: manager.showError ? 2 : 0)
            .disabled(manager.showError)

            // Overlay Layer
            if manager.showError {
                AlertOverlay(
                    title: "Error",
                    message: manager.lastError ?? "Unknown error",
                    isPresented: $manager.showError,
                    isError: true
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
