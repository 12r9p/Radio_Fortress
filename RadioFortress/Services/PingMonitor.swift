import Foundation
import Combine

struct PingPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let rtt: Double // ms
}

// MARK: - Ping監視サービス
// /sbin/ping コマンドをバックグラウンドで実行し、
// 標準出力をパースしてRTTをリアルタイムに計測する。
// また、直近のRTT履歴からジッター（揺らぎ）を計算する。
final class PingMonitor: ObservableObject {
    @Published var history: [PingPoint] = []
    @Published var currentRTT: Double = 0
    @Published var jitter: Double = 0
    @Published var isRunning: Bool = false
    
    // 省電力モード（Ping停止）
    @Published var isLowPowerMode: Bool = false {
        didSet {
            if isLowPowerMode {
                stopPing()
            } else {
                startPing()
            }
        }
    }

    private var process: Process?
    private var pipe: Pipe?
    
    // グラフ表示用に保持する最大ポイント数（約60秒分）
    private let maxHistoryCount = 60
    
    // Ping先（Google Public DNS）
    private let targetHost = "8.8.8.8"

    init() {
        if !isLowPowerMode {
            startPing()
        }
    }

    func startPing() {
        guard !isRunning, !isLowPowerMode else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        // -i 1.0: 1秒間隔
        // --apple-time: タイムスタンプ付与（解析用）
        process.arguments = ["-i", "1.0", targetHost]

        let pipe = Pipe()
        process.standardOutput = pipe
        self.pipe = pipe
        self.process = process

        // バックグラウンドスレッドで出力を読み取る
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                self?.parseOutput(output)
            }
        }

        do {
            try process.run()
            isRunning = true
        } catch {
            print("Failed to start ping: \(error)")
            isRunning = false
        }
    }

    func stopPing() {
        process?.terminate()
        pipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        pipe = nil
        isRunning = false
    }

    private func parseOutput(_ output: String) {
        // Ping出力例:
        // 64 bytes from 8.8.8.8: icmp_seq=0 ttl=118 time=12.345 ms
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if let range = line.range(of: "time=") {
                let afterTime = line[range.upperBound...]
                let components = afterTime.components(separatedBy: " ")
                if let rttString = components.first, let rtt = Double(rttString) {
                    DispatchQueue.main.async {
                        self.updateMetrics(rtt: rtt)
                    }
                }
            }
        }
    }

    private func updateMetrics(rtt: Double) {
        currentRTT = rtt
        let point = PingPoint(timestamp: Date(), rtt: rtt)
        history.append(point)

        if history.count > maxHistoryCount {
            history.removeFirst()
        }

        calculateJitter()
    }

    // ジッター計算: RFC 1889 (RTP) に準拠したスムージングアルゴリズムの簡易版
    // または単純に「隣接するパケット間のRTT差分の平均」を採用。
    // ここでは直感的な「直近10件のRTTの標準偏差」を採用する。
    private func calculateJitter() {
        let recentPoints = history.suffix(10)
        guard recentPoints.count > 1 else {
            jitter = 0
            return
        }

        let rtts = recentPoints.map { $0.rtt }
        let mean = rtts.reduce(0, +) / Double(rtts.count)
        let variance = rtts.map { pow($0 - mean, 2) }.reduce(0, +) / Double(rtts.count)
        jitter = sqrt(variance)
    }

    deinit {
        stopPing()
    }
}
