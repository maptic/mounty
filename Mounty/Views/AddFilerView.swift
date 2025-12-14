import SwiftUI

struct AddFilerView: View {
    @ObservedObject var manager: FilerManager
    @Binding var viewMode: AppViewMode
    
    @State private var name = ""
    @State private var address = "smb://"
    @FocusState private var focusedField: Field?
    enum Field { case name, address }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button { viewMode = .list } label: {
                HStack { Image(systemName: "chevron.left"); Text("Back") }
            }
            .buttonStyle(.plain).foregroundColor(.secondary)
            
            Text("Add New Filer").font(.title3).fontWeight(.bold)
            
            VStack(spacing: 15) {
                TextField("Display Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .address }
                
                TextField("Server (smb://server/share)", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .address)
                    .submitLabel(.done)
                    .onSubmit { save() }
                    .autocorrectionDisabled(true)
            }
            Spacer()
            HStack {
                Spacer()
                Button("Add Filer") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || address.count < 6)
            }
        }
        .padding(20).onAppear { focusedField = .name }
    }
    
    private func save() {
        guard !name.isEmpty, address.count >= 6 else { return }
        manager.addFiler(Filer(name: name, serverAddress: address))
        viewMode = .list
    }
}
