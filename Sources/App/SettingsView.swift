// SettingsView.swift
// VietKey App
//
// Settings window layout: tab enum, sidebar, content router.

import SwiftUI
import EventTap

// MARK: - Settings Tab

enum SettingsTab: CaseIterable {
    case general
    case input
    case apps
    case about

    var title: String {
        switch self {
        case .general: return L.general
        case .input:   return L.input
        case .apps:    return L.apps
        case .about:   return L.about
        }
    }

    var subtitle: String {
        switch self {
        case .general: return L.generalSummary
        case .input:   return L.inputSummary
        case .apps:    return L.appsSummary
        case .about:   return L.aboutSummary
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .input:   return "keyboard.fill"
        case .apps:    return "app.badge.fill"
        case .about:   return "info.circle.fill"
        }
    }
}

// MARK: - Settings Sidebar

struct SettingsSidebar: View {
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SidebarButton(
                    title: tab.title,
                    subtitle: tab.subtitle,
                    icon: tab.icon,
                    isSelected: navigation.selectedTab == tab
                ) {
                    navigation.selectedTab = tab
                }
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Settings Content

struct SettingsContent: View {
    @ObservedObject var settings: UserSettings
    let inputController: InputController
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        ScrollView {
            Group {
                switch navigation.selectedTab {
                case .general: GeneralTab(settings: settings, inputController: inputController)
                case .input:   InputTab(settings: settings)
                case .apps:    AppsTab(settings: settings)
                case .about:   AboutTab()
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.955), Color(white: 0.935)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

// MARK: - Sidebar Button

struct SidebarButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .accentColor.opacity(0.7) : Color(white: 0.55))
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : Color(white: 0.35))
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
