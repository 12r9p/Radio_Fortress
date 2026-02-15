import SwiftUI
import AppKit

// MARK: - メニューバーアイコンレンダラー
// メニューバーの限られたスペース（約18×18pt）に
// 小さなコンスタレーション風のアイコンを動的に描画する。
// NSImageとして生成し、MenuBarExtraのlabelで使用。
final class MenuBarIconRenderer {

    // アイコンサイズはmacOSメニューバーの標準に合わせる
    static let iconSize = NSSize(width: 18, height: 18)

    // WiFiの現在状態からメニューバー用NSImageを生成
    static func renderIcon(for state: WiFiState) -> NSImage {
        let size = iconSize
        let image = NSImage(size: size, flipped: false) { rect in
            guard let cgContext = NSGraphicsContext.current?.cgContext else {
                return false
            }

            // 透明背景（テンプレートイメージとしてレンダリングされるため）
            cgContext.clear(rect)

            guard state.isConnected else {
                drawDisconnectedIcon(in: cgContext, rect: rect)
                return true
            }

            let modType = state.modulationType
            let quality = state.qualityLevel
            let margin: CGFloat = 2
            let plotRect = rect.insetBy(dx: margin, dy: margin)
            
            // メニューバーでは視認性重視のため、アニメーションはせず静的に表示
            // 変調モードに応じて点の密度を変える(BPSK=2x2, 16QAM=3x3, etc.)
            
            let displayCols: Int
            let displayRows: Int
            
            // ポイントカラー（ConstellationColorsの定義を使用）
            let baseColor: NSColor
            switch quality {
            case .excellent: baseColor = NSColor(ConstellationColors.excellent)
            case .good:      baseColor = NSColor(ConstellationColors.good)
            case .fair:      baseColor = NSColor(ConstellationColors.fair)
            case .poor:      baseColor = NSColor(ConstellationColors.poor)
            }
            
            switch modType {
            case .bpsk, .qpsk:
                displayCols = 2
                displayRows = 2
            case .qam16:
                displayCols = 3
                displayRows = 3
            case .qam64:
                displayCols = 4
                displayRows = 4
            default: // 256, 1024
                displayCols = 5
                displayRows = 5
            }
            
            // ドットサイズ調整
            let dotRadius: CGFloat = displayCols > 4 ? 0.9 : 1.2
            
            for col in 0..<displayCols {
                for row in 0..<displayRows {
                    let x = plotRect.minX + plotRect.width * (CGFloat(col) + 0.5) / CGFloat(displayCols)
                    let y = plotRect.minY + plotRect.height * (CGFloat(row) + 0.5) / CGFloat(displayRows)

                    let dotRect = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    
                    cgContext.setFillColor(baseColor.cgColor)
                    cgContext.fillEllipse(in: dotRect)
                }
            }

            return true
        }

        // テンプレートイメージとして設定しない（カスタムカラーを維持するため）
        image.isTemplate = false
        return image
    }

    private static func drawDisconnectedIcon(in context: CGContext, rect: CGRect) {
        let color = NSColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 0.6)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.5)

        // 斜線入りの円（WiFi OFF表現）
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 6
        context.strokeEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        // 斜線
        context.move(to: CGPoint(x: center.x - 4, y: center.y + 4))
        context.addLine(to: CGPoint(x: center.x + 4, y: center.y - 4))
        context.strokePath()
    }
}
