import SwiftUI

struct AddFilerView: View {
    @ObservedObject var manager: FilerManager
    @Binding var viewMode: AppViewMode
    
    @State private var name = ""
    @State private var address = "smb://"
    
    @FocusState private var focusedField: Field?
    enum Field { case name, address }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Add New Filer").font(.headline).padding(.top, 5)
            
            VStack(spacing: 12) {
                TextField("Display Name (e.g. Work)", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .address }
                
                TextField("Server (smb://server/share)", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .address)
                    .submitLabel(.done)
                    .onSubmit { addFiler() }
                    .autocorrectionDisabled(true)
            }
            Spacer()
            
            HStack {
                Button("Cancel") { viewMode = .list }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { addFiler() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || address.count < 7)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            focusedField = .name
        }
    }
    
    private func addFiler() {
        guard !name.isEmpty, address.count >= 7 else { return }
        let newFiler = Filer(name: name, serverAddress: address)
        manager.addFiler(newFiler)
        viewMode = .list
    }
}
