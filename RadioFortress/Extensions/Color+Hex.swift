import SwiftUI

extension Color {
    // 16進数カラーコードからColorを生成するイニシャライザ
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - コンスタレーション表示用カラーパレット (Semantic Colors)
// ライト/ダークモードに対応したセマンティックカラー定義
enum ConstellationColors {
    // 背景は親ViewのMaterialに任せるためClearに
    static var background: Color { .clear }
    
    // グリッド線: 現在のモードのprimaryカラーを薄く使う
    static var gridLine: Color { .primary.opacity(0.15) }
    static var axisLine: Color { .blue.opacity(0.5) }
    static var centerMark: Color { .blue.opacity(0.7) }

    // 信号品質に応じたポイントカラー（視認性重視で調整）
    static let excellent     = Color.green
    static let good          = Color.cyan
    static let fair          = Color.orange
    static let poor          = Color.red

    // Glow（発光）用カラー
    static let glowExcellent = Color.green.opacity(0.4)
    static let glowGood      = Color.cyan.opacity(0.4)
    static let glowFair      = Color.orange.opacity(0.3)
    static let glowPoor      = Color.red.opacity(0.3)

    // テキストカラー
    static var labelText: Color { .secondary }
    static var infoText: Color { .secondary }
    static var valueText: Color { .primary }

    static func pointColor(for quality: QualityLevel) -> Color {
        switch quality {
        case .excellent: return excellent
        case .good:      return good
        case .fair:      return fair
        case .poor:      return poor
        }
    }

    static func glowColor(for quality: QualityLevel) -> Color {
        switch quality {
        case .excellent: return glowExcellent
        case .good:      return glowGood
        case .fair:      return glowFair
        case .poor:      return glowPoor
        }
    }
}
