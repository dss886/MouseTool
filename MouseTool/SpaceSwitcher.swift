import ApplicationServices
import Foundation

enum SpaceSwitcher {
    private static let leftArrowKeyCode: CGKeyCode = 83
    private static let rightArrowKeyCode: CGKeyCode = 84
    private static let controlKeyCode: CGKeyCode = 59

    static func switchLeft() {
        sendControlArrow(keyCode: leftArrowKeyCode, name: "左箭头")
    }

    static func switchRight() {
        sendControlArrow(keyCode: rightArrowKeyCode, name: "右箭头")
    }

    private static func sendControlArrow(keyCode: CGKeyCode, name: String) {
        NSLog("MouseTool 通过 CGEvent 发送快捷键：Control + \(name)")

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            NSLog("MouseTool 创建键盘事件失败")
            return
        }

        keyDown.flags = .maskControl
        keyUp.flags = .maskControl
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
