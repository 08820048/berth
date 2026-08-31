import SwiftUI

enum BerthLayout {
    static let panelWidth: CGFloat = 380
    static let settingsWidth: CGFloat = 320
    static let rowHeight: CGFloat = 47
    static let groupHeaderHeight: CGFloat = 27
    // Keep the native menu-bar card compact while project cards stay collapsed by default.
    static let maxListHeight: CGFloat = 500
    static let minListHeight: CGFloat = 360
    static let emptyListHeight: CGFloat = 88
    static let headerHeight: CGFloat = 36
    static let searchHeight: CGFloat = 34
    static let footerRowHeight: CGFloat = 36
    // 让设置面板在常见内容量下（中英文）无需滚动即可完整展示。
    static let settingsMinHeight: CGFloat = 768

}

struct QuietIconButtonStyle: ButtonStyle {
    var color: Color = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct MenuHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

enum PathDisplay {
    static func compact(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
