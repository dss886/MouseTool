import ApplicationServices
import Foundation

enum SpaceSwitcher {
    private static let leftArrowKeyCode: CGKeyCode = 123
    private static let rightArrowKeyCode: CGKeyCode = 124

    static func switchLeft() {
        sendAppleScriptControlArrow(keyCode: leftArrowKeyCode, name: "左箭头")
    }

    static func switchRight() {
        sendAppleScriptControlArrow(keyCode: rightArrowKeyCode, name: "右箭头")
    }

    private static func sendAppleScriptControlArrow(keyCode: CGKeyCode, name: String) {
        NSLog("MouseTool 通过 AppleScript 发送快捷键：Control + \(name)")

        let source = """
        tell application "System Events"
            key code \(keyCode) using control down
        end tell
        """

        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            NSLog("MouseTool 创建 AppleScript 失败")
            return
        }

        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            NSLog("MouseTool 执行 AppleScript 失败：\(errorInfo)")
        }
    }
}
