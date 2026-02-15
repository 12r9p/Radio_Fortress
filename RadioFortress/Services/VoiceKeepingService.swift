import Foundation
import Network

// MARK: - Voice優先モード (QoS Keep Alive)
// 定期的にUDPパケットを送信し、そのパケットに "Voice" (AC_VO) のサービスクラスを設定する。
// これにより、無線チップおよび経路上でこの端末のフローがVoice優先度として扱われることを期待する。
// WMM (Wi-Fi Multimedia) 対応APであれば、これにより通信優先度が上がる可能性がある。
final class VoiceKeepingService: ObservableObject {
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startKeepAlive()
            } else {
                stopKeepAlive()
            }
        }
    }

    private var connection: NWConnection?
    private var timer: Timer?
    // 送信間隔: 200ms (50ms〜200ms程度がVoIPの実質的なパケット間隔)
    private let interval: TimeInterval = 0.2
    
    // 宛先: Google Public DNS (8.8.8.8) の53番(DNS)
    // 実際にはDNSクエリを送るわけではなくダミーデータを送るが、
    // 53番ポートは通りやすい。
    // もしくは単純にゲートウェイに投げても良いが、ここでは確実な外部IPを指定。
    private let host: NWEndpoint.Host = "8.8.8.8"
    private let port: NWEndpoint.Port = 53

    private func startKeepAlive() {
        stopKeepAlive()
        
        // Voiceサービスクラスを指定
        let parameters = NWParameters.udp
        parameters.serviceClass = .interactiveVoice
        
        connection = NWConnection(host: host, port: port, using: parameters)
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("VoiceKeeper: Ready (Voice QoS)")
            case .failed(let error):
                print("VoiceKeeper: Failed \(error)")
            default:
                break
            }
        }
        connection?.start(queue: .global())
        
        // 定期送信開始
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendKeepAlivePacket()
        }
    }

    private func stopKeepAlive() {
        timer?.invalidate()
        timer = nil
        connection?.cancel()
        connection = nil
    }

    private func sendKeepAlivePacket() {
        guard let connection = connection else { return }

        // ダミーペイロード (1バイト)
        let data = "V".data(using: .utf8)
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("VoiceKeeper send error: \(error)")
            }
        })
    }

    deinit {
        stopKeepAlive()
    }
}
