// GeneralTab.swift
// VietKey App
//
// General settings tab: language, game mode, shortcuts, switch sound.

import SwiftUI
import EventTap

struct GeneralTab: View {
    @ObservedObject var settings: UserSettings
    let inputController: InputController

    private var shortcutDisplay: String {
        var parts: [String] = []
        if settings.switchKeyControl { parts.append("⌃") }
        if settings.switchKeyShift { parts.append("⇧") }
        if settings.switchKeyCommand { parts.append("⌘") }
        if settings.switchKeyOption { parts.append("⌥") }
        return parts.isEmpty ? "—" : parts.joined()
    }

    private var langDisplay: String {
        settings.appLanguage == "vi" ? "Tiếng Việt" : "English"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            SummaryBanner(items: [
                ("globe", L.language, langDisplay),
                ("command", L.shortcut, shortcutDisplay),
                ("speaker.wave.2.fill", L.switchSound, settings.switchSound ? "ON" : "OFF"),
                ("gamecontroller.fill", "Game Mode", settings.forceGameMode ? "ON" : "OFF"),
            ])

            SectionHeader(L.language)

            SettingRow(L.appLanguage, description: L.appLanguageDescription) {
                Picker("", selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .cardStyle()

            SettingRow(L.gameMode, description: L.gameModeDescription) {
                Toggle("", isOn: $settings.forceGameMode)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .cardStyle()

            SectionHeader(L.shortcut)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.primaryShortcut)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.15))
                    Text(L.modifierOnlyHint)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.5))

                    HStack(spacing: 8) {
                        ModifierKeyToggle(symbol: "⌃", name: "Control", isOn: $settings.switchKeyControl)
                        ModifierKeyToggle(symbol: "⇧", name: "Shift", isOn: $settings.switchKeyShift)
                        ModifierKeyToggle(symbol: "⌘", name: "Command", isOn: $settings.switchKeyCommand)
                        ModifierKeyToggle(symbol: "⌥", name: "Option", isOn: $settings.switchKeyOption)
                    }
                }
                .padding(.bottom, 14)

                ThinDivider()
                    .padding(.bottom, 14)

                SettingRow(L.secondaryShortcut, description: L.shortcutDescription) {
                    ShortcutRecorder(
                        keyCode: $settings.secondaryShortcutKeyCode,
                        modifiers: $settings.secondaryShortcutModifiers,
                        inputController: inputController
                    )
                }
            }
            .cardStyle()

            SectionHeader(L.switchSound)

            VStack(spacing: 0) {
                SettingRow(L.switchSound, description: L.switchSoundDescription) {
                    Toggle("", isOn: $settings.switchSound)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if settings.switchSound {
                    ThinDivider()
                        .padding(.vertical, 12)

                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.5))
                        Slider(value: $settings.switchSoundVolume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
            }
            .cardStyle()
        }
    }
}

// MARK: - Modifier Key Toggle

struct ModifierKeyToggle: View {
    let symbol: String
    let name: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(spacing: 3) {
                Text(symbol)
                    .font(.system(size: 17, weight: .medium))
                Text(name)
                    .font(.system(size: 9, weight: .medium))
            }
            .frame(width: 62, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn ? Color.accentColor.opacity(0.12) : Color.black.opacity(0.03))
            )
            .foregroundColor(isOn ? .accentColor : Color(white: 0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isOn ? Color.accentColor.opacity(0.35) : Color.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorder: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @State private var isRecording: Bool = false
    let inputController: InputController

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? L.pressKey : displayString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isRecording ? .accentColor : Color(white: 0.3))
                    .frame(minWidth: 110)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isRecording ? Color.accentColor.opacity(0.08) : Color.black.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isRecording ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.06), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if keyCode >= 0 {
                Button {
                    keyCode = -1
                    modifiers = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startRecording() {
        isRecording = true
        inputController.onShortcutRecorded = { capturedKeyCode, capturedFlags in
            DispatchQueue.main.async {
                let relevantMask = CGEventFlags.maskControl.rawValue
                    | CGEventFlags.maskShift.rawValue
                    | CGEventFlags.maskCommand.rawValue
                    | CGEventFlags.maskAlternate.rawValue

                if capturedKeyCode == 53 {
                    // Escape cancels recording
                } else {
                    keyCode = Int(capturedKeyCode)
                    modifiers = Int(capturedFlags & relevantMask)
                }
                isRecording = false
            }
        }
        inputController.isRecordingShortcut = true
    }

    private func stopRecording() {
        isRecording = false
        inputController.isRecordingShortcut = false
        inputController.onShortcutRecorded = nil
    }

    private var displayString: String {
        guard keyCode >= 0 else { return L.none }
        var parts: [String] = []
        let flags = UInt64(modifiers)
        if flags & CGEventFlags.maskControl.rawValue != 0 { parts.append("⌃") }
        if flags & CGEventFlags.maskAlternate.rawValue != 0 { parts.append("⌥") }
        if flags & CGEventFlags.maskShift.rawValue != 0 { parts.append("⇧") }
        if flags & CGEventFlags.maskCommand.rawValue != 0 { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ code: Int) -> String {
        let mapping: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
            28: "8", 25: "9", 29: "0",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
            97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12",
            63: "Fn", 179: "🌐",
        ]
        return mapping[code] ?? "Key\(code)"
    }
}
