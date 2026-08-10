import SwiftUI

// MARK: - Shared form fields

/// Reusable form body used by both AddVolumeView and EditVolumeView.
/// Manages its own focus state so callers only need to bind the name and address.
struct VolumeFormFields: View {
    @Binding var name: String
    @Binding var address: String
    var onSubmit: () -> Void = {}

    @FocusState private var focusedField: Field?
    private enum Field { case name, address }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TextField("Display Name (e.g. 'Work Drive')", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .address }

            HStack(spacing: 4) {
                Text("smb://")
                    .font(.body)
                    .foregroundColor(.secondary)

                TextField("server/share", text: $address)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .address)
                    .submitLabel(.done)
                    .onSubmit { onSubmit() }
                    .autocorrectionDisabled(true)
                    .onChange(of: address) { _, newValue in
                        let normalized = Volume.shareAddress(from: newValue)
                        if normalized != newValue { address = normalized }
                    }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                focusedField = .name
            }
        }
    }
}

// MARK: - Add Volume View

struct AddVolumeView: View {
    var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    @State private var name = ""
    @State private var address = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: "Add New Volume",
                backAction: { viewMode = .list }
            )

            Divider()

            VolumeFormFields(
                name: $name,
                address: $address,
                onSubmit: save
            )
            .padding(20)

            Spacer()

            HStack {
                Spacer()
                Button("Add Volume") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || address.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        guard !name.isEmpty, !address.isEmpty else { return }
        let fullAddress = Volume.smbServerAddress(from: address)
        manager.addVolume(Volume(name: name, serverAddress: fullAddress))
        viewMode = .list
    }
}

// MARK: - Edit Volume View

struct EditVolumeView: View {
    let volume: Volume
    var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    @State private var name: String
    @State private var address: String

    init(volume: Volume, manager: VolumeManager, viewMode: Binding<AppViewMode>) {
        self.volume = volume
        self.manager = manager
        self._viewMode = viewMode

        self._name = State(initialValue: volume.name)
        self._address = State(initialValue: Volume.shareAddress(from: volume.serverAddress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: "Edit Volume",
                backAction: { viewMode = .list }
            )

            Divider()

            VolumeFormFields(
                name: $name,
                address: $address,
                onSubmit: save
            )
            .padding(20)

            Spacer()

            HStack {
                Spacer()
                Button("Save Changes") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || address.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        guard !name.isEmpty, !address.isEmpty else { return }
        let fullAddress = Volume.smbServerAddress(from: address)
        manager.editVolume(id: volume.id, name: name, serverAddress: fullAddress)
        viewMode = .list
    }
}
