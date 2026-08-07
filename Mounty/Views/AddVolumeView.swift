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
        case smb = "SMB"
        case afp = "AFP"
        case nfs = "NFS"
        case ftp = "FTP"
        var id: String { self.rawValue }
        var scheme: String { self.rawValue.lowercased() + "://" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                title: "Add New Volume",
                backAction: {
                    focusedField = nil
                    withAnimation { viewMode = .list }
                }
            )

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                TextField("Display Name (e.g. 'Work Drive')", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .address }

                Picker("Protocol", selection: $selectedProtocol) {
                    ForEach(ProtocolType.allCases) { Text($0.rawValue).tag($0) }
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
                        .onSubmit { save() }
                        .autocorrectionDisabled(true)
                        .onChange(of: address) { _, newValue in
                            for proto in ProtocolType.allCases {
                                if newValue.lowercased().hasPrefix(proto.scheme) {
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
