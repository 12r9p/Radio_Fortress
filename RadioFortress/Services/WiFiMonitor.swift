import Foundation
import CoreWLAN
import CoreLocation
import Combine

// MARK: - WiFiモニタリングサービス
// CoreWLANを使ってWiFi接続状態を定期的にポーリングし、
// SwiftUIのビューにリアクティブに公開する。
//
// macOS 10.15以降、CoreWLANでSSID/BSSIDを取得するには
// CoreLocationの位置情報権限（WhenInUse）が必須。
// このクラスはアプリ起動時に権限を要求し、許可後にWiFi情報を完全取得する。
final class WiFiMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var state = WiFiState()
    @Published var locationAuthorized = false

    private var timer: Timer?
    private let client = CWWiFiClient.shared()
    private let locationManager = CLLocationManager()
    private let pollingInterval: TimeInterval = 1.0

    override init() {
        super.init()
        locationManager.delegate = self
        requestLocationAuthorization()
        startMonitoring()
    }

    // MARK: - CoreLocation 権限要求

    private func requestLocationAuthorization() {
        // macOSではCLLocationManagerに対してrequestAlwaysAuthorizationを呼ぶと
        // システムダイアログが表示される。Info.plistにNSLocationWhenInUseUsageDescriptionが必要。
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            // macOSでは requestAlwaysAuthorization を使う
            // (requestWhenInUseAuthorization は iOS専用)
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorized:
            locationAuthorized = true
        default:
            locationAuthorized = false
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        locationAuthorized = (status == .authorizedAlways || status == .authorized)
        // 権限状態が変わったら即座にWiFi情報を更新
        updateState()
    }

    // MARK: - モニタリング制御

    func startMonitoring() {
        updateState()
        timer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.updateState()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - WiFi状態更新

    private func updateState() {
        guard let interface = client.interface() else {
            state.isConnected = false
            state.ssid = "WiFiインターフェース未検出"
            return
        }

        // 接続判定: RSSI と TxRate で判定する
        // SSIDはLocation権限がないとnilになるため、接続判定に使ってはいけない。
        // rssiValue() は未接続時に0を返し、接続時は-30〜-100程度の負の値を返す。
        let rssi = interface.rssiValue()
        let txRate = interface.transmitRate()
        let isAssociated = rssi != 0 && txRate > 0

        guard isAssociated else {
            state.isConnected = false
            state.ssid = "未接続"
            return
        }

        state.isConnected = true
        state.rssi = rssi
        state.noise = interface.noiseMeasurement()
        state.txRate = txRate

        // SSIDはLocation権限が必要。権限がない場合はその旨を表示。
        if let ssid = interface.ssid(), !ssid.isEmpty {
            state.ssid = ssid
        } else if !locationAuthorized {
            state.ssid = "📍 位置情報の許可が必要"
        } else {
            state.ssid = "Hidden Network"
        }

        state.bssid = interface.bssid() ?? "--"

        if let channel = interface.wlanChannel() {
            state.channelNumber = channel.channelNumber
            state.channelBand = channelBandString(channel.channelBand)
        }

        // CoreWLAN APIにはMCSインデックスの直接取得メソッドがないため、
        // TxRateとチャンネル帯域幅から推定する。
        // この推定は正確ではないが、ビジュアル表現としては十分な精度。
        state.mcsIndex = estimateMCSIndex(
            txRate: state.txRate,
            channelBand: state.channelBand
        )
    }

    // TxRateから変調方式を推定するヒューリスティック
    // Wi-Fi 6 (802.11ax) のレート表を基に、おおよそのMCSインデックスをマッピング。
    // 実際のMCSはストリーム数・GI長・帯域幅で大きく変わるため、あくまで近似値。
    private func estimateMCSIndex(txRate: Double, channelBand: String) -> Int {
        // 5GHz 80MHz帯域を基準にしたざっくりとした推定
        // 実際のレートは帯域幅・空間ストリーム数で大きく異なるため、
        // 変調方式の「雰囲気」を出すための簡易マッピング
        switch txRate {
        case ..<10:     return 0   // BPSK 1/2
        case 10..<20:   return 1   // QPSK 1/2
        case 20..<40:   return 2   // QPSK 3/4
        case 40..<60:   return 3   // 16-QAM 1/2
        case 60..<90:   return 4   // 16-QAM 3/4
        case 90..<135:  return 5   // 64-QAM 2/3
        case 135..<175: return 6   // 64-QAM 3/4
        case 175..<250: return 7   // 64-QAM 5/6
        case 250..<400: return 8   // 256-QAM 3/4
        case 400..<600: return 9   // 256-QAM 5/6
        default:        return 10  // 1024-QAM
        }
    }

    private func channelBandString(_ band: CWChannelBand) -> String {
        switch band {
        case .band2GHz:      return "2.4 GHz"
        case .band5GHz:      return "5 GHz"
        case .band6GHz:      return "6 GHz"
        case .bandUnknown:   return "Unknown"
        @unknown default:    return "Unknown"
        }
    }

    deinit {
        stopMonitoring()
    }
}
