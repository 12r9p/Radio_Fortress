import SwiftUI

// MARK: - Radio Fortress アプリケーション
// MenuBarExtra を廃止し、NSApplicationDelegateAdaptor を使用して
// AppDelegate でステータスバーアイテムを制御する方式に移行。
@main
struct RadioFortressApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // MenuBarExtraは使用しないため空のSettingsシーンのみ定義
        // (Appプロトコルに準拠するため何らかのSceneは必要だが、WindowGroup等は不要)
        Settings {
            EmptyView()
        }
    }
}
