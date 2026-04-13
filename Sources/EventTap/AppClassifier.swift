// AppClassifier.swift
// GoviKey EventTap
//
// App detection and classification by bundle ID.
// Uses BundlePatternSet for exact + wildcard prefix matching.
// Cached on app switch via NSWorkspace notification.

import AppKit

// MARK: - Bundle Pattern Matching

struct BundlePatternSet {
    private let exact: Set<String>
    private let wildcardPrefixes: [String]

    init(_ patterns: [String]) {
        var exact = Set<String>()
        var wildcardPrefixes: [String] = []
        for pattern in patterns {
            let normalized = pattern.lowercased()
            if normalized.hasSuffix("*") {
                wildcardPrefixes.append(String(normalized.dropLast()))
            } else {
                exact.insert(normalized)
            }
        }
        self.exact = exact
        self.wildcardPrefixes = wildcardPrefixes
    }

    func contains(_ bundleId: String?) -> Bool {
        guard let id = bundleId?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty else { return false }
        if exact.contains(id) { return true }
        for prefix in wildcardPrefixes where id.hasPrefix(prefix) {
            return true
        }
        return false
    }
}

// MARK: - App Category

public enum AppCategory {
    case normal
    case browser
    case terminal
    case spotlightLike
    case game
}

// MARK: - AppClassifier

public final class AppClassifier {

    public static let shared = AppClassifier()

    // MARK: - Pattern Sets

    private let browserApps = BundlePatternSet([
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.Safari.WebApp.*",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "app.zen-browser.zen",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.dev",
        "com.google.Chrome.beta",
        "org.chromium.Chromium",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Beta",
        "com.microsoft.Edge",
        "com.microsoft.Edge.Dev",
        "com.thebrowser.Browser",
        "company.thebrowser.Browser",
        "company.thebrowser.dia",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "com.coccoc.browser",
        "com.duckduckgo.macos.browser",
        "com.kagi.kagimacOS",
        "ai.perplexity.comet",
        "com.google.Chrome.app.*",
        "com.brave.Browser.app.*",
        "com.microsoft.edgemac.app.*",
        "com.microsoft.Edge.app.*",
        "org.chromium.Chromium.app.*",
        "com.vivaldi.Vivaldi.app.*",
        "com.operasoftware.Opera.app.*",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.electron.discord",
        "com.figma.Desktop",
        "com.linear",
        "md.obsidian",
    ])

    private let terminalApps = BundlePatternSet([
        "com.apple.Terminal",
        "io.alacritty",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.raphaelamorim.rio",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "org.tabby",
        "com.termius-dmg.mac",
    ])

    private let spotlightLikeApps = BundlePatternSet([
        "com.apple.Spotlight",
        "com.apple.systemuiserver",
        "com.raycast.*",
        "com.alfredapp.Alfred",
        "com.apple.launchpad",
    ])

    private let gameApps = BundlePatternSet([
        // Riot Games (LOL, TFT, Valorant)
        "com.riotgames.*",
        "com.leagueoflegends.*",
        "com.riotgames.LeagueofLegends.*",
        // Blizzard (WoW, Diablo, Overwatch, SC2)
        "com.blizzard.*",
        "com.blizzard.worldofwarcraft",
        "com.blizzard.diablo*",
        "com.blizzard.starcraft2",
        "com.blizzard.Overwatch",
        // Steam / Valve
        "com.valvesoftware.*",
        "com.valvesoftware.steam",
        "com.valvesoftware.dota2",
        "com.valvesoftware.csgo",
        "com.valvesoftware.cs2",
        // Epic Games
        "com.epicgames.*",
        // Mojang (Minecraft)
        "com.mojang.*",
        "com.mojang.minecraftlauncher",
        // EA
        "com.ea.*",
        "com.electronicarts.*",
        // Ubisoft
        "com.ubisoft.*",
        // Activision
        "com.activision.*",
        // Unity games (common prefix)
        "com.unity.*",
        // Genshin Impact
        "com.mihoyo.*",
        "com.hoyoverse.*",
        // Roblox
        "com.roblox.*",
        // Other popular macOS games
        "com.supergiantgames.*",
        "com.innersloth.amongus",
        "com.Respawn.*",
    ])

    /// User-configurable bundle IDs treated as games.
    private var customGameBundleIds: Set<String> = []

    private let safariApps = BundlePatternSet([
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.Safari.WebApp.*",
    ])

    private let stepByStepApps = BundlePatternSet([
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.alfredapp.Alfred",
        "com.apple.launchpad",
        "notion.id",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.Safari.WebApp.*",
    ])

    private init() {}

    // MARK: - Custom Game List

    /// Add a bundle ID to the user-configurable game list.
    public func addCustomGame(_ bundleId: String) {
        customGameBundleIds.insert(bundleId.lowercased())
    }

    /// Remove a bundle ID from the user-configurable game list.
    public func removeCustomGame(_ bundleId: String) {
        customGameBundleIds.remove(bundleId.lowercased())
    }

    /// Set the full custom game list (e.g. from UserDefaults).
    public func setCustomGames(_ bundleIds: [String]) {
        customGameBundleIds = Set(bundleIds.map { $0.lowercased() })
    }

    // MARK: - Classification

    public func classify(_ bundleId: String?) -> AppCategory {
        if isGame(bundleId) { return .game }
        if spotlightLikeApps.contains(bundleId) { return .spotlightLike }
        if terminalApps.contains(bundleId) { return .terminal }
        if browserApps.contains(bundleId) { return .browser }
        return .normal
    }

    public func isBrowser(_ bundleId: String?) -> Bool {
        browserApps.contains(bundleId)
    }

    public func isSafari(_ bundleId: String?) -> Bool {
        safariApps.contains(bundleId)
    }

    public func isGame(_ bundleId: String?) -> Bool {
        if gameApps.contains(bundleId) { return true }
        guard let id = bundleId?.lowercased() else { return false }
        return customGameBundleIds.contains(id)
    }

    public func isSpotlightLike(_ bundleId: String?) -> Bool {
        spotlightLikeApps.contains(bundleId)
    }

    public func isTerminal(_ bundleId: String?) -> Bool {
        terminalApps.contains(bundleId)
    }

    public func needsStepByStep(_ bundleId: String?) -> Bool {
        stepByStepApps.contains(bundleId)
    }
}

// MARK: - ActiveAppMonitor

/// Monitors the active (frontmost) application via NSWorkspace notifications.
/// Caches the bundle ID to avoid repeated lookups on every keystroke.
public final class ActiveAppMonitor {

    public private(set) var bundleId: String?
    public private(set) var category: AppCategory = .normal

    private let classifier = AppClassifier.shared

    public init() {}

    /// Start monitoring app switches. Call once at startup.
    public func start() {
        // Set initial state
        updateFromFrontmost()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    public func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appDidActivate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            bundleId = app.bundleIdentifier
        } else {
            updateFromFrontmost()
        }
        category = classifier.classify(bundleId)
    }

    private func updateFromFrontmost() {
        bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        category = classifier.classify(bundleId)
    }
}
