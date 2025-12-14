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
        VStack(spacing: 0) {
            // Hidden button to catch keyboard shortcut
            Button("") { withAnimation { manager.showSearch.toggle() } }
                .keyboardShortcut("f", modifiers: .command)
                .frame(width: 0, height: 0)

            // --- HEADER ---
            HStack {
                Text("Mounty").font(.headline).fontWeight(.bold)
                Spacer()
                Button {
                    viewMode = .settings
                } label: {
                    Image(systemName: "gearshape.fill").foregroundColor(
                        .secondary
                    )
                }
                .buttonStyle(.plain).help("Settings")
            }
            .padding([.horizontal, .top], 12).padding(.bottom, 8)
            // *** THE FIX ***
            // This modifier intercepts the animation transaction and nullifies it
            // for this specific view and its children. The header will now snap
            // to its final position instantly, while other views animate.
            .transaction { transaction in
                transaction.animation = nil
            }

            // --- SEARCH BAR ---
            // The search bar is still added/removed conditionally,
            // and its animation is governed by the `withAnimation` block below.
            if isSearchVisible {
                HStack {
                    TextField("Search...", text: $manager.searchText)
                        .textFieldStyle(.roundedBorder).frame(height: 28)

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
                    .pickerStyle(.inline).menuStyle(.borderlessButton)
                    .frame(width: 28, height: 28).help("Sort By")

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
                    .frame(width: 28, height: 28).help("Toggle Sort Direction")
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            // List with dynamic height
            if manager.filteredAndSortedVolumes.isEmpty {
                VStack {
                    Spacer()
                    Text(
                        manager.volumes.isEmpty
                            ? "No Volumes Configured" : "No Matching Volumes"
                    )
                    .foregroundColor(.secondary)
                    Spacer()
                }.frame(height: listHeight)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(manager.filteredAndSortedVolumes) { volume in
                            VolumeRow(volume: volume, manager: manager).frame(
                                height: rowHeight
                            )
                            Divider()
                        }
                    }
                }.frame(height: listHeight)
            }

            Divider()

            // --- FOOTER ---
            HStack {
                Button {
                    // The withAnimation block triggers the animation for the whole view.
                    // The .transaction modifier on the header opts it out.
                    withAnimation { manager.showSearch.toggle() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(
                            isSearchVisible ? .accentColor : .secondary
                        )
                }
                .buttonStyle(.plain).help("Search Volumes (⌘F)")

                Spacer()

                Button {
                    viewMode = .add
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered).controlSize(.small).help("Add Volume")
            }
            .padding(12)
        }
        .alert(
            "Error",
            isPresented: $manager.showError,
            actions: {},
            message: { Text(manager.lastError ?? "Unknown") }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}
