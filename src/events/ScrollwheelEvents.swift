import Cocoa

class ScrollwheelEvents {
    static var shouldBeEnabled: Bool!
    private static var eventTap: CFMachPort!
    // accumulated precise (trackpad) scroll distance not yet converted into selection steps
    private static var scrollAccumulator = CGFloat(0)
    private static let pixelsPerSelectionStep = CGFloat(50)

    static func observe() {
        observe_()
        toggle(false)
    }

    static func toggle(_ enabled: Bool) {
        guard enabled != shouldBeEnabled else { return }
        shouldBeEnabled = enabled
        scrollAccumulator = 0
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: enabled)
        }
    }

    static func reEnableTapIfNeeded() {
        guard let eventTap, shouldBeEnabled, !CGEvent.tapIsEnabled(tap: eventTap) else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        Logger.warning { "" }
    }

    private static func observe_() {
        // CGEvent.tapCreate returns null if ensureAccessibilityCheckboxIsChecked() didn't pass
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap, // we need raw data
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: NSEvent.EventTypeMask.scrollWheel.rawValue,
            callback: handleEvent,
            userInfo: nil)
        if let eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
            CFRunLoopAddSource(BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop, runLoopSource, .commonModes)
        } else {
            App.restart()
        }
    }

    private static let handleEvent: CGEventTapCallBack = { _, type, cgEvent, _ in
        if type.rawValue == NSEvent.EventType.scrollWheel.rawValue {
            if Preferences.scrollToSelectEnabled && SwitcherSession.isActive && handleSelectionScroll(cgEvent) {
                return nil // absorb: the scroll drives the switcher selection
            }
            if cgEvent.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 {
                // block continuous (trackpad) scrolling; let discrete (mouse) scrolling through
                return nil
            }
        } else if (type == .tapDisabledByUserInput || type == .tapDisabledByTimeout) && shouldBeEnabled {
            CGEvent.tapEnable(tap: eventTap!, enable: true)
        }
        return Unmanaged.passUnretained(cgEvent) // focused app will receive the event
    }

    /// scrolling up moves the selection up. Trackpads accumulate precise pixel deltas so a
    /// continuous swipe steps through the list; mouse wheels step once per notch
    private static func handleSelectionScroll(_ cgEvent: CGEvent) -> Bool {
        guard let nsEvent = cgEvent.toNSEvent() else { return false }
        let delta = nsEvent.scrollingDeltaY
        if nsEvent.hasPreciseScrollingDeltas {
            if delta * scrollAccumulator < 0 {
                // direction flipped; discard leftover momentum so the selection turns around instantly
                scrollAccumulator = 0
            }
            scrollAccumulator += delta
            let steps = Int(scrollAccumulator / pixelsPerSelectionStep)
            if steps != 0 {
                scrollAccumulator -= CGFloat(steps) * pixelsPerSelectionStep
                cycleSelection(steps)
            }
        } else if delta != 0 {
            cycleSelection(delta > 0 ? 1 : -1)
        }
        return true
    }

    private static func cycleSelection(_ steps: Int) {
        DispatchQueue.main.async {
            if Preferences.trackpadHapticFeedbackEnabled {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            }
            for _ in 0..<abs(steps) {
                App.cycleSelection(steps > 0 ? .up : .down, allowWrap: false)
            }
        }
    }
}
