import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum DefaultsKey {
        static let gestureEnabled = "gestureEnabled"
        static let scrollReverseEnabled = "scrollReverseEnabled"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
    }

    private static let defaultsSuiteName = Bundle.main.bundleIdentifier ?? "com.dss886.MouseTool"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let gestureController = MouseGestureController()
    private let scrollReverserController = MouseScrollReverserController()
    private var permissionTimer: Timer?
    private var lastTrustedState = AccessibilityPermission.isTrusted
    private var launchAtLoginEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        loadSavedToggleStates()
        syncLaunchAtLoginWithSavedState()
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
        gestureItem.state = gestureController.isEnabled ? .on : .off
        gestureItem.isEnabled = AccessibilityPermission.isTrusted
        menu.addItem(gestureItem)
        
        let scrollReverseItem = NSMenuItem(title: scrollReverseMenuTitle, action: #selector(toggleScrollReverse), keyEquivalent: "")
        scrollReverseItem.target = self
        scrollReverseItem.state = scrollReverserController.isEnabled ? .on : .off
        scrollReverseItem.isEnabled = AccessibilityPermission.isTrusted
        menu.addItem(scrollReverseItem)
        
        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(title: launchAtLoginMenuTitle, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())
        
        let permissionItem = NSMenuItem(title: "打开辅助功能设置", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        let quitItem = NSMenuItem(title: "退出 MouseTool", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private var gestureMenuTitle: String {
        AccessibilityPermission.isTrusted ? "启用右键切换屏幕" : "启用右键切换屏幕（需要辅助功能权限）"
    }

    private var scrollReverseMenuTitle: String {
        AccessibilityPermission.isTrusted ? "启用滚动垂直反转" : "启用滚动垂直反转（需要辅助功能权限）"
    }

    private var launchAtLoginMenuTitle: String {
        if SMAppService.mainApp.status == .requiresApproval {
            return "开机自动启动（需批准）"
        }

        return "开机自动启动"
    }

    @objc private func toggleEnabled() {
        gestureController.isEnabled.toggle()
        saveToggleStates()
        if gestureController.isEnabled {
            gestureController.start()
        } else {
            gestureController.stop()
        }
        rebuildMenu()
    }

    @objc private func toggleScrollReverse() {
        scrollReverserController.isEnabled.toggle()
        saveToggleStates()
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
        let newValue = !launchAtLoginEnabled

        do {
            try applyLaunchAtLogin(enabled: newValue)
            launchAtLoginEnabled = newValue
            saveToggleStates()
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

    private func loadSavedToggleStates() {
        let defaults = Self.defaults
        gestureController.isEnabled = savedBool(
            forKey: DefaultsKey.gestureEnabled,
            defaultValue: true,
            defaults: defaults
        )
        scrollReverserController.isEnabled = savedBool(
            forKey: DefaultsKey.scrollReverseEnabled,
            defaultValue: true,
            defaults: defaults
        )
        launchAtLoginEnabled = savedBool(
            forKey: DefaultsKey.launchAtLoginEnabled,
            defaultValue: isLaunchAtLoginRequestedBySystem,
            defaults: defaults
        )
        NSLog("MouseTool 已读取开关状态：gestureEnabled=\(gestureController.isEnabled), scrollReverseEnabled=\(scrollReverserController.isEnabled), launchAtLoginEnabled=\(launchAtLoginEnabled)")
    }

    private func saveToggleStates() {
        let defaults = Self.defaults
        defaults.set(gestureController.isEnabled, forKey: DefaultsKey.gestureEnabled)
        defaults.set(scrollReverserController.isEnabled, forKey: DefaultsKey.scrollReverseEnabled)
        defaults.set(launchAtLoginEnabled, forKey: DefaultsKey.launchAtLoginEnabled)
        defaults.synchronize()
        NSLog("MouseTool 已保存开关状态到 \(Self.defaultsSuiteName)：gestureEnabled=\(gestureController.isEnabled), scrollReverseEnabled=\(scrollReverserController.isEnabled), launchAtLoginEnabled=\(launchAtLoginEnabled)")
    }

    private func syncLaunchAtLoginWithSavedState() {
        do {
            try applyLaunchAtLogin(enabled: launchAtLoginEnabled)
        } catch {
            NSLog("MouseTool 同步开机自动启动状态失败：\(error.localizedDescription)")
        }
    }

    private func applyLaunchAtLogin(enabled: Bool) throws {
        switch (enabled, SMAppService.mainApp.status) {
        case (true, .enabled), (true, .requiresApproval):
            return
        case (true, _):
            try SMAppService.mainApp.register()
        case (false, .enabled), (false, .requiresApproval):
            try SMAppService.mainApp.unregister()
        case (false, _):
            return
        }
    }

    private var isLaunchAtLoginRequestedBySystem: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        default:
            return false
        }
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: defaultsSuiteName) ?? .standard
    }

    private func savedBool(forKey key: String, defaultValue: Bool, defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
