import AppKit
import ApplicationServices

final class MouseGestureController {
    private enum PendingSwitchDirection {
        case left
        case right
    }

    var isEnabled = true

    private(set) var isRunning = false

    private let switchThreshold: CGFloat = 40
    private let directionLockRatio: CGFloat = 1.25
    private let replayedEventMarker: Int64 = 0x4D_54_52_43

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var isRightButtonDown = false
    private var didTriggerDuringPress = false
    private var pendingSwitchDirection: PendingSwitchDirection?
    private var startPoint = CGPoint.zero
    private var latestPoint = CGPoint.zero
    private var originalMouseDownEvent: CGEvent?

    func start() {
        guard isEnabled, !isRunning else { return }
        guard AccessibilityPermission.isTrusted else {
            NSLog("MouseTool 没有辅助功能权限，无法启动事件监听")
            return
        }

        let events = [
            CGEventType.rightMouseDown,
            CGEventType.rightMouseDragged,
            CGEventType.rightMouseUp,
            CGEventType.tapDisabledByTimeout,
            CGEventType.tapDisabledByUserInput
        ]

        let mask = events.reduce(CGEventMask(0)) { result, eventType in
            result | (CGEventMask(1) << eventType.rawValue)
        }

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<MouseGestureController>.fromOpaque(userInfo).takeUnretainedValue()
            return controller.handle(proxy: proxy, type: type, event: event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            NSLog("MouseTool 无法创建 CGEventTap，请检查辅助功能权限，必要时退出应用后重新授权并启动")
            isRunning = false
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
        isRunning = true
        NSLog("MouseTool 事件监听已启动")
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
        isRunning = false
        resetGestureState()
        NSLog("MouseTool 事件监听已停止")
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == replayedEventMarker {
            return Unmanaged.passUnretained(event)
        }

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                NSLog("MouseTool 事件监听被系统暂停，已尝试重新启用")
            }
            return Unmanaged.passUnretained(event)
        }

        guard isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .rightMouseDown:
            isRightButtonDown = true
            didTriggerDuringPress = false
            startPoint = event.location
            latestPoint = startPoint
            originalMouseDownEvent = event.copy()
            NSLog("MouseTool 捕获右键按下：x=\(Int(startPoint.x)), y=\(Int(startPoint.y))")
            return nil

        case .rightMouseDragged:
            guard isRightButtonDown else {
                return Unmanaged.passUnretained(event)
            }

            latestPoint = event.location
            return nil

        case .rightMouseUp:
            latestPoint = event.location
            pendingSwitchDirection = resolveSwitchDirection()
            didTriggerDuringPress = pendingSwitchDirection != nil
            let shouldSuppress = didTriggerDuringPress
            NSLog("MouseTool 捕获右键松开，已触发切换：\(shouldSuppress)")
            let direction = pendingSwitchDirection
            let mouseDownEvent = originalMouseDownEvent
            let mouseUpEvent = event.copy()
            resetGestureState()
            if let direction {
                performSwitchAfterMouseUp(direction)
            } else if let mouseDownEvent, let mouseUpEvent {
                replayRightClick(mouseDown: mouseDownEvent, mouseUp: mouseUpEvent)
            }
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func resolveSwitchDirection() -> PendingSwitchDirection? {
        let deltaX = latestPoint.x - startPoint.x
        let deltaY = latestPoint.y - startPoint.y

        guard abs(deltaX) >= switchThreshold else { return nil }
        guard abs(deltaX) >= abs(deltaY) * directionLockRatio else { return nil }

        if deltaX < 0 {
            NSLog("MouseTool 右键松手：左拖，切到右侧 Space，deltaX=\(Int(deltaX)), deltaY=\(Int(deltaY))")
            return .right
        } else {
            NSLog("MouseTool 右键松手：右拖，切到左侧 Space，deltaX=\(Int(deltaX)), deltaY=\(Int(deltaY))")
            return .left
        }
    }

    private func performSwitchAfterMouseUp(_ direction: PendingSwitchDirection) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            switch direction {
            case .left:
                SpaceSwitcher.switchLeft()
            case .right:
                SpaceSwitcher.switchRight()
            }
        }
    }

    private func replayRightClick(mouseDown: CGEvent, mouseUp: CGEvent) {
        DispatchQueue.main.async {
            mouseDown.setIntegerValueField(.eventSourceUserData, value: self.replayedEventMarker)
            mouseUp.setIntegerValueField(.eventSourceUserData, value: self.replayedEventMarker)
            mouseDown.post(tap: .cghidEventTap)
            mouseUp.post(tap: .cghidEventTap)
        }
    }

    private func resetGestureState() {
        isRightButtonDown = false
        didTriggerDuringPress = false
        pendingSwitchDirection = nil
        startPoint = .zero
        latestPoint = .zero
        originalMouseDownEvent = nil
    }
}
