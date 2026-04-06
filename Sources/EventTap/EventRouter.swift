// EventRouter.swift
// VietKey EventTap
//
// Main event callback dispatcher. Routes keystrokes to the Vietnamese engine
// and sends output via KeyEventSender.
// Designed for minimal overhead — game mode path does ~5 operations.

import CoreGraphics
import Foundation
import Engine

/// Central controller that owns the engine, event tap, and sender.
public final class InputController {

    public let engine = VietnameseEngine()
    public let sender = KeyEventSender()
    public let tapManager = EventTapManager()
    public let appMonitor = ActiveAppMonitor()
    public let spotlightDetector = SpotlightDetector()
    public let accessibilityOutput = AccessibilityOutput()

    /// Whether Vietnamese mode is active (vs English passthrough).
    public var isVietnameseMode: Bool = true

    /// Force game mode regardless of app classification.
    public var forceGameMode: Bool = false

    /// Whether the input system is running.
    public var isRunning: Bool { tapManager.isActive }

    /// Whether the current context is a Spotlight/search field (cached per-check).
    private var isSpotlightContext: Bool = false

    /// Whether the current keystroke should use the game fast path.
    private var isGamePath: Bool = false

    /// Callback invoked on language switch (for UI update + sound).
    /// Called on the event tap thread — dispatch to main if needed.
    public var onLanguageSwitch: (() -> Void)?

    /// Modifier flags from the last flagsChanged event (for modifier-only hotkey detection).
    var lastModifierFlags: UInt64 = 0

    /// Whether a non-modifier key was pressed while hotkey modifiers were held.
    var keyPressedWhileModifiersHeld: Bool = false

    /// Primary hotkey modifier mask (set by UserSettings.apply).
    public var hotkeyModifierMask: UInt64 = 0

    /// Secondary hotkey key code (-1 = disabled).
    public var secondaryHotkeyKeyCode: Int = -1

    /// Secondary hotkey modifier flags (NSEvent.ModifierFlags rawValue).
    public var secondaryHotkeyModifiers: Int = 0

    /// When true, the next keyDown is captured for shortcut recording instead of normal processing.
    /// The tap consumes the event so it doesn't leak to other apps.
    public var isRecordingShortcut: Bool = false

    /// Callback when a key is captured during shortcut recording: (keyCode, modifierFlags).
    public var onShortcutRecorded: ((UInt16, UInt64) -> Void)?

    public init() {}

    // MARK: - Start / Stop

    /// Start the input method. Requires Accessibility permission.
    public func start() -> Bool {
        engine.initialize()
        engine.config.inputType = .telex
        engine.config.checkSpelling = true
        engine.config.useModernOrthography = true

        // Start app switch monitoring
        appMonitor.start()

        // Store self pointer for C callback
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        return tapManager.start(callback: eventTapCallback, userInfo: refcon)
    }

    /// Stop the input method.
    public func stop() {
        tapManager.stop()
        appMonitor.stop()
    }

    /// Toggle between Vietnamese and English mode.
    public func toggleLanguage() {
        isVietnameseMode.toggle()
        if isVietnameseMode {
            engine.resetSession()
        }
    }

    // MARK: - Hotkey Detection

    /// Check flagsChanged event for modifier-only hotkey (like PHTV's Ctrl+Shift).
    /// Triggers on the first modifier release after the full combo was held.
    /// Returns true if language was toggled.
    func checkModifierHotkey(flags: UInt64) -> Bool {
        let mask = hotkeyModifierMask
        guard mask != 0 else {
            lastModifierFlags = flags
            return false
        }

        let relevantMask = CGEventFlags.maskControl.rawValue
            | CGEventFlags.maskShift.rawValue
            | CGEventFlags.maskCommand.rawValue
            | CGEventFlags.maskAlternate.rawValue

        let currentModifiers = flags & relevantMask
        let previousModifiers = lastModifierFlags & relevantMask

        if currentModifiers > previousModifiers {
            // Pressing more modifiers — update peak state
            lastModifierFlags = flags
        } else if currentModifiers < previousModifiers {
            // Releasing modifiers — check if peak matched target combo
            let shouldTrigger = previousModifiers == mask && !keyPressedWhileModifiersHeld
            lastModifierFlags = flags
            keyPressedWhileModifiersHeld = false

            if shouldTrigger {
                toggleLanguage()
                onLanguageSwitch?()
                return true
            }
        }

        if currentModifiers == 0 {
            keyPressedWhileModifiersHeld = false
        }

        return false
    }

    /// Check keyDown event for secondary hotkey (modifier + key).
    /// Returns true if language was toggled.
    func checkKeyDownHotkey(keyCode: UInt16, flags: UInt64) -> Bool {
        guard secondaryHotkeyKeyCode >= 0 else { return false }
        guard Int(keyCode) == secondaryHotkeyKeyCode else { return false }

        let relevantMask = CGEventFlags.maskControl.rawValue
            | CGEventFlags.maskShift.rawValue
            | CGEventFlags.maskCommand.rawValue
            | CGEventFlags.maskAlternate.rawValue

        let currentModifiers = flags & relevantMask
        let expectedModifiers = UInt64(secondaryHotkeyModifiers)

        if currentModifiers == expectedModifiers {
            toggleLanguage()
            onLanguageSwitch?()
            return true
        }
        return false
    }

    /// Mark that a key was pressed while modifiers are held (invalidates modifier-only hotkey).
    func markKeyPressedWhileModifiersHeld() {
        keyPressedWhileModifiersHeld = true
    }

    // MARK: - Event Processing

    /// Process a key down event. Called from the C callback.
    /// Two-tier design:
    ///   - GameFastPath: engine → direct keyboard output, no AX/Spotlight/spelling (~5 ops, <100μs)
    ///   - NormalPath: full pipeline with Spotlight detection, AX replacement, spelling
    func handleKeyDown(event: CGEvent) -> CGEvent? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Determine caps status
        let capsStatus: UInt8 = flags.contains(.maskShift) ? 1 :
                                (flags.contains(.maskAlphaShift) ? 2 : 0)

        // Check for control/command modifiers (passthrough)
        let hasControl = flags.contains(.maskControl) || flags.contains(.maskCommand)
        if hasControl {
            engine.resetSession()
            return event
        }

        // Determine path: game fast path vs normal path
        isGamePath = forceGameMode || appMonitor.category == .game

        if isGamePath {
            return handleGameFastPath(event: event, keyCode: keyCode, capsStatus: capsStatus)
        } else {
            return handleNormalPath(event: event, keyCode: keyCode, capsStatus: capsStatus)
        }
    }

    // MARK: - Game Fast Path

    /// Minimal-overhead path for games. ~5 operations per keystroke.
    /// Skips: Spotlight detection, AX API, spelling check overhead.
    /// Target: < 100μs per keystroke.
    @inline(__always)
    private func handleGameFastPath(event: CGEvent, keyCode: UInt16, capsStatus: UInt8) -> CGEvent? {
        // 1. Engine processes the key (pure computation, no I/O)
        let result = engine.handleKeyEvent(
            event: .keyboard,
            state: .keyDown,
            keyCode: keyCode,
            capsStatus: capsStatus,
            otherControlKey: false
        )

        // 2. Act on result — direct keyboard injection only
        switch result.action {
        case .doNothing, .breakWord:
            return event // Pass through unchanged

        case .willProcess:
            if result.backspaceCount > 0 {
                sender.sendBackspaces(result.backspaceCount)
            }
            sendEngineOutput(result)
            return nil // Consume original event

        case .restore, .restoreAndStartNewSession:
            if result.backspaceCount > 0 {
                sender.sendBackspaces(result.backspaceCount)
            }
            sendEngineOutput(result)
            if result.action == .restoreAndStartNewSession {
                engine.resetSession()
            }
            return nil
        }
    }

    // MARK: - Normal Path

    /// Full pipeline with Spotlight detection and AX replacement.
    private func handleNormalPath(event: CGEvent, keyCode: UInt16, capsStatus: UInt8) -> CGEvent? {
        // Detect Spotlight/search field context
        isSpotlightContext = spotlightDetector.isActive() || appMonitor.category == .spotlightLike

        // Process through the Vietnamese engine
        let result = engine.handleKeyEvent(
            event: .keyboard,
            state: .keyDown,
            keyCode: keyCode,
            capsStatus: capsStatus,
            otherControlKey: false
        )

        switch result.action {
        case .doNothing:
            return event

        case .willProcess:
            deliverOutput(result)
            return nil

        case .restore, .restoreAndStartNewSession:
            deliverOutput(result)
            if result.action == .restoreAndStartNewSession {
                engine.resetSession()
            }
            return nil

        case .breakWord:
            return event
        }
    }

    /// Deliver engine output using the appropriate strategy.
    /// Spotlight/search contexts use AX API replacement; everything else uses keyboard injection.
    func deliverOutput(_ result: EngineResult) {
        if isSpotlightContext {
            // Build the output string
            let text = buildOutputString(result)
            // Try AX API replacement (atomic, no double chars)
            let axOK = accessibilityOutput.replaceText(
                backspaceCount: result.backspaceCount,
                insertText: text,
                verify: result.backspaceCount > 0
            )
            if axOK { return }
            // AX failed — fall through to keyboard injection
        }

        // Normal path: backspace + retype via synthetic key events
        if result.backspaceCount > 0 {
            sender.sendBackspaces(result.backspaceCount)
        }
        sendEngineOutput(result)
    }

    /// Convert engine output data to a precomposed Unicode string.
    func buildOutputString(_ result: EngineResult) -> String {
        guard result.newCharCount > 0 else { return "" }

        var chars: [UInt16] = []
        for i in stride(from: result.newCharCount - 1, through: 0, by: -1) {
            guard i < result.data.count else { continue }
            let ch = decodeEngineChar(result.data[i])
            if ch > 0 { chars.append(ch) }
        }

        guard !chars.isEmpty else { return "" }
        let str = String(utf16CodeUnits: chars, count: chars.count)
        return str.precomposedStringWithCanonicalMapping
    }

    /// Convert engine output data to Unicode and send via keyboard injection.
    func sendEngineOutput(_ result: EngineResult) {
        let text = buildOutputString(result)
        guard !text.isEmpty else { return }
        let utf16 = Array(text.utf16)
        sender.sendUnicodeString(utf16)
    }

    /// Decode a single engine character data value to a Unicode code point.
    func decodeEngineChar(_ data: UInt32) -> UInt16 {
        // Pure character (bit 31 set) — raw Unicode
        if (data & PURE_CHARACTER_MASK) != 0 {
            return UInt16(data & 0xFFFF)
        }
        // Encoded character (CHAR_CODE_MASK set) — already resolved by engine
        if (data & CHAR_CODE_MASK) != 0 {
            return UInt16(data & 0xFFFF)
        }
        // Raw key code — convert to ASCII
        let isCaps = (data & CAPS_MASK) != 0
        let keyCode = data & CHAR_MASK
        let lookupKey = isCaps ? (keyCode | CAPS_MASK) : keyCode
        return vnKeyCodeToCharacter(lookupKey)
    }
}

// MARK: - C Callback

/// C-convention callback for CGEventTap.
/// Bridges to InputController.handleKeyDown() with minimal overhead.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // 1. Skip self-generated events (< 1ns)
    if EventMarker.isSelfGenerated(event) {
        return Unmanaged.passRetained(event)
    }

    // 2. Handle tap disabled by system
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        guard let refcon = refcon else { return Unmanaged.passRetained(event) }
        let controller = Unmanaged<InputController>.fromOpaque(refcon).takeUnretainedValue()
        controller.tapManager.reEnable()
        return Unmanaged.passRetained(event)
    }

    // 3. Get controller reference
    guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }
    let controller = Unmanaged<InputController>.fromOpaque(refcon).takeUnretainedValue()

    // 4. Determine if we're on the game fast path (skip AX/Spotlight overhead)
    let isGamePath = controller.forceGameMode || controller.appMonitor.category == .game

    // 5. Invalidate Spotlight cache on relevant events (skip in game mode)
    if !isGamePath {
        if type == .leftMouseDown || type == .rightMouseDown || type == .keyDown || type == .flagsChanged {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            controller.spotlightDetector.handleCacheInvalidation(type: type, keyCode: keyCode, flags: event.flags)
        }
    }

    // 6. Reset engine on mouse clicks (word boundary)
    if type == .leftMouseDown || type == .rightMouseDown {
        controller.engine.resetSession()
        return Unmanaged.passRetained(event)
    }

    // 7. Handle hotkey detection on flagsChanged (modifier-only shortcut)
    if type == .flagsChanged {
        let flags = event.flags.rawValue
        if controller.checkModifierHotkey(flags: flags) {
            return Unmanaged.passRetained(event) // Hotkey triggered, pass event through
        }
        return Unmanaged.passRetained(event)
    }

    // 8. Only process keyDown events
    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    // 9. Shortcut recording mode — capture key and consume event
    if controller.isRecordingShortcut {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.rawValue
        controller.isRecordingShortcut = false
        controller.onShortcutRecorded?(keyCode, flags)
        return nil // Consume — don't leak to other apps
    }

    // 10. Mark key pressed while modifiers held (invalidates modifier-only hotkey)
    controller.markKeyPressedWhileModifiersHeld()

    // 10. Check secondary hotkey (modifier + key)
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    if controller.checkKeyDownHotkey(keyCode: keyCode, flags: event.flags.rawValue) {
        return nil // Consume the hotkey event
    }

    // 11. Check if Vietnamese mode is active
    guard controller.isVietnameseMode else {
        return Unmanaged.passRetained(event)
    }

    // 12. Process the key
    if let passthrough = controller.handleKeyDown(event: event) {
        return Unmanaged.passRetained(passthrough)
    }
    return nil // Event consumed
}
