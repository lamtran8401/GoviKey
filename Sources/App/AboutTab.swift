// AboutTab.swift
// VietKey App
//
// About tab: app name, version, technical info.

import SwiftUI

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("VietKey")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color(white: 0.15))

            Text(L.vietnameseInputMethod)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.45))

            Text(L.version)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.55))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.04))
                .clipShape(Capsule())

            Spacer().frame(height: 8)

            VStack(spacing: 0) {
                InfoRow(label: L.engine, value: "Telex + VNI")
                ThinDivider().padding(.vertical, 10)
                InfoRow(label: L.platform, value: "macOS 13+")
                ThinDivider().padding(.vertical, 10)
                InfoRow(label: L.architecture, value: "CGEventTap (HID)")
            }
            .cardStyle()
            .frame(maxWidth: 300)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.25))
        }
    }
}
