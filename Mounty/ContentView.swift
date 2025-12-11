//
//  ContentView.swift
//  Mounty
//
//  Created by Merlin Unterfinger on 11.12.2025.
//


import SwiftUI

struct ContentView: View {
    @StateObject var manager: FilerManager
    @State private var showingAddSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // -- HEADER --
            HStack {
                Text("Mounty")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("Start at Login", isOn: $manager.launchAtLogin)
                    .controlSize(.mini)
                    .toggleStyle(.switch)
                    .font(.caption)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // -- LIST --
            if manager.filers.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(manager.filers) { filer in
                            FilerRow(filer: filer, manager: manager)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }
            
            Divider()
            
            // -- FOOTER --
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                
                Spacer()
                
                Button(action: { showingAddSheet = true }) {
                    Label("Add Filer", systemImage: "plus")
                }
            }
            .buttonStyle(.borderless) // Standard text buttons for footer
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 340)
        .sheet(isPresented: $showingAddSheet) {
            AddFilerView(manager: manager, isPresented: $showingAddSheet)
        }
    }
}

// -- SUBVIEW: Row --
struct FilerRow: View {
    let filer: Filer
    @ObservedObject var manager: FilerManager
    
    var isMounted: Bool {
        manager.mountedStatus[filer.id] ?? false
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Status Dot
            Circle()
                .fill(isMounted ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .help(isMounted ? "Mounted" : "Disconnected")
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(filer.name)
                    .font(.system(size: 13, weight: .medium))
                
                HStack(spacing: 4) {
                    Image(systemName: "network")
                    Text(filer.mountPoint)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 0) {
                // Copy Path Button
                Button {
                    manager.copyPath(filer)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("Copy Path")
                .disabled(!isMounted)
                .opacity(isMounted ? 1 : 0.3)
                
                // Automount Toggle (Icon based)
                Button {
                    manager.toggleAutomount(for: filer.id)
                } label: {
                    Image(systemName: filer.isAutomountEnabled ? "bolt.fill" : "bolt.slash")
                        .foregroundColor(filer.isAutomountEnabled ? .yellow : .secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("Toggle Automount")
                
                // Mount/Unmount Button
                if isMounted {
                    Button("Eject") {
                        manager.unmount(filer)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                } else {
                    Button("Mount") {
                        manager.mount(filer)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.clear)
        .contextMenu {
            Button("Remove Filer") {
                manager.removeFiler(id: filer.id)
            }
        }
    }
}

// -- SUBVIEW: Empty State --
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No Filers Configured")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
    }
}