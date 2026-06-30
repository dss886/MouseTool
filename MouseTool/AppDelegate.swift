import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let gestureController = MouseGestureController()
    private let scrollReverserController = MouseScrollReverserController()
    private var permissionTimer: Timer?
    private var lastTrustedState = AccessibilityPermission.isTrusted

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        rebuildMenu()
        startPermissionTimer()

        if AccessibilityPermission.isTrusted {
            gestureController.start()
            scrollReverserController.start()
        } else {
            AccessibilityPermission.request()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        gestureController.stop()
        scrollReverserController.stop()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            let image = NSImage(named: "StatusMouse")
            image?.size = NSSize(width: 20, height: 20)
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "MouseTool"
        }
    }

    private func startPermissionTimer() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermissionState()
        }
    }

    private func refreshPermissionState() {
        let trusted = AccessibilityPermission.isTrusted
        if trusted, gestureController.isEnabled, !gestureController.isRunning {
            gestureController.start()
        }
        if trusted, scrollReverserController.isEnabled, !scrollReverserController.isRunning {
            scrollReverserController.start()
        }

        if trusted != lastTrustedState {
            lastTrustedState = trusted
            rebuildMenu()
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let gestureItem = NSMenuItem(title: gestureMenuTitle, action: #selector(toggleEnabled), keyEquivalent: "")
        gestureItem.target = self
        gestureItem.state = gestureController.isEnabled && AccessibilityPermission.isTrusted ? .on : .off
        gestureItem.isEnabled = AccessibilityPermission.isTrusted
        menu.addItem(gestureItem)
        
        let restartItem = NSMenuItem(title: restartMenuTitle, action: #selector(restartEventTap), keyEquivalent: "")
        restartItem.target = self
        restartItem.isEnabled = AccessibilityPermission.isTrusted
        menu.addItem(restartItem)
        
        let permissionItem = NSMenuItem(title: "打开辅助功能设置", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        menu.addItem(.separator())
        
        let scrollReverseItem = NSMenuItem(title: scrollReverseMenuTitle, action: #selector(toggleScrollReverse), keyEquivalent: "")
        scrollReverseItem.target = self
        scrollReverseItem.state = scrollReverserController.isEnabled && AccessibilityPermission.isTrusted ? .on : .off
        scrollReverseItem.isEnabled = AccessibilityPermission.isTrusted
        menu.addItem(scrollReverseItem)
        
        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(title: launchAtLoginMenuTitle, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 MouseTool", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private var gestureMenuTitle: String {
        AccessibilityPermission.isTrusted ? "启用右键快捷手势" : "启用右键快捷手势（需要辅助功能权限）"
    }

    private var scrollReverseMenuTitle: String {
        AccessibilityPermission.isTrusted ? "启用滚动垂直反转" : "启用滚动垂直反转（需要辅助功能权限）"
    }
    
    private var restartMenuTitle: String {
        AccessibilityPermission.isTrusted ? "重启事件监听" : "重启事件监听（需要辅助功能权限）"
    }

    private var launchAtLoginMenuTitle: String {
        if SMAppService.mainApp.status == .requiresApproval {
            return "启用开机自动启动（需批准）"
        }

        return "启用开机自动启动"
    }

    @objc private func toggleEnabled() {
        gestureController.isEnabled.toggle()
        if gestureController.isEnabled {
            gestureController.start()
        } else {
            gestureController.stop()
        }
        rebuildMenu()
    }

    @objc private func toggleScrollReverse() {
        scrollReverserController.isEnabled.toggle()
        if scrollReverserController.isEnabled {
            scrollReverserController.start()
        } else {
            scrollReverserController.stop()
        }
        rebuildMenu()
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermission.openSettings()
        AccessibilityPermission.request()
        refreshPermissionState()
        rebuildMenu()
    }

    @objc private func restartEventTap() {
        gestureController.stop()
        scrollReverserController.stop()
        if AccessibilityPermission.isTrusted {
            gestureController.start()
            scrollReverserController.start()
        } else {
            AccessibilityPermission.request()
        }
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(
                title: "无法更新开机自动启动",
                message: error.localizedDescription
            )
        }

        rebuildMenu()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
