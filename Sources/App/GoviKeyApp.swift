// GoviKeyApp.swift
// GoviKey
//
// Menu bar application entry point.
// Runs as LSUIElement (no dock icon), provides status bar menu.

import Cocoa
import SwiftUI
import Engine
import EventTap

@main
struct GoviKeyApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private var statusItem: NSStatusItem!
    private let inputController = InputController()
    private let settings = UserSettings()
    private var settingsWindow: NSWindow?
    private var settingsObserver: Any?
    private var cachedMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.apply(to: inputController)
        setupStatusBar()

        // Language switch callback (called from CGEventTap thread)
        inputController.onLanguageSwitch = { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusIcon()
                self?.rebuildMenu()
                self?.playSwitchSound()
            }
        }

        if !inputController.start() {
            showAccessibilityAlert()
        }

        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.settings.apply(to: self.inputController)
            self.rebuildMenu()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        inputController.stop()
        if let obs = settingsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()

        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let isVi = inputController.isVietnameseMode

        let viItem = NSMenuItem(title: L.vietnamese, action: #selector(selectVietnamese), keyEquivalent: "")
        viItem.state = isVi ? .on : .off
        viItem.image = sfSymbol("v.circle")
        menu.addItem(viItem)

        let enItem = NSMenuItem(title: L.english, action: #selector(selectEnglish), keyEquivalent: "")
        enItem.state = isVi ? .off : .on
        enItem.image = sfSymbol("e.circle")
        menu.addItem(enItem)

        menu.addItem(NSMenuItem.separator())

        // Bảng mã submenu
        let encodingItem = NSMenuItem(title: L.charEncoding, action: nil, keyEquivalent: "")
        encodingItem.image = sfSymbol("character.book.closed.fill")
        let encodingSub = NSMenu()
        for enc in CharacterEncoding.allCases {
            let item = NSMenuItem(title: enc.displayName, action: #selector(selectEncoding(_:)), keyEquivalent: "")
            item.tag = enc.rawValue
            item.state = settings.charEncoding == enc.rawValue ? .on : .off
            encodingSub.addItem(item)
        }
        encodingItem.submenu = encodingSub
        menu.addItem(encodingItem)

        // Bộ gõ submenu
        let inputItem = NSMenuItem(title: L.inputMethod, action: nil, keyEquivalent: "")
        inputItem.image = sfSymbol("keyboard.fill")
        let inputSub = NSMenu()

        let telexItem = NSMenuItem(title: "Telex", action: #selector(selectTelex), keyEquivalent: "")
        telexItem.state = settings.inputType == "telex" ? .on : .off
        inputSub.addItem(telexItem)

        let vniItem = NSMenuItem(title: "VNI", action: #selector(selectVNI), keyEquivalent: "")
        vniItem.state = settings.inputType == "vni" ? .on : .off
        inputSub.addItem(vniItem)

        inputSub.addItem(NSMenuItem.separator())

        inputSub.addItem(toggleMenuItem(L.quickTelex, on: settings.quickTelex, action: #selector(toggleQuickTelex)))
        inputSub.addItem(toggleMenuItem(L.autoCapitalize, on: settings.upperCaseFirstChar, action: #selector(toggleUpperCase)))
        inputSub.addItem(toggleMenuItem(L.freeMark, on: settings.freeMark, action: #selector(toggleFreeMark)))
        inputSub.addItem(toggleMenuItem(L.quickStartConsonant, on: settings.quickStartConsonant, action: #selector(toggleQuickStartConsonant)))
        inputSub.addItem(toggleMenuItem(L.quickEndConsonant, on: settings.quickEndConsonant, action: #selector(toggleQuickEndConsonant)))

        inputSub.addItem(NSMenuItem.separator())

        inputSub.addItem(toggleMenuItem(L.spellingCheck, on: settings.checkSpelling, action: #selector(toggleSpelling)))
        inputSub.addItem(toggleMenuItem(L.modernOrthography, on: settings.useModernOrthography, action: #selector(toggleModernOrtho)))

        inputItem.submenu = inputSub
        menu.addItem(inputItem)

        menu.addItem(toggleMenuItem("Game Mode", on: settings.forceGameMode, action: #selector(toggleGameMode), icon: "gamecontroller"))

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: L.settings, action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: L.aboutGoviKey, action: #selector(openAbout), keyEquivalent: "")
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: L.quitGoviKey, action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        self.cachedMenu = menu
    }

    @objc private func statusItemClicked() {
        rebuildMenu()
        guard let menu = cachedMenu else { return }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { self.statusItem.menu = nil }
    }

    // MARK: - Menu Helpers

    private func toggleMenuItem(_ title: String, on: Bool, action: Selector, icon: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.state = on ? .on : .off
        if let icon { item.image = sfSymbol(icon) }
        return item
    }

    private func sfSymbol(_ name: String) -> NSImage? {
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        img?.size = NSSize(width: 16, height: 16)
        return img
    }

    private func updateStatusIcon() {
        if let button = statusItem.button {
            let isVi = inputController.isVietnameseMode
            button.title = isVi ? "Vi" : "En"
            button.toolTip = isVi ? L.tooltipVietnamese : L.tooltipEnglish
        }
    }

    // MARK: - Switch Sound

    private func playSwitchSound() {
        guard settings.switchSound else { return }
        guard let sound = NSSound(named: "Pop") else { return }
        sound.volume = Float(settings.switchSoundVolume)
        sound.play()
    }

    // MARK: - Actions

    @objc private func selectVietnamese() {
        if !inputController.isVietnameseMode {
            inputController.toggleLanguage()
        }
        updateStatusIcon()
        rebuildMenu()
    }

    @objc private func selectEnglish() {
        if inputController.isVietnameseMode {
            inputController.toggleLanguage()
        }
        updateStatusIcon()
        rebuildMenu()
    }

    @objc private func selectEncoding(_ sender: NSMenuItem) {
        settings.charEncoding = sender.tag
        settings.apply(to: inputController)
        inputController.engine.resetSession()
    }

    @objc private func selectTelex() {
        settings.inputType = "telex"
        settings.apply(to: inputController)
        inputController.engine.resetSession()
    }

    @objc private func selectVNI() {
        settings.inputType = "vni"
        settings.apply(to: inputController)
        inputController.engine.resetSession()
    }

    @objc private func toggleSpelling() {
        settings.checkSpelling.toggle()
        settings.apply(to: inputController)
    }

    @objc private func toggleModernOrtho() {
        settings.useModernOrthography.toggle()
        settings.apply(to: inputController)
    }

    @objc private func toggleGameMode() {
        settings.forceGameMode.toggle()
        settings.apply(to: inputController)
    }

    @objc private func toggleQuickTelex() {
        settings.quickTelex.toggle()
        settings.apply(to: inputController)
    }

    @objc private func toggleUpperCase() {
        settings.upperCaseFirstChar.toggle()
        settings.apply(to: inputController)
    }

    @objc private func toggleFreeMark() {
        settings.freeMark.toggle()
        settings.apply(to: inputController)
    }

    @objc private func toggleQuickStartConsonant() {
        settings.quickStartConsonant.toggle()
        settings.apply(to: inputController)
    }

    @objc private func toggleQuickEndConsonant() {
        settings.quickEndConsonant.toggle()
        settings.apply(to: inputController)
    }

    @objc private func openAbout() {
        NSApp.setActivationPolicy(.regular)

        let aboutView = AboutTab().preferredColorScheme(.light)

        let hostingController = NSHostingController(rootView: aboutView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = L.aboutGoviKey
        window.styleMask = [.titled, .closable]
        window.appearance = NSAppearance(named: .aqua)
        window.setContentSize(NSSize(width: 320, height: 300))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.orderFrontRegardless()

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)

        if let window = settingsWindow, window.isVisible {
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let splitVC = SettingsSplitViewController(settings: settings, inputController: inputController)

        let window = NSWindow(contentViewController: splitVC)
        window.title = ""
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        let toolbar = NSToolbar(identifier: "settingsToolbar")
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: .aqua)
        window.setContentSize(NSSize(width: Theme.windowWidth, height: Theme.windowHeight))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.orderFrontRegardless()

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func quitApp() {
        inputController.stop()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Revert to accessory (no dock icon) when settings window closes
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Accessibility

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = L.accessibilityTitle
        alert.informativeText = L.accessibilityMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.openSystemSettings)
        alert.addButton(withTitle: L.quit)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Settings Navigation State

/// Shared state between sidebar and content so both react to tab changes.
final class SettingsNavigation: ObservableObject {
    @Published var selectedTab: SettingsTab = .general
}

// MARK: - Settings Split View Controller

/// Uses NSSplitViewController so macOS natively renders the titlebar
/// translucent over the sidebar.
final class SettingsSplitViewController: NSSplitViewController {

    private let settings: UserSettings
    private let inputController: InputController
    private let navigation = SettingsNavigation()

    init(settings: UserSettings, inputController: InputController) {
        self.settings = settings
        self.inputController = inputController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Sidebar — shares navigation state
        let sidebarVC = NSHostingController(rootView:
            SettingsSidebar(navigation: navigation)
                .preferredColorScheme(.light)
        )
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = 204
        sidebarItem.maximumThickness = 204
        addSplitViewItem(sidebarItem)

        // Content — shares same navigation state
        let contentVC = NSHostingController(rootView:
            SettingsContent(settings: settings, inputController: inputController, navigation: navigation)
                .preferredColorScheme(.light)
        )
        let contentItem = NSSplitViewItem(viewController: contentVC)
        addSplitViewItem(contentItem)
    }
}
