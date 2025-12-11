import SwiftUI

struct AddFilerView: View {
    @ObservedObject var manager: FilerManager
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var address = "smb://"
    @State private var mountPoint = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add New Filer")
                .font(.headline)
            
            Form {
                TextField("Display Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Address (smb://...)", text: $address)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Mount Name (Folder in /Volumes)", text: $mountPoint)
                    .textFieldStyle(.roundedBorder)
                
                Text("The mount name usually matches the share name.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Cancel") { isPresented = false }
                Spacer()
                Button("Add") {
                    let newFiler = Filer(
                        name: name,
                        serverAddress: address,
                        mountPoint: mountPoint
                    )
                    manager.addFiler(newFiler)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || address.count < 7 || mountPoint.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }
}