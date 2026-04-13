// AppsTab.swift
// GoviKey App
//
// Apps settings tab: custom game bundle ID management.

import SwiftUI

struct AppsTab: View {
    @ObservedObject var settings: UserSettings
    @State private var newBundleId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            SummaryBanner(items: [
                ("gamecontroller.fill", L.gameApps, "\(settings.customGameApps.count)"),
            ])

            SectionHeader(L.gameApps, subtitle: L.gameAppsDescription)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    TextField(L.bundleIdPlaceholder, text: $newBundleId)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        addCustomGame()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newBundleId.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !settings.customGameApps.isEmpty {
                    ThinDivider().padding(.vertical, 12)

                    ForEach(Array(settings.customGameApps.enumerated()), id: \.element) { index, bundleId in
                        if index > 0 {
                            ThinDivider().padding(.vertical, 8)
                        }
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.5))
                                .frame(width: 18)
                            Text(bundleId)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(white: 0.2))
                            Spacer()
                            Button {
                                removeCustomGame(bundleId)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(white: 0.65))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .cardStyle()

            Text(L.gameAppsBuiltIn)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.5))
                .padding(.horizontal, 4)
        }
    }

    private func addCustomGame() {
        let id = newBundleId.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !settings.customGameApps.contains(id) else { return }
        var apps = settings.customGameApps
        apps.append(id)
        settings.customGameApps = apps
        newBundleId = ""
    }

    private func removeCustomGame(_ bundleId: String) {
        var apps = settings.customGameApps
        apps.removeAll { $0 == bundleId }
        settings.customGameApps = apps
    }
}
