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
    static let dotColor = Key<DotColor>("dotColor", default: DotColor.black)
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

    static func fromInfoDict(_ dict: [String: Any]) -> WindowInfo {
        var rect = CGRect.zero
        if let bounds = dict["kCGWindowBounds"] as? [String: CGFloat],
           let x = bounds["X"], let y = bounds["Y"],
           let width = bounds["Width"], let height = bounds["Height"]
        {
            rect = CGRect(x: x, y: y, width: width, height: height)
        }
        return WindowInfo(
            bounds: rect,
            memoryUsage: (dict["kCGWindowMemoryUsage"] as? Int) ?? 0,
            alpha: (dict["kCGWindowAlpha"] as? Int) ?? 0,
            sharingState: (dict["kCGWindowSharingState"] as? Int) ?? 0,
            number: (dict["kCGWindowNumber"] as? Int) ?? 0,
            ownerName: (dict["kCGWindowOwnerName"] as? String) ?? "",
            storeType: (dict["kCGWindowStoreType"] as? Int) ?? 0,
            layer: (dict["kCGWindowLayer"] as? Int) ?? 0,
            ownerPID: (dict["kCGWindowOwnerPID"] as? Int) ?? 0,
            isOnscreen: (dict["kCGWindowIsOnscreen"] as? Int) ?? 0,
            name: (dict["kCGWindowName"] as? String) ?? ""
        )
    }
}

func getWindows() -> [WindowInfo] {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
    let infoList = windowsListInfo as! [[String: Any]]

    let dicts = infoList.filter { w in
        guard let name = w["kCGWindowName"] as? String else { return false }
        return name == "StatusIndicator" || name == "Menubar"
    }

    return dicts.map { WindowInfo.fromInfoDict($0) }
}

@MainActor var windows: [WindowInfo] = []

@MainActor func setDotBrightness(_ brightness: Float) {
    let windows = windows.filter { $0.name == "StatusIndicator" }
    guard !windows.isEmpty else {
        return
    }

    #if DEBUG
        for window in windows {
            print(window)
        }
    #endif

    var ids = windows.map(\.number)
    var brightnesses = [Float](repeating: brightness, count: ids.count)
    CGSSetWindowListBrightness(cid, &ids, &brightnesses, Int32(ids.count))
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
        setDotBrightness(Defaults[.dotColor].brightness)

        windowFetcher?.invalidate()
        dotHider?.invalidate()

        windowFetcher = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            mainActor { windows = getWindows() }
        }
        dotHider = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            let color = Defaults[.dotColor]
            guard color != .default else { return }
            mainActor { setDotBrightness(color.brightness) }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        Defaults[.launchCount] += 1

        initDotHider(timeInterval: 1)

        pub(.dotColor).sink { paused in
            setDotBrightness(paused.newValue.brightness)
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

enum DotColor: String, Defaults.Serializable {
    case black
    case `default`
//    case adaptive
    case white

    @MainActor var brightness: Float {
        switch self {
        case .black:
            -1.0
        case .default:
            0.0
        case .white:
            1.0
//        case .adaptive:
//            windows.contains(where: { $0.name == "Menubar" }) ? -1.0 : 1.0
        }
    }
}

@main
struct YellowDotApp: App {
    init() {}

    @AppStorage("showMenubarIcon") var showMenubarIcon = Defaults[.showMenubarIcon]
    @AppStorage("dotColor") var dotColor = Defaults[.dotColor]

    @Environment(\.openWindow) var openWindow
    @ObservedObject var wm = WM
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var dotColorPicker: some View {
        Picker("Dot color", selection: $dotColor) {
            Text("Black").tag(DotColor.black)
                .help("Makes the dot black.")
            Text("Default").tag(DotColor.default)
                .help("Disables any dot color changes")
//            Text("Adaptive").tag(DotColor.adaptive)
//                .help("Makes the dot black/white based on the color of the menubar icons.")
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
                    dotColorPicker.pickerStyle(.segmented)
                }.formStyle(.grouped)
                Button("Quit") {
                    NSApplication.shared.terminate(self)
                }.padding()
            }
        }
        .defaultSize(width: 370, height: 280)
        MenuBarExtra("YellowDot", systemImage: "circle.fill", isInserted: $showMenubarIcon) {
            Toggle("Show menubar icon", isOn: $showMenubarIcon)
            LaunchAtLogin.Toggle()
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
