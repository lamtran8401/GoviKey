// UserSettings.swift
// VietKey App
//
// Centralized user preferences backed by UserDefaults.
// Observable object that syncs to EngineConfig and InputController.

import SwiftUI
import Engine
import EventTap

final class UserSettings: ObservableObject {

    // MARK: - Input

    @AppStorage("charEncoding") var charEncoding: Int = 0 {
        didSet { notifyChange() }
    }

    @AppStorage("inputType") var inputType: String = "telex" {
        didSet { notifyChange() }
    }

    @AppStorage("checkSpelling") var checkSpelling: Bool = true {
        didSet { notifyChange() }
    }

    @AppStorage("useModernOrthography") var useModernOrthography: Bool = true {
        didSet { notifyChange() }
    }

    @AppStorage("quickTelex") var quickTelex: Bool = false {
        didSet { notifyChange() }
    }

    @AppStorage("upperCaseFirstChar") var upperCaseFirstChar: Bool = false {
        didSet { notifyChange() }
    }

    @AppStorage("freeMark") var freeMark: Bool = false {
        didSet { notifyChange() }
    }

    @AppStorage("quickStartConsonant") var quickStartConsonant: Bool = false {
        didSet { notifyChange() }
    }

    @AppStorage("quickEndConsonant") var quickEndConsonant: Bool = false {
        didSet { notifyChange() }
    }

    // MARK: - Game Mode

    @AppStorage("forceGameMode") var forceGameMode: Bool = false {
        didSet { notifyChange() }
    }

    // MARK: - Sound

    @AppStorage("switchSound") var switchSound: Bool = true {
        didSet { notifyChange() }
    }

    @AppStorage("switchSoundVolume") var switchSoundVolume: Double = 0.5 {
        didSet { notifyChange() }
    }

    // MARK: - Primary Shortcut (modifier-only, like PHTV)

    @AppStorage("switchKeyControl") var switchKeyControl: Bool = true {
        didSet { notifyChange() }
    }

    @AppStorage("switchKeyShift") var switchKeyShift: Bool = true {
        didSet { notifyChange() }
    }

    @AppStorage("switchKeyCommand") var switchKeyCommand: Bool = false {
        didSet { notifyChange() }
    }

    @AppStorage("switchKeyOption") var switchKeyOption: Bool = false {
        didSet { notifyChange() }
    }

    /// Whether the primary shortcut has any modifiers selected.
    var hasPrimaryShortcut: Bool {
        switchKeyControl || switchKeyShift || switchKeyCommand || switchKeyOption
    }

    /// Build CGEventFlags mask from selected modifier bools.
    var primaryShortcutFlags: UInt64 {
        var flags: UInt64 = 0
        if switchKeyControl { flags |= CGEventFlags.maskControl.rawValue }
        if switchKeyShift   { flags |= CGEventFlags.maskShift.rawValue }
        if switchKeyCommand { flags |= CGEventFlags.maskCommand.rawValue }
        if switchKeyOption  { flags |= CGEventFlags.maskAlternate.rawValue }
        return flags
    }

    // MARK: - Secondary Shortcut (modifier + key)

    /// Secondary shortcut modifier flags (raw NSEvent.ModifierFlags rawValue)
    @AppStorage("secondaryShortcutModifiers") var secondaryShortcutModifiers: Int = 0 {
        didSet { notifyChange() }
    }

    /// Secondary shortcut key code (-1 = disabled)
    @AppStorage("secondaryShortcutKeyCode") var secondaryShortcutKeyCode: Int = -1 {
        didSet { notifyChange() }
    }

    // MARK: - Language

    @AppStorage("appLanguage") var appLanguage: String = "vi" {
        didSet { notifyChange() }
    }


    // MARK: - Custom Game Apps

    @AppStorage("customGameApps") var customGameAppsData: Data = Data() {
        didSet { notifyChange() }
    }

    var customGameApps: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: customGameAppsData)) ?? []
        }
        set {
            customGameAppsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    // MARK: - Sync

    private func notifyChange() {
        objectWillChange.send()
    }

    /// Apply current settings to the engine and input controller.
    func apply(to controller: InputController) {
        controller.engine.config.charEncoding = CharacterEncoding(rawValue: charEncoding) ?? .unicode
        controller.engine.config.inputType = inputType == "vni" ? .vni : .telex
        controller.engine.config.checkSpelling = checkSpelling
        controller.engine.config.useModernOrthography = useModernOrthography
        controller.engine.config.quickTelex = quickTelex
        controller.engine.config.upperCaseFirstChar = upperCaseFirstChar
        controller.engine.config.freeMark = freeMark
        controller.engine.config.quickStartConsonant = quickStartConsonant
        controller.engine.config.quickEndConsonant = quickEndConsonant
        controller.forceGameMode = forceGameMode
        controller.hotkeyModifierMask = primaryShortcutFlags
        controller.secondaryHotkeyKeyCode = secondaryShortcutKeyCode
        controller.secondaryHotkeyModifiers = secondaryShortcutModifiers
        AppClassifier.shared.setCustomGames(customGameApps)
    }
}
