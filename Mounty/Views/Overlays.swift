import SwiftUI

// MARK: - Icon Button Hover Style
// ButtonStyle is the correct mechanism: padding added inside makeBody becomes
// part of the button's own rendered frame, so the full padded area is the hit
// target. The old ViewModifier approach added padding *outside* the Button,
// leaving the hit area as only the small icon — causing missed clicks.
struct IconHoverButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 5
    var padding: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        IconHoverBody(
            configuration: configuration,
            cornerRadius: cornerRadius,
            padding: padding
        )
    }
}

private struct IconHoverBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let padding: CGFloat
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        (isHovered || configuration.isPressed)
                            ? Color.primary.opacity(0.08) : .clear
                    )
                    .animation(.easeOut(duration: 0.12), value: isHovered)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

extension View {
    // Callers must NOT also apply .buttonStyle(.plain) — that would take
    // precedence over this style and revert to a tiny hit area.
    func iconButtonHover(cornerRadius: CGFloat = 5, padding: CGFloat = 4) -> some View {
        buttonStyle(IconHoverButtonStyle(cornerRadius: cornerRadius, padding: padding))
    }

    func appFooterLayout() -> some View {
        frame(height: 24)
            .padding(12)
            .frame(maxWidth: .infinity)
    }
}

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
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 10)
            .transition(.scale.combined(with: .opacity))
        }
        .zIndex(100)
    }
}

// MARK: - Speed Test Result Overlay
struct SpeedTestOverlay: View {
    let volumeName: String
    let result: SpeedTestService.Result
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 16) {
                Image(systemName: "speedometer")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)

                Text(volumeName).font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        Label("Write", systemImage: "arrow.up.circle")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f MB/s", result.writeSpeed))
                            .fontWeight(.medium)
                            .gridColumnAlignment(.trailing)
                    }
                    GridRow {
                        Label("Read", systemImage: "arrow.down.circle")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f MB/s", result.readSpeed))
                            .fontWeight(.medium)
                            .gridColumnAlignment(.trailing)
                    }
                }
                .font(.callout)

                Text("Test size: \(String(format: "%.0f", result.fileSizeMB)) MB")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Done") { withAnimation { isPresented = false } }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)
            .frame(width: 280)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 10)
            .transition(.scale.combined(with: .opacity))
        }
        .zIndex(100)
    }
}
