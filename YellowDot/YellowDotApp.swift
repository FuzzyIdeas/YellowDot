//
//  YellowDotApp.swift
//  YellowDot
//
//  Created by Alin Panaitiu on 21.12.2021.
//

import Combine
import Defaults
import LaunchAtLogin
import SwiftUI

let cid = CGSMainConnectionID()
let WM = WindowManager()

extension Defaults.Keys {
    static let showMenubarIcon = Key<Bool>("showMenubarIcon", default: true)
    static let indicatorColor = Key<DotColor>("indicatorColor", default: DotColor.dim)
    static let dotColor = Key<DotColor>("dotColor", default: DotColor.adaptive)
    static let launchCount = Key<Int>("launchCount", default: 0)
}

struct WindowInfo {
    var bounds: CGRect // "kCGWindowBounds"
    var memoryUsage: Int // "kCGWindowMemoryUsage"
    var alpha: Int // "kCGWindowAlpha"
    var sharingState: Int // "kCGWindowSharingState"
    var number: Int // "kCGWindowNumber"
    var ownerName: String // "kCGWindowOwnerName"
    var storeType: Int // "kCGWindowStoreType"
    var layer: Int // "kCGWindowLayer"
    var ownerPID: Int // "kCGWindowOwnerPID"
    var isOnscreen: Int // "kCGWindowIsOnscreen"
    var name: String // "kCGWindowName"
    var screen: String? // "display uuid"
    var space: Int? // "space number"

    var isControlCenterColoredIcon: Bool {
        COLORED_MENUBAR_ICON_NAMES.contains(name)
            && CONTROL_CENTER_NAMES.contains(ownerName)
    }
    var isDot: Bool {
        name == "StatusIndicator"
    }

    static func fromInfoDict(_ dict: [String: Any]) -> WindowInfo {
        var rect = CGRect.zero
        if let bounds = dict["kCGWindowBounds"] as? [String: CGFloat],
           let x = bounds["X"], let y = bounds["Y"],
           let width = bounds["Width"], let height = bounds["Height"]
        {
            rect = CGRect(x: x, y: y, width: width, height: height)
        }

        let id = (dict["kCGWindowNumber"] as? Int) ?? 0
        let screen = CGSCopyManagedDisplayForWindow(cid, id)?.takeRetainedValue() as String?
        return WindowInfo(
            bounds: rect,
            memoryUsage: (dict["kCGWindowMemoryUsage"] as? Int) ?? 0,
            alpha: (dict["kCGWindowAlpha"] as? Int) ?? 0,
            sharingState: (dict["kCGWindowSharingState"] as? Int) ?? 0,
            number: id,
            ownerName: (dict["kCGWindowOwnerName"] as? String) ?? "",
            storeType: (dict["kCGWindowStoreType"] as? Int) ?? 0,
            layer: (dict["kCGWindowLayer"] as? Int) ?? 0,
            ownerPID: (dict["kCGWindowOwnerPID"] as? Int) ?? 0,
            isOnscreen: (dict["kCGWindowIsOnscreen"] as? Int) ?? 0,
            name: (dict["kCGWindowName"] as? String) ?? "",
            screen: screen,
            space: CGSManagedDisplayGetCurrentSpace(cid, screen as CFString?)
        )
    }
}

let CONTROL_CENTER_NAMES: Set<String> = [
    "Control Center",
    "Control Centre",
    "مركز التحكم",
    "Centre de control",
    "Ovládací centrum",
    "Kontrolcenter",
    "Kontrollzentrum",
    "Κέντρο ελέγχου",
    "Centro de control",
    "Ohjauskeskus",
    "Centre de contrôle",
    "מרכז הבקרה",
    "कंट्रोल सेंटर",
    "Kontrolni centar",
    "Vezérlőközpont",
    "Pusat Kontrol",
    "Centro di Controllo",
    "コントロールセンター",
    "제어 센터",
    "Pusat Kawalan",
    "Bedieningspaneel",
    "Kontrollsenter",
    "Centrum sterowania",
    "Central de Controle",
    "Central de controlo",
    "Centru de control",
    "Пункт управления",
    "Ovládacie centrum",
    "Kontrollcenter",
    "ศูนย์ควบคุม",
    "Denetim Merkezi",
    "Центр керування",
    "Trung tâm điều khiển",
    "控制中心",
]

let COLORED_MENUBAR_ICON_NAMES: Set<String> = [
    "AudioVideoModule",
    "عناصر التحكم في الصوت والفيديو",
    "Controls d’àudio i de vídeo",
    "Ovládání zvuku a videa",
    "Lyd- og videoindstillinger",
    "Audio- und Videosteuerung",
    "Στοιχεία ελέγχου ήχου και βίντεο",
    "Audio and Video Controls",
    "Audio and Video Controls",
    "Audio and Video Controls",
    "Controles de audio y vídeo",
    "Controles de audio y video",
    "Ääni- ja videosäätimet",
    "Commandes audio et vidéo",
    "Contrôles audio et vidéo",
    "פקדי שמע ווידאו",
    "ऑडियो और वीडियो कंट्रोल",
    "Audio i video kontrole",
    "Hang- és videóvezérlők",
    "Kontrol Audio dan Video",
    "Controlli audio e video",
    "オーディオとビデオのコントロール",
    "오디오 및 비디오 제어",
    "Kawalan Audio dan Video",
    "Audio- en videoregelaars",
    "Lyd- og videokontroller",
    "Narzędzia audio i wideo",
    "Controles de Áudio e Vídeo",
    "Controlos de áudio e vídeo",
    "Comenzi audio și video",
    "Элементы управления аудио и видео",
    "Ovládanie audia a videa",
    "Ljud- och videoreglage",
    "ตัวควบคุมเสียงและวิดีโอ",
    "Ses ile Video Denetimleri",
    "Елементи керування звуком і відео",
    "Điều khiển âm thanh và video",
    "音频和视频控制",
    "音訊和影片控制項目",
    "音訊和影片控制項目",
]

func getWindows() -> [WindowInfo] {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
    let infoList = windowsListInfo as! [[String: Any]]

    let dicts = infoList.filter { w in
        guard let name = w["kCGWindowName"] as? String else {
            return false
        }

        return name == "StatusIndicator"
            || name == "Menubar"
            || (
                COLORED_MENUBAR_ICON_NAMES.contains(name)
                    && CONTROL_CENTER_NAMES.contains((w["kCGWindowOwnerName"] as? String) ?? "")
            )
    }

    return dicts.map { WindowInfo.fromInfoDict($0) }
}

@MainActor var windows: [WindowInfo] = []

@MainActor func setWindowBrightness(color: DotColor, predicate: (WindowInfo) -> Bool) {
    let windows = windows.filter(predicate)
    guard !windows.isEmpty else {
        return
    }

    #if DEBUG
        for window in windows {
            print(window)
        }
    #endif

    for window in windows {
        var ids = [window.number]
        var brightnesses: [Float] = [color.brightness(window: window)]
        CGSSetWindowListBrightness(cid, &ids, &brightnesses, Int32(1))
    }
}

func pub<T: Equatable>(_ key: Defaults.Key<T>) -> Publishers.Filter<Publishers.RemoveDuplicates<Publishers.Drop<AnyPublisher<Defaults.KeyChange<T>, Never>>>> {
    Defaults.publisher(key).dropFirst().removeDuplicates().filter { $0.oldValue != $0.newValue }
}

class WindowManager: ObservableObject {
    @Published var windowToOpen: String? = nil

    func open(_ window: String) {
        windowToOpen = window
    }
}

func mainActor(_ action: @escaping @MainActor () -> Void) {
    Task.init { await MainActor.run { action() }}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var instance: AppDelegate!

    var application = NSApplication.shared
    var observers: Set<AnyCancellable> = []
    var dotHider: Timer?
    var windowFetcher: Timer?

    func application(_ application: NSApplication, open urls: [URL]) {
        WM.open("settings")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !firstAppActive else {
            firstAppActive = false
            return
        }
        WM.open("settings")
    }

    @MainActor func initDotHider(timeInterval: TimeInterval) {
        setWindowBrightness(color: Defaults[.dotColor]) { $0.isDot }
        setWindowBrightness(color: Defaults[.indicatorColor]) { $0.isControlCenterColoredIcon }

        windowFetcher?.invalidate()
        dotHider?.invalidate()

        windowFetcher = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            mainActor { windows = getWindows() }
        }
        dotHider = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            let dotColor = Defaults[.dotColor]
            guard dotColor != .default else { return }
            let indicatorColor = Defaults[.indicatorColor]
            mainActor {
                setWindowBrightness(color: dotColor) { $0.isDot }
                setWindowBrightness(color: indicatorColor) { $0.isControlCenterColoredIcon }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        Defaults[.launchCount] += 1

        if !CGPreflightScreenCaptureAccess(), Defaults[.indicatorColor] != .default {
            let alert = NSAlert()
            alert.messageText = "Enable menubar icon dimming?"
            alert.informativeText = "To dim the orange/purple/green menubar icons for microphone, screencapture and FaceTime, the app needs to ask for Screen Recording permissions."
            alert.addButton(withTitle: "Yes")
            alert.addButton(withTitle: "No")
            alert.alertStyle = .informational
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                CGRequestScreenCaptureAccess()
            } else {
                Defaults[.indicatorColor] = .default
            }
        }

        initDotHider(timeInterval: 1)

        pub(.dotColor).sink { dotColor in
            setWindowBrightness(color: dotColor.newValue) { $0.isDot }
        }.store(in: &observers)
        pub(.indicatorColor).sink { indicatorColor in
            CGRequestScreenCaptureAccess()
            setWindowBrightness(color: indicatorColor.newValue) { $0.isControlCenterColoredIcon }
        }.store(in: &observers)

        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeMainNotification), name: NSWindow.didBecomeMainNotification, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window.title == "YellowDot Settings" {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc func windowDidBecomeMainNotification(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window.title == "YellowDot Settings" {
            NSApp.setActivationPolicy(.regular)
        }
    }

    private var firstAppActive = true
}

extension NSAppearance {
    var isDark: Bool { name == .vibrantDark || name == .darkAqua }
    var isLight: Bool { !isDark }
    static var dark: NSAppearance? { NSAppearance(named: .darkAqua) }
    static var light: NSAppearance? { NSAppearance(named: .aqua) }
    static var vibrantDark: NSAppearance? { NSAppearance(named: .vibrantDark) }
    static var vibrantLight: NSAppearance? { NSAppearance(named: .vibrantLight) }
}

func statusBarAppearance(screen: String?) -> NSAppearance? {
    guard let screen else {
        return NSApp.windows.first(where: { $0.className == "NSStatusBarWindow" })?.effectiveAppearance ?? .light
    }

    return NSApp.windows
        .first(where: { $0.className == "NSStatusBarWindow" && $0.screen?.uuid == screen })?
        .effectiveAppearance ?? .light
}

extension NSScreen {
    var id: CGDirectDisplayID? {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDirectDisplayID(id.uint32Value)
    }
    var uuid: String {
        guard let id, let uuid = CGDisplayCreateUUIDFromDisplayID(id) else { return "" }
        let uuidValue = uuid.takeRetainedValue()
        let uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidValue) as String
        return uuidString
    }
}

enum DotColor: String, Defaults.Serializable {
    case black
    case `default`
    case adaptive
    case white
    case dim

    @MainActor func brightness(window: WindowInfo) -> Float {
        switch self {
        case .black:
            -1.0
        case .default:
            0.0
        case .white:
            1.0
        case .dim:
            -0.7
        case .adaptive:
            (!CGSIsMenuBarVisibleOnSpace(cid, window.space ?? 1) || (statusBarAppearance(screen: window.screen)?.isLight ?? true)) ? -1.0 : 1.0
        }
    }
}

struct ColorPicker: View {
    let title: String
    let blackHelp: String
    let defaultHelp: String
    let adaptiveHelp: String
    let dimHelp: String
    let whiteHelp: String
    let selection: Binding<DotColor>

    var body: some View {
        Picker(title, selection: selection) {
            Text("Black").tag(DotColor.black)
                .help(blackHelp)
            Text("Default").tag(DotColor.default)
                .help(defaultHelp)
            Text("Adaptive").tag(DotColor.adaptive)
                .help(adaptiveHelp)
            Text("Dim").tag(DotColor.dim)
                .help(dimHelp)
            Text("White").tag(DotColor.white)
                .help(whiteHelp)
        }
    }
}

@main
struct YellowDotApp: App {
    init() {}

    @AppStorage("showMenubarIcon") var showMenubarIcon = Defaults[.showMenubarIcon]
    @AppStorage("dotColor") var dotColor = Defaults[.dotColor]
    @AppStorage("indicatorColor") var indicatorColor = Defaults[.indicatorColor]

    @Environment(\.openWindow) var openWindow
    @ObservedObject var wm = WM
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var dotColorPicker: some View {
        ColorPicker(
            title: "Dot color",
            blackHelp: "Makes the dot black.",
            defaultHelp: "Disables any dot color changes",
            adaptiveHelp: "Makes the dot black/white based on the color of the menubar icons.",
            dimHelp: "Makes the dot 70% darker, keeping a bit of its color.",
            whiteHelp: "Makes the dot white.",
            selection: $dotColor
        )
    }

    var indicatorColorPicker: some View {
        ColorPicker(
            title: "Menubar Indicator color",
            blackHelp: "Makes the indicator black.",
            defaultHelp: "Disables any indicator color changes",
            adaptiveHelp: "Makes the indicator black/white based on the color of the menubar icons.",
            dimHelp: "Makes the indicator 70% darker, keeping a bit of its color.",
            whiteHelp: "Makes the indicator white.",
            selection: $indicatorColor
        )
    }

    var body: some Scene {
        MenuBarExtra("YellowDot", systemImage: "circle.fill", isInserted: $showMenubarIcon) {
            Toggle("Show menubar icon", isOn: $showMenubarIcon)
            LaunchAtLogin.Toggle()
            indicatorColorPicker
            dotColorPicker
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(self)
            }
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: showMenubarIcon) { show in
            if !show {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onChange(of: wm.windowToOpen) { window in
            guard let window else { return }
            openWindow(id: window)
            wm.windowToOpen = nil
        }
        Window("YellowDot Settings", id: "settings") {
            VStack(alignment: .trailing) {
                Form {
                    Toggle("Show menubar icon", isOn: $showMenubarIcon)
                    LaunchAtLogin.Toggle()
                    indicatorColorPicker.pickerStyle(.segmented)
                    dotColorPicker.pickerStyle(.segmented)
                }.formStyle(.grouped)
                Button("Quit") {
                    NSApplication.shared.terminate(self)
                }.padding()
            }
            .frame(minWidth: 580, minHeight: 270)
        }
        .defaultSize(width: 580, height: 270)
    }
}
