import Cocoa

enum SpaceSwitcher {
    private struct Shortcut {
        let keyCode: CGKeyCode
        let flags: UInt64
    }

    private enum Direction: String {
        case left = "左侧"
        case right = "右侧"
    }

    private static let moveSpaceLeftHotkeyID = 79
    private static let moveSpaceRightHotkeyID = 81
    private static let fallbackFlags = UInt64(NSEvent.ModifierFlags.control.union(.function).rawValue)
    private static let fallbackLeft = Shortcut(keyCode: 123, flags: fallbackFlags)
    private static let fallbackRight = Shortcut(keyCode: 124, flags: fallbackFlags)

    private static var resolvedShortcuts: [Direction: Shortcut] = loadSystemShortcuts()

    static func switchLeft() {
        sendShortcut(resolvedShortcuts[.left] ?? fallbackLeft, direction: .left)
    }

    static func switchRight() {
        sendShortcut(resolvedShortcuts[.right] ?? fallbackRight, direction: .right)
    }

    static func reloadSystemShortcuts() {
        resolvedShortcuts = loadSystemShortcuts()
        NSLog("MouseTool 已重新读取 Space 切换快捷键配置，数量：\(resolvedShortcuts.count)")
    }

    private static func sendShortcut(_ shortcut: Shortcut, direction: Direction) {
        NSLog("MouseTool 通过 CGEvent 切换到\(direction.rawValue) Space：keyCode=\(shortcut.keyCode), flags=0x\(String(shortcut.flags, radix: 16))")

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else {
            NSLog("MouseTool 创建键盘事件失败")
            return
        }

        keyDown.flags = CGEventFlags(rawValue: shortcut.flags)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func loadSystemShortcuts() -> [Direction: Shortcut] {
        var shortcuts: [Direction: Shortcut] = [:]

        guard let symbolicHotkeys = UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys"),
              let hotkeys = symbolicHotkeys["AppleSymbolicHotKeys"] as? [String: Any] else {
            NSLog("MouseTool 读取 com.apple.symbolichotkeys 失败，将使用内置 Space 切换快捷键")
            return shortcuts
        }

        shortcuts[.left] = parseShortcut(hotkeyID: moveSpaceLeftHotkeyID, from: hotkeys)
        shortcuts[.right] = parseShortcut(hotkeyID: moveSpaceRightHotkeyID, from: hotkeys)

        return shortcuts
    }

    private static func parseShortcut(hotkeyID: Int, from hotkeys: [String: Any]) -> Shortcut? {
        guard let hotkeyConfig = hotkeys[String(hotkeyID)] as? [String: Any],
              let enabled = hotkeyConfig["enabled"] as? Bool,
              enabled,
              let value = hotkeyConfig["value"] as? [String: Any],
              let parameters = value["parameters"] as? [Any],
              parameters.count >= 3,
              let keyCode = parameters[1] as? Int,
              let modifiers = parameters[2] as? Int else {
            return nil
        }

        return Shortcut(keyCode: CGKeyCode(keyCode), flags: UInt64(modifiers))
    }
}
