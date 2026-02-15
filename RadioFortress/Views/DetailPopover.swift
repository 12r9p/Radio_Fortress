import SwiftUI
import Charts

// MARK: - ポップオーバー詳細ビュー
// メニューバーアイコンをクリックした際に表示されるウィンドウ。
// macOSネイティブのブラー（.ultraThinMaterial）をベースにした
// フロストガラス風デザインで、通信の「電波感」を演出する。
struct DetailPopover: View {
    @ObservedObject var wifiMonitor: WiFiMonitor
    @ObservedObject var pingMonitor: PingMonitor
    @ObservedObject var voiceService: VoiceKeepingService

    var body: some View {
        VStack(spacing: 0) {
            constellationSection
            dividerLine
            pingChartSection
            dividerLine
            infoSection
            dividerLine
            footerSection
        }
        .frame(width: 340, height: 500)
        .background(.ultraThinMaterial)
    }

    // MARK: - 区切り線

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }

    // MARK: - コンスタレーション表示エリア

    private var constellationSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("CONSTELLATION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Spacer()
                signalBadge
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            if wifiMonitor.state.isConnected {
                ConstellationView(
                    wifiState: wifiMonitor.state,
                    showLabels: true
                )
                .frame(height: 180) // 少し高さを詰める
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            } else {
                disconnectedView
                    .frame(height: 180)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Pingグラフセクション [NEW]

    private var pingChartSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("LATENCY (RTT)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Spacer()
                Text(String(format: "%.1f ms", pingMonitor.currentRTT))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ConstellationColors.pointColor(for: .good))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            
            // Pingグラフ
            Chart(pingMonitor.history) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("RTT", point.rtt)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ConstellationColors.excellent,
                            ConstellationColors.good.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("RTT", point.rtt)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ConstellationColors.excellent.opacity(0.2),
                            ConstellationColors.excellent.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: .automatic(includesZero: true))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color.white.opacity(0.1))
                    if let intValue = value.as(Int.self) {
                        AxisValueLabel("\(intValue)", centered: false)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    // MARK: - WiFi情報セクション

    private var infoSection: some View {
        VStack(spacing: 5) {
            infoRow(label: "SSID", value: wifiMonitor.state.ssid)
            
            HStack(spacing: 16) {
                infoRow(label: "RSSI", value: "\(wifiMonitor.state.rssi) dBm")
                infoRow(label: "Jitter", value: String(format: "%.1f ms", pingMonitor.jitter))
            }
            
            infoRow(
                label: "SNR",
                value: String(format: "%.1f dB", wifiMonitor.state.snr),
                highlight: true
            )
            
            HStack(spacing: 16) {
                infoRow(
                    label: "Modulation",
                    value: wifiMonitor.state.modulationType.rawValue,
                    highlight: true
                )
                infoRow(
                    label: "Channel",
                    value: "Ch.\(wifiMonitor.state.channelNumber)"
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - フッター（Voice Mode Switch）

    private var footerSection: some View {
        HStack {
            Toggle(isOn: $voiceService.isEnabled) {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(voiceService.isEnabled ? ConstellationColors.poor : .secondary)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Voice Priority Mode")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(voiceService.isEnabled ? .primary : .secondary)
                        Text(voiceService.isEnabled ? "Keeping Connection Active (QoS VO)" : "Standard Mode")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: ConstellationColors.poor)) // Voiceモードは赤系統で強調
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - サブコンポーネント

    private var signalBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(signalDotColor)
                .frame(width: 6, height: 6)
                // 接続中はパルスアニメーション
                .shadow(color: signalDotColor.opacity(0.6), radius: 3)
            Text(wifiMonitor.state.isConnected ? "LIVE" : "OFFLINE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(signalDotColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(signalDotColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private var signalDotColor: Color {
        guard wifiMonitor.state.isConnected else {
            return ConstellationColors.poor
        }
        return ConstellationColors.pointColor(for: wifiMonitor.state.qualityLevel)
    }

    private var disconnectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)

            if !wifiMonitor.locationAuthorized {
                // 位置情報権限がない場合の案内表示
                VStack(spacing: 6) {
                    Text("位置情報の許可が必要です")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("システム設定 → プライバシーとセキュリティ\n→ 位置情報サービスで許可してください")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("WiFi未接続")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func infoRow(
        label: String,
        value: String,
        highlight: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: highlight ? .bold : .regular, design: .monospaced))
                .foregroundColor(
                    highlight
                        ? ConstellationColors.pointColor(for: wifiMonitor.state.qualityLevel)
                        : .primary
                )
        }
    }
}
