import SwiftUI
import AppKit

// MARK: - App Delegate
// MenuBarExtraの代わりにNSStatusItemを直接管理し、
// 左クリック（ポップオーバー）と右クリック（メニュー）の振り分けを実現する。
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    // アプリケーション全体で共有する状態
    let wifiMonitor = WiFiMonitor()
    let pingMonitor = PingMonitor()
    let voiceService = VoiceKeepingService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // 初期アイコン（透明なplaceholder）
            button.image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in true }
            button.action = #selector(handleStatusBarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        
        // WiFiMonitorの状態監視を開始し、アイコンを更新
        // Combineの購読が必要だが、簡易的にWiFiMonitor側でNotificationCenterを飛ばすか、
        // あるいはここからTimerで監視するか。
        // シンプルにTimerで再描画を回す（RadioFortressAppと同じアプローチ）
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateIcon()
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 500) // 高さを少し拡張（グラフ用）
        popover.behavior = .transient
        popover.animates = true
        
        let contentView = DetailPopover(
            wifiMonitor: wifiMonitor,
            pingMonitor: pingMonitor,
            voiceService: voiceService
        )
        
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        button.image = MenuBarIconRenderer.renderIcon(for: wifiMonitor.state)
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // 右クリック：メニュー表示
            showContextMenu(sender)
        } else {
            // 左クリック：ポップオーバー表示/非表示
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            // ポップオーバー表示時は最前面に
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        // Voice Mode Toggle
        let voiceItem = NSMenuItem(
            title: "Voice Priority Mode",
            action: #selector(toggleVoiceMode),
            keyEquivalent: ""
        )
        voiceItem.state = voiceService.isEnabled ? .on : .off
        voiceItem.target = self
        menu.addItem(voiceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit Radio Fortress",
            action: #selector(terminateApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil) // メニューを強制表示
        statusItem?.menu = nil // 次回クリック時のために解除（左クリック判定を邪魔しないため）
    }
    
    @objc private func toggleVoiceMode() {
        voiceService.isEnabled.toggle()
    }

    @objc private func terminateApp() {
        NSApp.terminate(nil)
    }
}
