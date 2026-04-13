// Localization.swift
// GoviKey App
//
// Simple string localization for Vietnamese (default) and English.
// Uses a dictionary map for cleaner readability.

import Foundation

enum AppLanguage: String, CaseIterable {
    case vietnamese = "vi"
    case english = "en"

    var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        }
    }
}

// MARK: - Localization Helper

private func loc(_ vi: String, _ en: String) -> String {
    L.current == .vietnamese ? vi : en
}

// MARK: - Localized Strings

enum L {
    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? "vi"
        return AppLanguage(rawValue: raw) ?? .vietnamese
    }

    // MARK: - Menu

    static var typingMode: String        { loc("Chế độ gõ", "Typing Mode") }
    static var vietnamese: String         { loc("Tiếng Việt", "Vietnamese") }
    static var english: String            { loc("Tiếng Anh", "English") }
    static var features: String           { loc("Tính năng", "Features") }
    static var charEncoding: String       { loc("Bảng mã", "Character Encoding") }
    static var charEncodingDescription: String { loc("Bảng mã xuất ký tự tiếng Việt", "Output encoding for Vietnamese characters") }
    static var inputMethod: String        { loc("Bộ gõ", "Input Method") }
    static var method: String             { loc("Phương pháp gõ", "Method") }
    static var inputOptions: String       { loc("Tùy chọn nhập", "Input Options") }
    static var quickTelex: String         { loc("Gõ nhanh (Quick Telex)", "Quick Telex") }
    static var autoCapitalize: String     { loc("Viết hoa đầu câu", "Auto Capitalize") }
    static var freeMark: String           { loc("Phụ âm Z, F, W, J", "Free Mark (Z, F, W, J)") }
    static var quickStartConsonant: String { loc("Phụ âm đầu nhanh", "Quick Start Consonant") }
    static var quickEndConsonant: String  { loc("Phụ âm cuối nhanh", "Quick End Consonant") }
    static var spelling: String           { loc("Chính tả", "Spelling") }
    static var spellingCheck: String      { loc("Kiểm tra chính tả", "Spelling Check") }
    static var modernOrthography: String  { loc("Chính tả mới (oà, uý)", "Modern Orthography") }
    static var gameMode: String           { "Game Mode" }
    static var aboutGoviKey: String       { loc("Về GoviKey", "About GoviKey") }

    // MARK: - Sound & Shortcuts

    static var switchSound: String        { loc("Âm thanh chuyển đổi", "Switch Sound") }
    static var switchSoundDescription: String { loc("Phát âm khi chuyển chế độ gõ", "Play sound when switching input mode") }
    static var shortcut: String           { loc("Phím tắt", "Shortcut") }
    static var shortcutDescription: String { loc("Phím tắt chuyển đổi chế độ gõ", "Shortcut to toggle input mode") }
    static var primaryShortcut: String    { loc("Phím tắt chính", "Primary Shortcut") }
    static var secondaryShortcut: String  { loc("Phím tắt phụ", "Secondary Shortcut") }
    static var none: String               { loc("Không", "None") }
    static var modifierOnlyHint: String   { loc("Bấm và thả tổ hợp phím để chuyển đổi", "Press and release modifier combo to switch") }
    static var pressKey: String           { loc("Nhấn phím...", "Press a key...") }
    static var settings: String           { loc("Cài đặt...", "Settings...") }
    static var quitGoviKey: String        { loc("Thoát GoviKey", "Quit GoviKey") }

    // MARK: - Status Bar

    static var tooltipVietnamese: String  { loc("GoviKey - Tiếng Việt", "GoviKey - Vietnamese") }
    static var tooltipEnglish: String     { loc("GoviKey - Tiếng Anh", "GoviKey - English") }

    // MARK: - Settings Window

    static var settingsTitle: String      { loc("Cài đặt GoviKey", "GoviKey Settings") }
    static var general: String            { loc("Chung", "General") }
    static var input: String              { loc("Nhập liệu", "Input") }
    static var apps: String               { loc("Ứng dụng", "Apps") }
    static var about: String              { loc("Giới thiệu", "About") }
    static var generalSummary: String     { loc("Ngôn ngữ, phím tắt, âm thanh", "Language, shortcuts, sound") }
    static var inputSummary: String       { loc("Telex, VNI, chính tả", "Telex, VNI, spelling") }
    static var appsSummary: String        { loc("Danh sách game", "Game app list") }
    static var aboutSummary: String       { loc("Phiên bản, thông tin", "Version, info") }
    static var language: String           { loc("Ngôn ngữ", "Language") }
    static var appLanguage: String        { loc("Ngôn ngữ ứng dụng", "App Language") }
    static var appLanguageDescription: String { loc("Ngôn ngữ hiển thị của GoviKey", "Display language for GoviKey") }
    static var gameModeDescription: String { loc("Độ trễ tối thiểu, bỏ qua kiểm tra Spotlight/AX", "Minimal latency, skips Spotlight/AX checks") }
    static var inputMethodLabel: String   { loc("Phương pháp", "Method") }

    // MARK: - Input Descriptions

    static var quickTelexDescription: String { loc("Mở rộng phụ âm (ví dụ: cc -> ch)", "Expand consonant shortcuts (e.g. cc -> ch)") }
    static var autoCapitalizeDescription: String { loc("Viết hoa ký tự đầu câu", "Uppercase first character of sentences") }
    static var freeMarkDescription: String { loc("Cho phép dấu thanh không cần nguyên âm", "Allow tone/mark keys without vowels") }
    static var quickStartConsonantDescription: String { loc("Mở rộng phụ âm đầu nhanh", "Expand start consonant shortcuts") }
    static var quickEndConsonantDescription: String { loc("Mở rộng phụ âm cuối nhanh", "Expand end consonant shortcuts") }
    static var spellingCheckDescription: String { loc("Kiểm tra cấu trúc từ tiếng Việt", "Validate Vietnamese word structure") }
    static var modernOrthographyDescription: String { loc("Đặt dấu theo kiểu mới (ví dụ: hoàng)", "Use modern tone placement (e.g. hoàng)") }

    // MARK: - Apps Tab

    static var gameApps: String           { loc("Ứng dụng Game", "Game Apps") }
    static var gameAppsDescription: String { loc("Ứng dụng sử dụng chế độ nhanh (không AX API, độ trễ tối thiểu)", "Apps that use the fast path (no AX API, minimal latency)") }
    static var bundleIdPlaceholder: String { loc("Bundle ID (ví dụ: com.riotgames.lol)", "Bundle ID (e.g. com.riotgames.lol)") }
    static var add: String                { loc("Thêm", "Add") }
    static var gameAppsBuiltIn: String    { loc(
        "Tự động nhận diện Riot Games, Blizzard, Steam, Epic, EA, Ubisoft, v.v. Thêm Bundle ID tùy chỉnh cho game chưa được nhận diện.",
        "Built-in game detection covers Riot Games, Blizzard, Steam, Epic, EA, Ubisoft, and more. Add custom bundle IDs here for any game not auto-detected."
    ) }

    // MARK: - About Tab

    static var vietnameseInputMethod: String { loc("Bộ gõ tiếng Việt cho macOS", "Vietnamese Input Method for macOS") }
    static var version: String            { loc("Phiên bản 1.0.0", "Version 1.0.0") }
    static var engine: String             { loc("Bộ gõ", "Engine") }
    static var platform: String           { loc("Nền tảng", "Platform") }
    static var architecture: String       { loc("Kiến trúc", "Architecture") }

    // MARK: - Accessibility Alert

    static var accessibilityTitle: String { loc("GoviKey cần quyền Accessibility", "GoviKey Needs Accessibility Permission") }
    static var accessibilityMessage: String { loc(
        "GoviKey cần quyền Accessibility để nhận phím gõ tiếng Việt.\n\nVui lòng cấp quyền trong Cài đặt hệ thống > Quyền riêng tư & Bảo mật > Accessibility, sau đó khởi động lại GoviKey.",
        "GoviKey needs Accessibility access to intercept keystrokes for Vietnamese typing.\n\nPlease grant access in System Settings > Privacy & Security > Accessibility, then restart GoviKey."
    ) }
    static var openSystemSettings: String { loc("Mở Cài đặt hệ thống", "Open System Settings") }
    static var quit: String               { loc("Thoát", "Quit") }
}
