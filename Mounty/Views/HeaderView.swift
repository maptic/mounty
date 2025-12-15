import SwiftUI

struct HeaderView: View {
    let title: String

    var showLogo: Bool = false
    var backAction: (() -> Void)? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: (String, Color)? = nil
    var trailingHelp: String = ""

    var body: some View {
        HStack {
            // Leading
            ZStack(alignment: .leading) {
                if let backAction = backAction {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                } else if showLogo {
                    // Falls back to system icon if named asset missing
                    Image(
                        nsImage: NSImage(named: NSImage.applicationIconName)
                            ?? NSImage()
                    )
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(4)
                }
            }
            .frame(width: 28, height: 28, alignment: .leading)

            Spacer()

            // Center
            Text(title)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .frame(minWidth: 100)

            Spacer()

            // Trailing
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
