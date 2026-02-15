import Foundation

// MARK: - 変調方式の定義
// MCSインデックスから推定される変調タイプ。
// 実際の無線通信ではBPSK〜1024-QAMまで使い分けられるが、
// CoreWLAN APIからは直接取得できないため、TxRate / channelBandwidthから推定する。
enum ModulationType: String, CaseIterable, Equatable {
    case bpsk    = "BPSK"
    case qpsk    = "QPSK"
    case qam16   = "16-QAM"
    case qam64   = "64-QAM"
    case qam256  = "256-QAM"
    case qam1024 = "1024-QAM"

    var pointCount: Int {
        switch self {
        case .bpsk:    return 2
        case .qpsk:    return 4
        case .qam16:   return 16
        case .qam64:   return 64
        case .qam256:  return 256
        case .qam1024: return 1024
        }
    }

    // QAMグリッドの一辺の長さ（BPSKのみ1x2の例外配置）
    var gridColumns: Int {
        switch self {
        case .bpsk:    return 2
        case .qpsk:    return 2
        case .qam16:   return 4
        case .qam64:   return 8
        case .qam256:  return 16
        case .qam1024: return 32
        }
    }

    var gridRows: Int {
        switch self {
        case .bpsk:    return 1
        case .qpsk:    return 2
        case .qam16:   return 4
        case .qam64:   return 8
        case .qam256:  return 16
        case .qam1024: return 32
        }
    }

    // MCSインデックスから変調方式を推定するマッピング
    // Wi-Fi 6(802.11ax)のHT/VHT/HE MCSテーブルに準拠
    static func from(mcsIndex: Int) -> ModulationType {
        switch mcsIndex {
        case 0:        return .bpsk
        case 1...2:    return .qpsk
        case 3...4:    return .qam16
        case 5...7:    return .qam64
        case 8...9:    return .qam256
        default:       return .qam1024
        }
    }
}

// MARK: - WiFi状態モデル
struct WiFiState: Equatable {
    var ssid: String = "未接続"
    var bssid: String = "--"
    var rssi: Int = -100
    var noise: Int = -100
    var mcsIndex: Int = 0
    var txRate: Double = 0
    var channelNumber: Int = 0
    var channelBand: String = "--"
    var isConnected: Bool = false

    // Signal-to-Noise Ratio：電波品質の核心指標
    // rssiとnoiseの差分で、値が大きいほど通信品質が良い
    var snr: Double {
        guard isConnected else { return 0 }
        return max(Double(rssi - noise), 1)
    }

    var modulationType: ModulationType {
        ModulationType.from(mcsIndex: mcsIndex)
    }

    // SNRに基づく品質レベル（UIカラー選択等に使用）
    var qualityLevel: QualityLevel {
        switch snr {
        case 30...:  return .excellent
        case 20..<30: return .good
        case 10..<20: return .fair
        default:      return .poor
        }
    }
}

enum QualityLevel {
    case excellent, good, fair, poor
}
