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
        case smb = "smb://"
        case afp = "afp://"
        case nfs = "nfs://"
        case ftp = "ftp://"
        var id: String { self.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Replicated from SettingsView
            HStack {
                Button {
                    withAnimation { viewMode = .list }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain).foregroundColor(.accentColor)

                Spacer()
                Text("Add New Volume").font(.headline)
                Spacer()

                // Invisible spacer to balance the header title
                Text("Back").hidden()
            }
            .padding(12).background(.regularMaterial)

            Divider()

            // Form Content
            VStack(spacing: 15) {
                TextField("Display Name (e.g. 'Work Drive')", text: $name)
                    .textFieldStyle(.roundedBorder).focused(
                        $focusedField,
                        equals: .name
                    )
                    .submitLabel(.next).onSubmit { focusedField = .address }

                HStack {
                    Picker("Protocol", selection: $selectedProtocol) {
                        ForEach(ProtocolType.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden()

                    TextField("server/share", text: $address)
                        .textFieldStyle(.roundedBorder).focused(
                            $focusedField,
                            equals: .address
                        )
                        .submitLabel(.done).onSubmit { save() }
                        .autocorrectionDisabled(true)
                        .onChange(of: address) { _, newValue in
                            for proto in ProtocolType.allCases {
                                if newValue.lowercased().hasPrefix(
                                    proto.rawValue
                                ) {
                                    selectedProtocol = proto
                                    address = String(
                                        newValue.dropFirst(proto.rawValue.count)
                                    )
                                    return
                                }
                            }
                        }
                }
            }
            .padding(20)

            Spacer()

            // Footer Action
            HStack {
                Spacer()
                Button("Add Volume") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || address.isEmpty)
                    .keyboardShortcut(.defaultAction)  // Allow hitting Enter to save
            }
            .padding(20)
        }
        .onAppear {
            // Slight delay to allow view to transition before focusing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .name
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        guard !name.isEmpty, !address.isEmpty else { return }
        let fullAddress = selectedProtocol.rawValue + address
        manager.addVolume(Volume(name: name, serverAddress: fullAddress))
        viewMode = .list
    }
}
