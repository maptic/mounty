import SwiftUI

struct AddVolumeView: View {
    @ObservedObject var manager: FilerManager
    @Binding var viewMode: AppViewMode
    
    @State private var name = ""
    @State private var address = ""
    @State private var selectedProtocol: ProtocolType = .smb
    @FocusState private var focusedField: Field?
    
    enum Field { case name, address }
    enum ProtocolType: String, CaseIterable {
        case smb = "smb://"
        case afp = "afp://"
        case nfs = "nfs://"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button { viewMode = .list } label: {
                HStack { Image(systemName: "chevron.left"); Text("Back") }
            }
            .buttonStyle(.plain).foregroundColor(.secondary)
            
            Text("Add New Volume").font(.title3).fontWeight(.bold)
            
            VStack(spacing: 15) {
                TextField("Display Name", text: $name)
                    .textFieldStyle(.roundedBorder).focused($focusedField, equals: .name)
                    .submitLabel(.next).onSubmit { focusedField = .address }
                
                HStack {
                    Picker("", selection: $selectedProtocol) {
                        ForEach(ProtocolType.allCases, id: \.self) { proto in
                            Text(proto.rawValue).tag(proto)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    
                    TextField("server/share", text: $address)
                        .textFieldStyle(.roundedBorder).focused($focusedField, equals: .address)
                        .submitLabel(.done).onSubmit { save() }
                        .autocorrectionDisabled(true)
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button("Add Volume") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || address.isEmpty)
            }
        }
        .padding(20).onAppear { focusedField = .name }
    }
    
    private func save() {
        guard !name.isEmpty, !address.isEmpty else { return }
        let fullAddress = selectedProtocol.rawValue + address
        manager.addVolume(Volume(name: name, serverAddress: fullAddress))
        viewMode = .list
    }
}