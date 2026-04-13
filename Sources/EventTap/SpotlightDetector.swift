// SpotlightDetector.swift
// GoviKey EventTap
//
// Detects Spotlight, search bars, and other search-field contexts via Accessibility API.
// Uses AXRole/AXSubrole/AXDescription/AXPlaceholderValue to identify search fields.
// Results cached for 150ms to avoid expensive AX calls on every keystroke.

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

public final class SpotlightDetector {

    // MARK: - Constants

    private static let cacheDurationMs: UInt64 = 150
    private static let forceRecheckAfterInvalidationMs: UInt64 = 100

    private static let searchKeywords: [String] = [
        "search", "tìm kiếm", "tìm", "filter", "lọc",
    ]

    private static let spotlightBundleId = "com.apple.Spotlight"

    // MARK: - Cache State

    private var cachedResult: Bool = false
    private var lastCheckTime: UInt64 = 0
    private var lastInvalidationTime: UInt64 = 0
    private var cachedBundleId: String?

    private let classifier = AppClassifier.shared

    public init() {}

    // MARK: - Public API

    /// Check if the currently focused element is a search field / Spotlight-like context.
    /// Uses a 150ms cache to minimize AX API overhead.
    public func isActive() -> Bool {
        let now = machTimeMs()

        // Force recheck immediately after invalidation
        var effectiveLastCheck = lastCheckTime
        if lastInvalidationTime > 0 {
            let sinceInvalidation = now - lastInvalidationTime
            if sinceInvalidation < Self.forceRecheckAfterInvalidationMs {
                effectiveLastCheck = 0
            }
        }

        // Return cached result if still fresh
        if effectiveLastCheck > 0 && (now - effectiveLastCheck) < Self.cacheDurationMs {
            return cachedResult
        }

        // Fresh AX check
        let result = performDetection()
        cachedResult = result
        lastCheckTime = machTimeMs()
        return result
    }

    /// Invalidate the cache. Call on Cmd+Space, Escape, mouse click, or app switch.
    public func invalidateCache() {
        lastInvalidationTime = machTimeMs()
        lastCheckTime = 0
    }

    /// Handle events that should invalidate Spotlight cache.
    public func handleCacheInvalidation(type: CGEventType, keyCode: UInt16, flags: CGEventFlags) {
        // Cmd+Space toggles Spotlight
        if type == .keyDown && keyCode == 49 && flags.contains(.maskCommand) {
            invalidateCache()
            return
        }

        // Escape dismisses Spotlight
        if type == .keyDown && keyCode == 53 && cachedResult {
            invalidateCache()
            return
        }

        // Mouse click may change focus
        if (type == .leftMouseDown || type == .rightMouseDown) && cachedResult {
            invalidateCache()
        }
    }

    /// The bundle ID of the last detected focused app (from AX check).
    public var lastDetectedBundleId: String? { cachedBundleId }

    // MARK: - Detection Logic

    private func performDetection() -> Bool {
        guard let focused = focusedElement() else {
            updateCache(false, bundleId: nil)
            return false
        }

        // Get PID and bundle ID of focused element
        var pid: pid_t = 0
        guard AXUIElementGetPid(focused, &pid) == .success, pid > 0 else {
            updateCache(false, bundleId: nil)
            return false
        }

        let bundleId = bundleIdFromPid(pid)

        // Check if focused element looks like a search field
        if isSearchField(focused, bundleId: bundleId) {
            updateCache(true, bundleId: bundleId)
            return true
        }

        // Check if it's the Spotlight app by bundle ID
        if let bundleId, bundleId == Self.spotlightBundleId || bundleId.hasPrefix(Self.spotlightBundleId) {
            updateCache(true, bundleId: bundleId)
            return true
        }

        // Fallback: check process path for Spotlight
        if bundleId == nil {
            let pathBufSize = 4096
            var pathBuffer = [CChar](repeating: 0, count: pathBufSize)
            if proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 {
                let path = String(cString: pathBuffer)
                if path.contains("Spotlight") {
                    updateCache(true, bundleId: Self.spotlightBundleId)
                    return true
                }
            }
        }

        updateCache(false, bundleId: bundleId)
        return false
    }

    /// Check if an AXUIElement looks like a search field.
    private func isSearchField(_ element: AXUIElement, bundleId: String?) -> Bool {
        // For browsers, use AX replacement only for the URL/address bar (not web content)
        if let bundleId, classifier.isBrowser(bundleId) {
            return isBrowserAddressBar(element)
        }

        guard let role = stringAttribute(element, kAXRoleAttribute) else {
            return false
        }

        // AXSearchField is always a search field
        if role == "AXSearchField" {
            return true
        }

        // AXTextField / AXTextArea — check sub-attributes for search keywords
        if role == "AXTextField" || role == "AXTextArea" {
            return containsSearchKeyword(stringAttribute(element, kAXSubroleAttribute)) ||
                   containsSearchKeyword(stringAttribute(element, kAXIdentifierAttribute)) ||
                   containsSearchKeyword(stringAttribute(element, kAXDescriptionAttribute)) ||
                   containsSearchKeyword(stringAttribute(element, kAXPlaceholderValueAttribute))
        }

        return false
    }

    /// Detect if focused element is a browser address/URL bar (not web content).
    /// Address bars are AXTextField/AXComboBox/AXSearchField NOT inside an AXWebArea.
    private func isBrowserAddressBar(_ element: AXUIElement) -> Bool {
        guard let role = stringAttribute(element, kAXRoleAttribute) else { return false }
        guard role == "AXTextField" || role == "AXComboBox" || role == "AXSearchField" else {
            return false
        }
        // Walk parent chain — if we hit AXWebArea, we're inside web content
        var current: AXUIElement? = element
        for _ in 0..<10 {
            guard let el = current else { break }
            if stringAttribute(el, kAXRoleAttribute) == "AXWebArea" {
                return false
            }
            current = elementAttribute(el, kAXParentAttribute)
        }
        return true
    }

    // MARK: - Safari Helpers

    /// Check if Safari is focused on its address bar (vs web content).
    public func isSafariAddressBar() -> Bool {
        guard let focused = focusedElement() else {
            return true // Assume address bar if can't detect
        }

        if let role = stringAttribute(focused, kAXRoleAttribute),
           role == "AXTextField" || role == "AXComboBox" || role == "AXSearchField" {
            return true
        }

        // Walk parent chain looking for AXWebArea (= web content, not address bar)
        var current: AXUIElement? = focused
        for _ in 0..<10 {
            guard let el = current else { break }
            if stringAttribute(el, kAXRoleAttribute) == "AXWebArea" {
                return false
            }
            current = elementAttribute(el, kAXParentAttribute)
        }

        return true // Not in web content = address bar context
    }

    // MARK: - AX Helpers

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        return elementAttribute(systemWide, kAXFocusedUIElementAttribute)
    }

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

    private func containsSearchKeyword(_ value: String?) -> Bool {
        guard let lower = value?.lowercased(), !lower.isEmpty else { return false }
        for keyword in Self.searchKeywords where lower.contains(keyword) {
            return true
        }
        return false
    }

    private func bundleIdFromPid(_ pid: pid_t) -> String? {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    private func updateCache(_ active: Bool, bundleId: String?) {
        cachedBundleId = bundleId
    }

    // MARK: - Timing

    private static var timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private func machTimeMs() -> UInt64 {
        let now = mach_absolute_time()
        let info = Self.timebaseInfo
        return (now * UInt64(info.numer)) / (UInt64(info.denom) * 1_000_000)
    }
}
