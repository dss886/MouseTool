import AppKit
import ApplicationServices
import CoreGraphics

final class MouseScrollReverserController {
    private enum ScrollEventSource {
        case mouse
        case trackpad
    }

    var isEnabled = false

    private(set) var isRunning = false

    private let touchToScrollThreshold: UInt64 = 222_000_000
    private let mouseAfterTouchThreshold: UInt64 = 333_000_000

    private var activeTap: CFMachPort?
    private var activeRunLoopSource: CFRunLoopSource?
    private var passiveTap: CFMachPort?
    private var passiveRunLoopSource: CFRunLoopSource?

    private var touchingCount = 0
    private var lastTouchTime: UInt64 = 0
    private var lastSource: ScrollEventSource = .mouse

    func start() {
        guard isEnabled, !isRunning else { return }
        guard AccessibilityPermission.isTrusted else {
            NSLog("MouseTool 没有辅助功能权限，无法启动鼠标滚动反转")
            return
        }

        resetState()

        passiveTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(NSEvent.EventTypeMask.gesture.rawValue),
            callback: eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        activeTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(NSEvent.EventTypeMask.scrollWheel.rawValue),
            callback: eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let passiveTap, let activeTap else {
            NSLog("MouseTool 无法创建鼠标滚动反转事件监听，请检查辅助功能权限")
            stop()
            return
        }

        passiveRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, passiveTap, 0)
        activeRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, activeTap, 0)

        if let passiveRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), passiveRunLoopSource, .commonModes)
        }

        if let activeRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), activeRunLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: passiveTap, enable: true)
        CGEvent.tapEnable(tap: activeTap, enable: true)
        isRunning = true
        NSLog("MouseTool 鼠标滚动反转已启动")
    }

    func stop() {
        if let passiveTap {
            CGEvent.tapEnable(tap: passiveTap, enable: false)
            CFMachPortInvalidate(passiveTap)
        }

        if let activeTap {
            CGEvent.tapEnable(tap: activeTap, enable: false)
            CFMachPortInvalidate(activeTap)
        }

        if let passiveRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), passiveRunLoopSource, .commonModes)
        }

        if let activeRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), activeRunLoopSource, .commonModes)
        }

        passiveRunLoopSource = nil
        activeRunLoopSource = nil
        passiveTap = nil
        activeTap = nil
        isRunning = false
        resetState()
        NSLog("MouseTool 鼠标滚动反转已停止")
    }

    private let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<MouseScrollReverserController>.fromOpaque(userInfo).takeUnretainedValue()
        return controller.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            enableTaps()
            return Unmanaged.passUnretained(event)
        }

        if type.rawValue == NSEvent.EventType.gesture.rawValue {
            updateTouchState(from: event)
            return Unmanaged.passUnretained(event)
        }

        guard isEnabled, type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        if scrollSource(for: event) == .mouse {
            reverseVerticalScroll(in: event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func updateTouchState(from event: CGEvent) {
        guard let nsEvent = NSEvent(cgEvent: event) else { return }
        let count = nsEvent.touches(matching: .touching, in: nil).count
        guard count >= 2 else { return }

        touchingCount = max(touchingCount, count)
        lastTouchTime = DispatchTime.now().uptimeNanoseconds
    }

    private func scrollSource(for event: CGEvent) -> ScrollEventSource {
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        if !isContinuous {
            lastSource = .mouse
            touchingCount = 0
            return .mouse
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = lastTouchTime == 0 ? UInt64.max : now - lastTouchTime
        let recentTouchCount = touchingCount
        touchingCount = 0

        if recentTouchCount >= 2 && elapsed < touchToScrollThreshold {
            lastSource = .trackpad
            return .trackpad
        }

        if isNormalScrollPhase(for: event) && elapsed > mouseAfterTouchThreshold {
            lastSource = .mouse
            return .mouse
        }

        return lastSource
    }

    private func reverseVerticalScroll(in event: CGEvent) {
        let wheelDelta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let pointDelta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let fixedDelta = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -wheelDelta)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixedDelta)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -pointDelta)
    }

    private func isNormalScrollPhase(for event: CGEvent) -> Bool {
        guard let nsEvent = NSEvent(cgEvent: event) else { return false }
        return nsEvent.phase == [] && nsEvent.momentumPhase == []
    }

    private func enableTaps() {
        if let passiveTap {
            CGEvent.tapEnable(tap: passiveTap, enable: true)
        }

        if let activeTap {
            CGEvent.tapEnable(tap: activeTap, enable: true)
        }
    }

    private func resetState() {
        touchingCount = 0
        lastTouchTime = 0
        lastSource = .mouse
    }
}
