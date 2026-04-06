// EventTapManager.swift
// VietKey EventTap
//
// Creates and manages the CGEventTap lifecycle.
// Tries HID-level tap first (better for games/fullscreen), falls back to session tap.

import CoreGraphics
import Foundation

public final class EventTapManager {

    /// Callback type matching CGEventTapCallBack signature.
    public typealias EventCallback = @convention(c) (
        CGEventTapProxy, CGEventType, CGEvent, UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isUsingHIDTap: Bool = false

    /// Whether the event tap is currently active.
    public var isActive: Bool { eventTap != nil }

    public init() {}

    // MARK: - Tap Creation

    /// Create and install the event tap.
    /// - Parameters:
    ///   - callback: The C-convention callback function
    ///   - userInfo: Pointer passed as refcon to the callback
    /// - Returns: true if tap was created successfully
    @discardableResult
    public func start(callback: EventCallback, userInfo: UnsafeMutableRawPointer?) -> Bool {
        guard eventTap == nil else { return true }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        // Try HID tap first (better for fullscreen/games)
        if let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) {
            eventTap = tap
            isUsingHIDTap = true
        }
        // Fallback to session tap
        else if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) {
            eventTap = tap
            isUsingHIDTap = false
        }
        else {
            return false
        }

        // Add to run loop
        guard let tap = eventTap else { return false }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source = runLoopSource else {
            eventTap = nil
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    // MARK: - Tap Health

    /// Re-enable the tap if it was disabled by the system (timeout or user input).
    /// Call this from the callback when receiving tapDisabledByTimeout or tapDisabledByUserInput.
    public func reEnable() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Check if the tap is still enabled.
    public var isEnabled: Bool {
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    // MARK: - Shutdown

    /// Stop and remove the event tap.
    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    deinit {
        stop()
    }
}
