import SwiftUI

struct MainListView: View {
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    private let rowHeight: CGFloat = 50
    private let minVisibleRows = 3
    private let maxVisibleRowsCap = 12
    @AppStorage("mounty.maxVisibleRows") private var maxVisibleRows: Int = 5

    @State private var isResizeHovered = false
    @State private var dragStartRows = 0

    private var listHeight: CGFloat {
        let count = manager.filteredAndSortedVolumes.count
        // Empty state uses the current row cap so the resize handle still works.
        if count == 0 { return CGFloat(maxVisibleRows) * rowHeight }
        return min(CGFloat(count), CGFloat(maxVisibleRows)) * rowHeight
    }

    private var isSearchVisible: Bool {
        manager.showSearch || !manager.searchText.isEmpty
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView(
                    title: "Mounty",
                    showLogo: true,
                    trailingAction: { viewMode = .settings },
                    trailingIcon: ("gearshape.fill", .secondary),
                    trailingHelp: "Settings",
                    trailingAction2: { viewMode = .logs },
                    trailingIcon2: ("doc.text", .secondary),
                    trailingHelp2: "App Logs"
                )
                .transaction { $0.animation = nil }

                // Search bar — declarative animation driven by isSearchVisible.
                // No withAnimation in the toggle action; the .animation modifier on
                // the VStack handles it, making the transition reliable.
                if isSearchVisible {
                    HStack(alignment: .center) {
                        TextField("Search...", text: $manager.searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 28)

                        Menu {
                            Picker("Sort By", selection: $manager.sortOrder) {
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
                                systemName: manager.sortDirection == .ascending
                                    ? "arrow.down" : "arrow.up"
                            )
                        }
                        .buttonStyle(.borderless)
                        .frame(width: 28, height: 28)
                        .help("Toggle Sort Direction")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }

                Divider()

                // List content
                if manager.filteredAndSortedVolumes.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(
                            systemName: manager.volumes.isEmpty
                                ? "externaldrive.badge.plus"
                                : "magnifyingglass"
                        )
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                        Text(
                            manager.volumes.isEmpty
                                ? "No Volumes Configured"
                                : "No Matching Volumes"
                        )
                        .font(.callout)
                        .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(height: listHeight)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(manager.filteredAndSortedVolumes) { volume in
                                VolumeRow(volume: volume, manager: manager)
                                    .frame(height: rowHeight)
                                Divider()
                            }
                        }
                    }
                    .frame(height: listHeight)
                    .scrollDisabled(
                        manager.filteredAndSortedVolumes.count <= maxVisibleRows
                    )
                }

                // Resize handle — drag vertically to reveal more or fewer rows.
                // Shows a grab pill on hover; the resize cursor confirms the gesture.
                ZStack {
                    Color.clear.frame(height: 8)
                    Divider()
                    if isResizeHovered || dragStartRows != 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 36, height: 3)
                    }
                }
                .contentShape(Rectangle())
                .onHover { hovering in
                    isResizeHovered = hovering
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else if dragStartRows == 0 {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragStartRows == 0 { dragStartRows = maxVisibleRows }
                            let delta = Int(round(value.translation.height / rowHeight))
                            maxVisibleRows = min(
                                max(minVisibleRows, dragStartRows + delta),
                                maxVisibleRowsCap
                            )
                        }
                        .onEnded { _ in
                            dragStartRows = 0
                            if !isResizeHovered { NSCursor.pop() }
                        }
                )

                // Footer — maxWidth: .infinity guarantees the Spacer always fills
                // the same distance regardless of what the list content does.
                HStack {
                    Button {
                        manager.showSearch.toggle()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(
                                isSearchVisible ? .accentColor : .secondary
                            )
                    }
                    .buttonStyle(.plain)
                    .iconButtonHover()
                    // Keyboard shortcut lives here — removes the need for the
                    // hidden zero-size Button that was causing erratic toggles.
                    .keyboardShortcut("f", modifiers: .command)
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
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
            // Declarative animation: fires reliably on every isSearchVisible change
            // because it's value-driven, not action-driven. The HeaderView's own
            // .transaction suppressor prevents it from animating along.
            .animation(.easeOut(duration: 0.18), value: isSearchVisible)
            .blur(radius: manager.showError ? 2 : 0)
            .disabled(manager.showError)

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
