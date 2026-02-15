import SwiftUI

struct ConstellationView: View {
    let wifiState: WiFiState
    var showLabels: Bool = false
    
    // アニメーション用のタイムライン
    // .animationモード: 常に再描画して明滅させる
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // 1. 座標計算の準備
                let width = size.width
                let height = size.height
                let centerX = width / 2
                let centerY = height / 2
                // 描画領域のスケール（余白を持たせる）
                let scale = min(width, height) * 0.4
                
                // 2. 背景・グリッド・軸の描画
                drawGrid(context: context, size: size, center: CGPoint(x: centerX, y: centerY), scale: scale)
                
                // 3. コンスタレーション点（シンボル）の描画
                drawConstellationPoints(
                    context: context,
                    size: size,
                    center: CGPoint(x: centerX, y: centerY),
                    scale: scale,
                    time: time
                )
            }
        }
        .background(ConstellationColors.background) // Clear
        // 外枠は親View（DetailPopover）側で制御するが、
        // ここでも最低限のクリッピング等はしておくと良い
        .contentShape(Rectangle())
    }
    
    // MARK: - Drawing Logic
    
    private func drawGrid(context: GraphicsContext, size: CGSize, center: CGPoint, scale: CGFloat) {
        // 十字軸（Center Axis）を強調
        // グリッド全体をカバーする長さ
        let axisPath = Path { path in
            // X軸
            path.move(to: CGPoint(x: center.x - scale, y: center.y))
            path.addLine(to: CGPoint(x: center.x + scale, y: center.y))
            // Y軸
            path.move(to: CGPoint(x: center.x, y: center.y - scale))
            path.addLine(to: CGPoint(x: center.x, y: center.y + scale))
        }
        // 軸は少し目立たせる
        context.stroke(axisPath, with: .color(ConstellationColors.axisLine), lineWidth: 1.5)
        
        // 外枠（矩形）を描いて範囲を明確にする
        let borderPath = Path(CGRect(
            x: center.x - scale,
            y: center.y - scale,
            width: scale * 2,
            height: scale * 2
        ))
        context.stroke(borderPath, with: .color(ConstellationColors.gridLine), lineWidth: 1)
    }
    
    private func drawConstellationPoints(
        context: GraphicsContext,
        size: CGSize,
        center: CGPoint,
        scale: CGFloat,
        time: TimeInterval
    ) {
        let modType = wifiState.modulationType
        let cols = modType.gridColumns
        let rows = modType.gridRows
        
        let stepX = 2.0 / Double(max(cols, 1))
        let stepY = 2.0 / Double(max(rows, 1))
        
        let offsetX = -1.0 + (stepX / 2.0)
        let offsetY = -1.0 + (stepY / 2.0)
        
        let baseColor = ConstellationColors.pointColor(for: wifiState.qualityLevel)
        let glowColor = ConstellationColors.glowColor(for: wifiState.qualityLevel)
        
        let txRate = wifiState.txRate
        // BPSKのような1行/1列の場合の調整のため、最大次元でスケーリング
        // これにより、点が画面いっぱいに広がりすぎないようにする
        let maxDim = max(cols, rows)
        let drawScale = scale * (Double(maxDim) / Double(ModulationType.qam1024.gridColumns)) * 3.5
        
        for c in 0..<cols {
            for r in 0..<rows {
                let normX = (Double(c) * stepX) + offsetX
                let normY = rows > 1 ? (Double(r) * stepY) + offsetY : 0.0
                
                let spreadFactor: CGFloat = cols <= 4 ? 0.5 : 0.9
                
                let x = center.x + CGFloat(normX) * drawScale * spreadFactor
                let y = center.y + CGFloat(normY) * drawScale * spreadFactor
                
                // Firefly Animation Logic (Disabled by User Request)
                // 静的な描画に変更。常時点灯。
                
                // 通信品質に応じたベース透明度
                // excellentならくっきり(0.8), poorなら薄く(0.4)など
                var alpha: Double = 0.6
                
                // TxRateが高いときは少し明るくする（動的なフィードバックの代わり）
                if txRate > 100 {
                    alpha += min(txRate / 2000.0, 0.3)
                }

                let pointRect = CGRect(
                    x: x - 2.5,
                    y: y - 2.5,
                    width: 5,
                    height: 5
                )
                
                // Glowは常にうっすらと
                if alpha > 0.7 {
                    context.fill(
                        Circle().path(in: pointRect.insetBy(dx: -3, dy: -3)),
                        with: .color(glowColor.opacity(alpha * 0.3))
                    )
                }
                
                context.fill(
                    Circle().path(in: pointRect),
                    with: .color(baseColor.opacity(alpha))
                )
            }
        }
        
        // ラベル表示（デバッグ用、または詳細表示用）
        if showLabels {
            drawModulationLabel(context: context, size: size)
        }
    }
    
    private func drawModulationLabel(context: GraphicsContext, size: CGSize) {
        let text = Text(wifiState.modulationType.rawValue)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(ConstellationColors.labelText)
        
        context.draw(text, at: CGPoint(x: size.width - 40, y: size.height - 20))
    }
}
