// GoviKeyApp.swift
// GoviKey
//
// Menu bar application entry point.
// Runs as LSUIElement (no dock icon), provides status bar menu.

import Cocoa
import SwiftUI
import Engine
import EventTap
import ApplicationServices

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
    private var permissionWindow: NSWindow?
    private var permissionTimer: Timer?
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
            showPermissionWindow()
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

        inputSub.addItem(toggleMenuItem(L.autoCapitalize, on: settings.upperCaseFirstChar, action: #selector(toggleUpperCase)))
        if settings.inputType == "telex" {
            inputSub.addItem(toggleMenuItem(L.wKeyAsLetter, on: settings.wKeyAsLetter, action: #selector(toggleWKeyAsLetter)))
        }
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
        guard let button = statusItem.button else { return }
        let isVi = inputController.isVietnameseMode
        button.title = ""
        button.image = menubarIcon(isVietnamese: isVi)
        button.toolTip = isVi ? L.tooltipVietnamese : L.tooltipEnglish
    }

    private func menubarIcon(isVietnamese: Bool) -> NSImage? {
        let name = isVietnamese ? "menubar_vietnamese" : "menubar_english"
        let pointSize = NSSize(width: 16, height: 16)
        let img = NSImage(size: pointSize)

        func addRep(resource: String) {
            guard let url = Bundle.module.url(forResource: resource, withExtension: "png"),
                  let data = try? Data(contentsOf: url),
                  let rep = NSBitmapImageRep(data: data) else { return }
            rep.size = pointSize   // declare logical point size for this rep
            img.addRepresentation(rep)
        }

        addRep(resource: name)           // 18 px → 1× rep
        addRep(resource: "\(name)@2x")   // 36 px → 2× rep

        img.isTemplate = true
        return img
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

    @objc private func toggleUpperCase() {
        settings.upperCaseFirstChar.toggle()
        settings.apply(to: inputController)
    }

    @objc private func toggleWKeyAsLetter() {
        settings.wKeyAsLetter.toggle()
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

    // MARK: - Accessibility Permission

    private func showPermissionWindow() {
        NSApp.setActivationPolicy(.regular)

        let permissionState = PermissionState()
        let view = PermissionView(
            state: permissionState,
            onOpenSettings: { [weak self] in
                self?.openAccessibilitySettings()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            },
            onStart: { [weak self] in
                self?.onPermissionGranted()
            }
        ).preferredColorScheme(.light)

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = L.permissionTitle
        window.styleMask = [.titled, .closable]
        window.appearance = NSAppearance(named: .aqua)
        window.setContentSize(NSSize(width: 440, height: 340))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        permissionWindow = window

        // Poll until permission is granted, then let the user click Start
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak permissionState] _ in
            guard AXIsProcessTrusted() else { return }
            self?.permissionTimer?.invalidate()
            self?.permissionTimer = nil
            DispatchQueue.main.async {
                permissionState?.granted = true
            }
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func onPermissionGranted() {
        permissionWindow?.close()
        permissionWindow = nil
        NSApp.setActivationPolicy(.accessory)

        if !inputController.start() {
            // Permission was granted but tap still failed — show fallback alert
            let alert = NSAlert()
            alert.messageText = L.accessibilityTitle
            alert.informativeText = L.accessibilityMessage
            alert.alertStyle = .warning
            alert.addButton(withTitle: L.quit)
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }
}

// MARK: - Permission Window

final class PermissionState: ObservableObject {
    @Published var granted: Bool = false
}

struct PermissionView: View {
    @ObservedObject var state: PermissionState
    var onOpenSettings: () -> Void
    var onQuit: () -> Void
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }

                Text(L.permissionTitle)
                    .font(.title2).bold()

                Text(L.permissionSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.horizontal, 32)

            // Steps
            VStack(alignment: .leading, spacing: 10) {
                permissionStep(number: "1", text: L.permissionStep1)
                permissionStep(number: "2", text: L.permissionStep2)
                permissionStep(number: "3", text: L.permissionStep3)
            }
            .padding(.top, 20)
            .padding(.horizontal, 32)

            Spacer()

            // Status + Buttons
            VStack(spacing: 10) {
                if state.granted {
                    Label(L.permissionGranted, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline.weight(.medium))

                    Button(L.startGoviKey, action: onStart)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                } else {
                    Label(L.permissionWaiting, systemImage: "clock")
                        .foregroundColor(.secondary)
                        .font(.subheadline)

                    HStack(spacing: 12) {
                        Button(L.quit, action: onQuit)
                            .buttonStyle(.bordered)

                        Button(L.openSystemSettings, action: onOpenSettings)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 440, height: 340)
    }

    private func permissionStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 22, height: 22)
                Text(number)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
