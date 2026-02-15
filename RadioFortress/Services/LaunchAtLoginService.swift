import Foundation
import ServiceManagement
import Combine
import SwiftUI

/// アプリ起動時に自動的にログイン項目に追加するサービス
/// macOS 13.0以降のSMAppServiceを使用
final class LaunchAtLoginService: ObservableObject {
    static let shared = LaunchAtLoginService()
    
    @Published var isEnabled: Bool = false {
        didSet {
            guard oldValue != isEnabled else { return }
            updateService()
        }
    }
    
    private init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    private func updateService() {
        do {
            if isEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to update LaunchAtLogin status: \(error)")
            // 失敗した場合はUIを元に戻すなどの処理が必要だが、
            // ここではシンプルにログ出力のみとする
        }
    }
}
