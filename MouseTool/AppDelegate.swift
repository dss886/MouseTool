import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let gestureController = MouseGestureController()
    private var permissionTimer: Timer?
    private var lastTrustedState = AccessibilityPermission.isTrusted

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        rebuildMenu()
        startPermissionTimer()

        if AccessibilityPermission.isTrusted {
            gestureController.start()
        } else {
            AccessibilityPermission.request()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        gestureController.stop()
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

        if trusted != lastTrustedState {
            lastTrustedState = trusted
            rebuildMenu()
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let stateTitle: String
        if !AccessibilityPermission.isTrusted {
            stateTitle = "需要辅助功能权限"
        } else if gestureController.isRunning {
            stateTitle = "右键拖动切换：开启"
        } else {
            stateTitle = "右键拖动切换：关闭"
        }

        let stateItem = NSMenuItem(title: stateTitle, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let toggleTitle = gestureController.isEnabled ? "停用" : "启用"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = AccessibilityPermission.isTrusted
        menu.addItem(toggleItem)

        let permissionItem = NSMenuItem(title: "打开辅助功能设置", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        let restartItem = NSMenuItem(title: "重启事件监听", action: #selector(restartEventTap), keyEquivalent: "")
        restartItem.target = self
        restartItem.isEnabled = AccessibilityPermission.isTrusted
        menu.addItem(restartItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 MouseTool", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
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

    @objc private func openAccessibilitySettings() {
        AccessibilityPermission.openSettings()
        AccessibilityPermission.request()
        refreshPermissionState()
        rebuildMenu()
    }

    @objc private func restartEventTap() {
        gestureController.stop()
        if AccessibilityPermission.isTrusted {
            gestureController.start()
        } else {
            AccessibilityPermission.request()
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
