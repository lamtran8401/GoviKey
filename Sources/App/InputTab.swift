// InputTab.swift
// GoviKey App
//
// Input settings tab: character encoding, input method, options, spelling.

import SwiftUI
import Engine

struct InputTab: View {
    @ObservedObject var settings: UserSettings

    private var methodDisplay: String {
        settings.inputType == "vni" ? "VNI" : "Telex"
    }

    private var encodingDisplay: String {
        (CharacterEncoding(rawValue: settings.charEncoding) ?? .unicode).displayName
    }

    private var isTelex: Bool { settings.inputType != "vni" }

    private var optionsCount: Int {
        let wActive = isTelex && settings.wKeyAsLetter
        return [settings.upperCaseFirstChar, wActive,
                settings.quickStartConsonant, settings.quickEndConsonant].filter { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            SummaryBanner(items: [
                ("character.book.closed.fill", L.charEncoding, encodingDisplay),
                ("keyboard.fill", L.method, methodDisplay),
                ("slider.horizontal.3", L.inputOptions, "\(optionsCount)/4"),
                ("checkmark.seal.fill", L.spellingCheck, settings.checkSpelling ? "ON" : "OFF"),
            ])

            SectionHeader(L.charEncoding)

            SettingRow(L.charEncoding, description: L.charEncodingDescription) {
                Picker("", selection: Binding<Int>(
                    get: { settings.charEncoding },
                    set: { settings.charEncoding = $0 }
                )) {
                    Text("Unicode").tag(0)
                    Text("TCVN3 (ABC)").tag(1)
                    Text("VNI Windows").tag(2)
                    Text("Unicode Compound").tag(3)
                    Text("CP1258").tag(4)
                }
                .labelsHidden()
                .frame(width: 180)
            }
            .cardStyle()

            SectionHeader(L.inputMethod)

            SettingRow(L.inputMethodLabel) {
                Picker("", selection: $settings.inputType) {
                    Text("Telex").tag("telex")
                    Text("VNI").tag("vni")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .cardStyle()

            SectionHeader(L.inputOptions)

            VStack(spacing: 0) {
                SettingRow(L.autoCapitalize, description: L.autoCapitalizeDescription) {
                    Toggle("", isOn: $settings.upperCaseFirstChar)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                ThinDivider().padding(.vertical, 12)

                SettingRow(L.wKeyAsLetter, description: L.wKeyAsLetterDescription) {
                    Toggle("", isOn: $settings.wKeyAsLetter)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                ThinDivider().padding(.vertical, 12)

                SettingRow(L.quickStartConsonant, description: L.quickStartConsonantDescription) {
                    Toggle("", isOn: $settings.quickStartConsonant)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                ThinDivider().padding(.vertical, 12)

                SettingRow(L.quickEndConsonant, description: L.quickEndConsonantDescription) {
                    Toggle("", isOn: $settings.quickEndConsonant)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .cardStyle()

            SectionHeader(L.spelling)

            VStack(spacing: 0) {
                SettingRow(L.spellingCheck, description: L.spellingCheckDescription) {
                    Toggle("", isOn: $settings.checkSpelling)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                ThinDivider().padding(.vertical, 12)

                SettingRow(L.modernOrthography, description: L.modernOrthographyDescription) {
                    Toggle("", isOn: $settings.useModernOrthography)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .cardStyle()
        }
    }
}
