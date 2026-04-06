// AccessibilityOutput.swift
// VietKey EventTap
//
// AX API-based text replacement for Spotlight and search fields.
// Reads current text value + caret position, calculates replacement range,
// writes new value atomically. Avoids the backspace-retype pattern that
// causes double characters in Spotlight/search bars.
//
// Falls back to false (caller should use keyboard injection) if any AX call fails.

import ApplicationServices
import Foundation

public final class AccessibilityOutput {

    public init() {}

    /// Replace text at the current cursor position using Accessibility API.
    ///
    /// - Parameters:
    ///   - backspaceCount: How many characters to delete before the cursor
    ///   - insertText: The text to insert at the deletion point
    ///   - verify: If true, re-reads the value after writing to confirm success
    /// - Returns: true if AX replacement succeeded, false if caller should fall back to keyboard injection
    public func replaceText(backspaceCount: Int, insertText: String, verify: Bool = false) -> Bool {
        let clampedBackspace = max(0, backspaceCount)

        // Get focused element
        let systemWide = AXUIElementCreateSystemWide()
        guard let focused = elementAttribute(systemWide, kAXFocusedUIElementAttribute) else {
            return false
        }

        // Read current value
        guard let currentValue = stringAttribute(focused, kAXValueAttribute) else {
            return false
        }
        let nsValue = currentValue as NSString
        let valueLength = nsValue.length

        // Read caret position and selection
        var caretLocation = valueLength
        var selectedLength = 0

        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let rangeRef, CFGetTypeID(rangeRef) == AXValueGetTypeID() {
            var sel = CFRange()
            let axRange = unsafeDowncast(rangeRef, to: AXValue.self)
            if AXValueGetValue(axRange, .cfRange, &sel) {
                caretLocation = max(0, min(sel.location, valueLength))
                selectedLength = max(0, sel.length)
            }
        }

        // Calculate replacement range
        var start: Int
        var len: Int
        let selectionAtEnd = selectedLength > 0 && (caretLocation + selectedLength == valueLength)

        if selectedLength > 0 && !selectionAtEnd {
            // User has highlighted text in-place: replace selected range
            start = caretLocation
            len = selectedLength
        } else {
            // No selection or Spotlight autocomplete suffix
            let deleteStart = calculateDeleteStart(nsValue, caretLocation: caretLocation, backspaceCount: clampedBackspace)
            if selectionAtEnd {
                start = deleteStart
                len = (caretLocation - deleteStart) + selectedLength
            } else {
                start = deleteStart
                len = caretLocation - deleteStart
            }
        }

        // Clamp to valid range
        if start + len > valueLength { len = valueLength - start }
        if len < 0 { len = 0 }

        // Build and write new value
        let newValue = nsValue.replacingCharacters(in: NSRange(location: start, length: len), with: insertText)

        let writeError = AXUIElementSetAttributeValue(focused, kAXValueAttribute as CFString, newValue as CFTypeRef)
        guard writeError == .success else {
            return false
        }

        // Set caret position after inserted text
        let newCaret = start + (insertText as NSString).length
        var newSel = CFRange(location: newCaret, length: 0)
        if let newRange = AXValueCreate(.cfRange, &newSel) {
            _ = AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, newRange)
        }

        guard verify else { return true }

        // Verify the value was actually written (some apps apply AXValue asynchronously)
        for attempt in 0..<2 {
            if let verifyValue = stringAttribute(focused, kAXValueAttribute) {
                if canonicalEqual(verifyValue, newValue) { return true }
                // For Spotlight autocomplete, the app may append suggestions
                if selectionAtEnd && canonicalHasPrefix(verifyValue, prefix: newValue) { return true }
            }
            if attempt == 0 { usleep(2000) }
        }

        return false
    }

    // MARK: - Delete Position Calculation

    /// Calculate where to start deleting, accounting for combining marks.
    /// One "backspace" should delete one user-visible character (including its combining marks).
    private func calculateDeleteStart(_ value: NSString, caretLocation: Int, backspaceCount: Int) -> Int {
        guard backspaceCount > 0, caretLocation > 0 else {
            return caretLocation
        }

        var pos = caretLocation
        var deleted = 0

        while deleted < backspaceCount && pos > 0 {
            pos -= 1
            // Skip combining marks (they're part of the previous base character)
            while pos > 0 && isCombiningMark(value.character(at: pos)) {
                pos -= 1
            }
            deleted += 1
        }

        return max(0, pos)
    }

    /// Check if a Unicode scalar is a combining mark.
    @inline(__always)
    private func isCombiningMark(_ scalar: unichar) -> Bool {
        (scalar >= 0x0300 && scalar <= 0x036F) ||  // Combining Diacritical Marks
        (scalar >= 0x1DC0 && scalar <= 0x1DFF) ||  // Combining Diacritical Marks Supplement
        (scalar >= 0x20D0 && scalar <= 0x20FF) ||  // Combining Diacritical Marks for Symbols
        (scalar >= 0xFE20 && scalar <= 0xFE2F)     // Combining Half Marks
    }

    // MARK: - String Comparison

    /// Compare strings with canonical decomposition (handles NFC vs NFD differences).
    private func canonicalEqual(_ lhs: String, _ rhs: String) -> Bool {
        (lhs as NSString).compare(rhs, options: [.literal], range: NSRange(location: 0, length: (lhs as NSString).length)) == .orderedSame ||
        lhs.precomposedStringWithCanonicalMapping == rhs.precomposedStringWithCanonicalMapping
    }

    /// Check if string has prefix, accounting for canonical equivalence.
    private func canonicalHasPrefix(_ string: String, prefix: String) -> Bool {
        string.precomposedStringWithCanonicalMapping.hasPrefix(prefix.precomposedStringWithCanonicalMapping)
    }

    // MARK: - AX Helpers

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == CFStringGetTypeID() else {
            return nil
        }
        return value as? String
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }
}
