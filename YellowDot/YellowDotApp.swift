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
    static let dimMenubarIndicators = Key<Bool>("dimMenubarIndicators", default: true)
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

func getWindows() -> [WindowInfo] {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
    let infoList = windowsListInfo as! [[String: Any]]

    let dicts = infoList.filter { w in
        if let name = w["kCGWindowName"] as? String {
            return name == "StatusIndicator" || name == "Menubar"
        }
        if let ownerName = w["kCGWindowOwnerName"] as? String, let number = w["kCGWindowNumber"] as? Int, let bounds = w["kCGWindowBounds"] as? [String: CGFloat], let y = bounds["Y"] {
            return ownerName == "Control Centre" && number > 100 && y == 0
        }
        return false
    }

    return dicts.map { WindowInfo.fromInfoDict($0) }
}

@MainActor var windows: [WindowInfo] = []

@MainActor func setDotBrightness(color: DotColor, windowName: String? = nil, windowOwnerName: String? = nil) {
    let windows = windows.filter { $0.name == windowName || $0.ownerName == windowOwnerName }
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
        setDotBrightness(color: Defaults[.dotColor], windowName: "StatusIndicator")
        if Defaults[.dimMenubarIndicators] {
            setDotBrightness(color: .dim, windowOwnerName: "Control Centre")
        }

        windowFetcher?.invalidate()
        dotHider?.invalidate()

        windowFetcher = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            mainActor { windows = getWindows() }
        }
        dotHider = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            let color = Defaults[.dotColor]
            guard color != .default else { return }
            mainActor {
                setDotBrightness(color: color, windowName: "StatusIndicator")
                if Defaults[.dimMenubarIndicators] {
                    setDotBrightness(color: .dim, windowOwnerName: "Control Centre")
                }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        Defaults[.launchCount] += 1

        initDotHider(timeInterval: 1)

        pub(.dotColor).sink { dotColor in
            setDotBrightness(color: dotColor.newValue, windowName: "StatusIndicator")
        }.store(in: &observers)
        pub(.dimMenubarIndicators).sink { dim in
            setDotBrightness(color: dim.newValue ? .dim : .default, windowOwnerName: "Control Centre")
        }.store(in: &observers)

        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeMainNotification), name: NSWindow.didBecomeMainNotification, object: nil)
        NSApp.windows.first?.close()
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

@main
struct YellowDotApp: App {
    init() {}

    @AppStorage("showMenubarIcon") var showMenubarIcon = Defaults[.showMenubarIcon]
    @AppStorage("dotColor") var dotColor = Defaults[.dotColor]
    @AppStorage("dimMenubarIndicators") var dimMenubarIndicators = Defaults[.dimMenubarIndicators]

    @Environment(\.openWindow) var openWindow
    @ObservedObject var wm = WM
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var dotColorPicker: some View {
        Picker("Dot color", selection: $dotColor) {
            Text("Black").tag(DotColor.black)
                .help("Makes the dot black.")
            Text("Default").tag(DotColor.default)
                .help("Disables any dot color changes")
            Text("Adaptive").tag(DotColor.adaptive)
                .help("Makes the dot black/white based on the color of the menubar icons.")
            Text("Dim").tag(DotColor.dim)
                .help("Makes the dot 70% darker, keeping a bit of its color.")
            Text("White").tag(DotColor.white)
                .help("Makes the dot white.")
        }
    }

    var body: some Scene {
        Window("YellowDot Settings", id: "settings") {
            VStack(alignment: .trailing) {
                Form {
                    Toggle("Show menubar icon", isOn: $showMenubarIcon)
                    LaunchAtLogin.Toggle()
                    Toggle("Dim orange/purple menubar indicators", isOn: $dimMenubarIndicators)
                    dotColorPicker.pickerStyle(.segmented)
                }.formStyle(.grouped)
                Button("Quit") {
                    NSApplication.shared.terminate(self)
                }.padding()
            }
        }
        .defaultSize(width: 540, height: 340)
        MenuBarExtra("YellowDot", systemImage: "circle.fill", isInserted: $showMenubarIcon) {
            Toggle("Show menubar icon", isOn: $showMenubarIcon)
            LaunchAtLogin.Toggle()
            Toggle("Dim orange/purple menubar indicators", isOn: $dimMenubarIndicators)
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
            } else {
                NSApplication.shared.keyWindow?.close()
            }
        }
        .onChange(of: wm.windowToOpen) { window in
            guard let window else { return }
            openWindow(id: window)
            wm.windowToOpen = nil
        }
    }
}
