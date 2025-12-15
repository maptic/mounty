import SwiftUI

// MARK: - Status Alert Overlay
/// Displays success (Green) or error (Red) messages non-intrusively.
struct AlertOverlay: View {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    var isError: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 16) {
                Image(
                    systemName: isError
                        ? "exclamationmark.circle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.system(size: 32))
                .foregroundColor(isError ? .red : .green)

                Text(title).font(.headline)

                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("OK") { withAnimation { isPresented = false } }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .frame(width: 280)
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 10)
            .transition(.scale.combined(with: .opacity))
        }
        .zIndex(100)
    }
}

// MARK: - Confirmation Overlay
/// Modal for destructive actions (Quit, Reset).
struct ConfirmationOverlay: View {
    let title: String
    let message: String
    let confirmButtonText: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 16) {
                Text(title).font(.headline)
                Text(message).font(.caption).multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button("Cancel") { withAnimation { isPresented = false } }
                        .keyboardShortcut(.cancelAction)

                    Button(confirmButtonText) {
                        withAnimation { isPresented = false }
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 280)
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 10)
            .transition(.scale.combined(with: .opacity))
        }
        .zIndex(100)
    }
}

// MARK: - Input Overlay
/// Modal for text entry (e.g., Import Paths).
struct InputOverlay: View {
    let title: String
    let message: String
    let placeholder: String
    @Binding var inputText: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
                .onTapGesture {
                    isFocused = false
                    withAnimation { isPresented = false }
                }

            VStack(spacing: 16) {
                Text(title).font(.headline)
                Text(message).font(.caption).multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        isFocused = false
                        withAnimation { isPresented = false }
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Import") {
                        isFocused = false
                        withAnimation { isPresented = false }
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 280)
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 10)
            .transition(.scale.combined(with: .opacity))
        }
        .zIndex(100)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}
