import SwiftUI

/// A standardized, reusable header view for the application.
/// Ensures consistent height, padding, and alignment across all main views.
struct HeaderView: View {
    let title: String

    // Configuration
    var showLogo: Bool = false
    var backAction: (() -> Void)? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: (String, Color)? = nil
    var trailingHelp: String = ""

    var body: some View {
        HStack {
            // MARK: - Leading Item (Back Button OR Logo)
            ZStack(alignment: .leading) {
                if let backAction = backAction {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundColor(.accentColor)
                } else if showLogo {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(4)
                }
            }
            .frame(width: 28, height: 28, alignment: .leading)

            Spacer()

            // MARK: - Center Item (Title)
            Text(title)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                // Prevents layout jitter during transitions
                .frame(minWidth: 100)

            Spacer()

            // MARK: - Trailing Item (Settings/Quit/Empty)
            ZStack(alignment: .trailing) {
                if let action = trailingAction, let icon = trailingIcon {
                    Button(action: action) {
                        Image(systemName: icon.0)
                            .font(.system(size: 16))
                            .foregroundColor(icon.1)
                    }
                    .buttonStyle(.plain)
                    .help(trailingHelp)
                }
            }
            .frame(width: 28, height: 28, alignment: .trailing)
        }
        .padding(12)
        .background(.regularMaterial)
    }
}
