// KeyEventSender.swift
// GoviKey EventTap
//
// Sends synthetic key events (backspaces and Unicode characters) via CGEvent.

import CoreGraphics

public final class KeyEventSender {

    /// Private event source for synthetic events.
    private let eventSource: CGEventSource?

    /// Where to post events.
    public enum PostLocation {
        case hid
        case session
    }

    public var postLocation: PostLocation = .hid

    public init() {
        self.eventSource = CGEventSource(stateID: .privateState)
    }

    // MARK: - Backspace

    /// Send a single backspace key (keyDown + keyUp).
    public func sendBackspace() {
        guard let source = eventSource else { return }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0x33), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0x33), keyDown: false)
        else { return }

        down.flags.insert(.maskNonCoalesced)
        up.flags.insert(.maskNonCoalesced)

        postEvent(down)
        postEvent(up)
    }

    /// Send multiple backspaces.
    public func sendBackspaces(_ count: Int) {
        for _ in 0..<count {
            sendBackspace()
        }
    }

    // MARK: - Unicode character output

    /// Send a single Unicode character.
    public func sendCharacter(_ char: UInt16) {
        guard let source = eventSource else { return }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }

        var ch = char
        down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
        up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)

        postEvent(down)
        postEvent(up)
    }

    /// Send a Unicode string (array of UTF-16 code units).
    public func sendUnicodeString(_ chars: [UInt16]) {
        guard !chars.isEmpty, let source = eventSource else { return }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }

        var buffer = chars
        down.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &buffer)
        up.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &buffer)

        postEvent(down)
        postEvent(up)
    }

    /// Send a physical key event (with virtual key code, for keys like Enter, Tab).
    public func sendKeyEvent(virtualKey: CGKeyCode, flags: CGEventFlags = []) {
        guard let source = eventSource else { return }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        else { return }

        if !flags.isEmpty {
            down.flags = flags
            up.flags = flags
        }

        postEvent(down)
        postEvent(up)
    }

    // MARK: - Event posting

    /// Mark and post a synthetic event.
    private func postEvent(_ event: CGEvent) {
        EventMarker.markAsSelfGenerated(event)
        switch postLocation {
        case .hid:
            event.post(tap: .cghidEventTap)
        case .session:
            event.post(tap: .cgSessionEventTap)
        }
    }
}
