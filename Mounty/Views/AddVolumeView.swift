import SwiftUI

// MARK: - Shared types

enum VolumeProtocolType: String, CaseIterable, Identifiable {
    case smb = "SMB"
    case afp = "AFP"
    case nfs = "NFS"
    case ftp = "FTP"
    var id: String { rawValue }
    var scheme: String { rawValue.lowercased() + "://" }
}

// MARK: - Shared form fields

/// Reusable form body used by both AddVolumeView and EditVolumeView.
/// Manages its own focus state so callers only need to bind name/address/protocol.
struct VolumeFormFields: View {
    @Binding var name: String
    @Binding var address: String
    @Binding var selectedProtocol: VolumeProtocolType
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

            Picker("Protocol", selection: $selectedProtocol) {
                ForEach(VolumeProtocolType.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 4) {
                Text(selectedProtocol.scheme)
                    .font(.body)
                    .foregroundColor(.secondary)

                TextField("server/share", text: $address)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .address)
                    .submitLabel(.done)
                    .onSubmit { onSubmit() }
                    .autocorrectionDisabled(true)
                    .onChange(of: address) { _, newValue in
                        for proto in VolumeProtocolType.allCases {
                            if newValue.lowercased().hasPrefix(proto.scheme) {
                                selectedProtocol = proto
                                address = String(newValue.dropFirst(proto.scheme.count))
                                return
                            }
                        }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .name
            }
        }
    }
}

// MARK: - Add Volume View

struct AddVolumeView: View {
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    @State private var name = ""
    @State private var address = ""
    @State private var selectedProtocol: VolumeProtocolType = .smb

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
                selectedProtocol: $selectedProtocol,
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
        let fullAddress = selectedProtocol.scheme + address
        manager.addVolume(Volume(name: name, serverAddress: fullAddress))
        viewMode = .list
    }
}

// MARK: - Edit Volume View

struct EditVolumeView: View {
    let volume: Volume
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    @State private var name: String
    @State private var address: String
    @State private var selectedProtocol: VolumeProtocolType

    init(volume: Volume, manager: VolumeManager, viewMode: Binding<AppViewMode>) {
        self.volume = volume
        self.manager = manager
        self._viewMode = viewMode

        var proto = VolumeProtocolType.smb
        var addr = volume.serverAddress
        for p in VolumeProtocolType.allCases {
            if addr.lowercased().hasPrefix(p.scheme) {
                proto = p
                addr = String(addr.dropFirst(p.scheme.count))
                break
            }
        }
        self._name = State(initialValue: volume.name)
        self._address = State(initialValue: addr)
        self._selectedProtocol = State(initialValue: proto)
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
                selectedProtocol: $selectedProtocol,
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
        let fullAddress = selectedProtocol.scheme + address
        manager.editVolume(id: volume.id, name: name, serverAddress: fullAddress)
        viewMode = .list
    }
}
