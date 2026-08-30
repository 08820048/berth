import SwiftUI

struct FrameworkIcon: View {
    let name: String
    var size: CGFloat = 13

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.86, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var symbol: String {
        let key = name.lowercased()
        switch true {
        case key.contains("next"): return "square.dashed"
        case key.contains("vite"): return "bolt.fill"
        case key.contains("nuxt"): return "n.square"
        case key.contains("nest"): return "server.rack"
        case key.contains("express"), key.contains("node"): return "chevron.left.forwardslash.chevron.right"
        case key.contains("django"), key.contains("flask"), key.contains("python"): return "circle.hexagongrid"
        case key.contains("fast"): return "hare"
        case key.contains("rails"), key.contains("ruby"): return "diamond.fill"
        case key.contains("spring"): return "leaf"
        case key.contains("postgres"): return "cylinder"
        case key.contains("redis"): return "cylinder.split.1x2"
        case key.contains("mongo"): return "leaf.circle"
        case key.contains("docker"), key.contains("orbstack"), key.contains("colima"): return "shippingbox"
        default: return "server.rack"
        }
    }
}
