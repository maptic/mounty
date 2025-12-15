import SwiftUI

struct AddVolumeView: View {
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    @State private var name = ""
    @State private var address = ""
    @State private var selectedProtocol: ProtocolType = .smb
    @FocusState private var focusedField: Field?

    enum Field { case name, address }
    enum ProtocolType: String, CaseIterable, Identifiable {
        // Raw value is for the Picker's display text
        case smb = "SMB"
        case afp = "AFP"
        case nfs = "NFS"
        case ftp = "FTP"
        var id: String { self.rawValue }

        // Scheme is the functional prefix for the server address
        var scheme: String {
            return self.rawValue.lowercased() + "://"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // --- HEADER ---
            HStack {
                // Leading Item
                Button {
                    focusedField = nil
                    withAnimation { viewMode = .list }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundColor(.accentColor)
                .frame(width: 24, alignment: .leading)

                Spacer()

                // Center Item
                Text("Add New Volume").font(.headline)

                Spacer()

                // Trailing Item (for balance)
                Spacer().frame(width: 24)
            }
            .padding(12).background(.regularMaterial)

            Divider()

            // --- FORM CONTENT ---
            VStack(alignment: .leading, spacing: 18) {
                // Display Name
                TextField("Display Name (e.g. 'Work Drive')", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .address }

                // Protocol Selector
                Picker("Protocol", selection: $selectedProtocol) {
                    ForEach(ProtocolType.allCases) { proto in
                        Text(proto.rawValue).tag(proto)
                    }
                }
                .pickerStyle(.segmented)

                // Server Address Input (Custom Style)
                // This container is styled to exactly match the look of a .roundedBorder TextField,
                // while allowing a non-editable prefix to be displayed inside.
                HStack(spacing: 4) {
                    // The protocol prefix, styled like placeholder text
                    Text(selectedProtocol.scheme)
                        .font(.body)
                        .foregroundColor(.secondary)

                    // The actual text input field, with a plain style to remove its own border
                    TextField("server/share", text: $address)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .address)
                        .submitLabel(.done)
                        .onSubmit { save() }
                        .autocorrectionDisabled(true)
                        .onChange(of: address) { _, newValue in
                            for proto in ProtocolType.allCases {
                                if newValue.lowercased().hasPrefix(proto.scheme)
                                {
                                    selectedProtocol = proto
                                    address = String(
                                        newValue.dropFirst(proto.scheme.count)
                                    )
                                    return
                                }
                            }
                        }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(20)

            Spacer()

            // --- FOOTER ---
            HStack {
                Spacer()
                Button("Add Volume") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || address.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .name
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        guard !name.isEmpty, !address.isEmpty else { return }
        focusedField = nil

        let fullAddress = selectedProtocol.scheme + address
        manager.addVolume(Volume(name: name, serverAddress: fullAddress))
        viewMode = .list
    }
}
