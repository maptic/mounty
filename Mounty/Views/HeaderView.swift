import SwiftUI

struct HeaderView: View {
    let title: String

    var showLogo: Bool = false
    var backAction: (() -> Void)? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: (String, Color)? = nil
    var trailingHelp: String = ""
    // Optional second trailing button — rendered to the LEFT of the primary one.
    var trailingAction2: (() -> Void)? = nil
    var trailingIcon2: (String, Color)? = nil
    var trailingHelp2: String = ""
    var trailingShortcut2: KeyboardShortcut? = nil

    // When two trailing buttons are present, both sides widen to keep the title centered.
    private var sideWidth: CGFloat { trailingAction2 != nil ? 64 : 32 }

    var body: some View {
        HStack {
            // Leading
            ZStack(alignment: .leading) {
                if let backAction = backAction {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .iconButtonHover()
                } else if showLogo {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(4)
                }
            }
            .frame(width: sideWidth, height: 32, alignment: .leading)

            Spacer()

            // Center
            Text(title)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .frame(minWidth: 100)

            Spacer()

            // Trailing — second button (if any) sits to the left of the primary.
            HStack(spacing: 0) {
                if let action2 = trailingAction2, let icon2 = trailingIcon2 {
                    Button(action: action2) {
                        Image(systemName: icon2.0)
                            .font(.system(size: 15))
                            .foregroundColor(icon2.1)
                    }
                    .iconButtonHover()
                    .keyboardShortcut(trailingShortcut2)
                    .help(trailingHelp2)
                }
                if let action = trailingAction, let icon = trailingIcon {
                    Button(action: action) {
                        Image(systemName: icon.0)
                            .font(.system(size: 15))
                            .foregroundColor(icon.1)
                    }
                    .iconButtonHover()
                    .help(trailingHelp)
                }
            }
            .frame(width: sideWidth, height: 32, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
