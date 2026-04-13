// Theme.swift
// GoviKey App
//
// Design tokens and reusable style modifiers.
// Glassmorphism-inspired: frosted cards, soft shadows, large radii.

import SwiftUI

// MARK: - Design Tokens

enum Theme {
    static let cornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 14
    static let itemSpacing: CGFloat = 14
    static let windowWidth: CGFloat = 864
    static let windowHeight: CGFloat = 560
}

// MARK: - Glass Card Style

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(.white.opacity(0.55))
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(.ultraThinMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(white: 0.45))
                .textCase(.uppercase)
                .tracking(0.8)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.55))
            }
        }
        .padding(.leading, 4)
        .padding(.top, 2)
    }
}

// MARK: - Setting Row

struct SettingRow<Content: View>: View {
    let label: String
    let description: String?
    let content: () -> Content

    init(_ label: String, description: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.description = description
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.15))
                if let description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.5))
                }
            }
            Spacer()
            content()
        }
    }
}

// MARK: - Thin Divider

struct ThinDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
    }
}

// MARK: - Summary Banner

/// Shows a quick-read summary of current settings at the top of each tab.
struct SummaryBanner: View {
    let items: [(icon: String, label: String, value: String, color: Color)]

    /// Convenience init with automatic colors per index.
    init(items: [(icon: String, label: String, value: String)]) {
        let palette: [Color] = [
            Color(red: 0.25, green: 0.52, blue: 0.95),  // blue
            Color(red: 0.55, green: 0.36, blue: 0.85),  // purple
            Color(red: 0.18, green: 0.72, blue: 0.53),  // green
            Color(red: 0.92, green: 0.55, blue: 0.20),  // orange
        ]
        self.items = items.enumerated().map { index, item in
            (item.icon, item.label, item.value, palette[index % palette.count])
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(item.color.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(item.color)
                    }
                    Text(item.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(white: 0.5))
                        .textCase(.uppercase)
                        .tracking(0.3)
                    Text(item.value)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(item.color)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(.white.opacity(0.45))
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
    }
}
