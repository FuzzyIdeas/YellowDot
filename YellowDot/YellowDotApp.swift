//
//  YellowDotApp.swift
//  YellowDot
//
//  Created by Alin Panaitiu on 21.12.2021.
//

import AXSwift
import Combine
import Defaults
import SwiftUI

extension Defaults.Keys {
    static let hideMenubarIcon = Key<Bool>("hideMenubarIcon", default: false)
    static let paused = Key<Bool>("paused", default: false)
    static let orange = Key<Bool>("orange", default: false)
    static let faster = Key<Bool>("faster", default: false)
    static let launchCount = Key<Int>("launchCount", default: 0)
}

// MARK: - AXWindow

struct AXWindow {
    // MARK: Lifecycle

    init?(from window: UIElement, runningApp: NSRunningApplication? = nil) {
        guard let attrs = try? window.getMultipleAttributes(
            .frame,
            .fullScreen,
            .title,
            .position,
            .main,
            .minimized,
            .size,
            .identifier,
            .subrole,
            .role,
            .focused
        )
        else {
            return nil
        }
        element = window

        let frame = attrs[.frame] as? NSRect ?? NSRect()

        self.frame = frame
        fullScreen = attrs[.fullScreen] as? Bool ?? false
        title = attrs[.title] as? String ?? ""
        position = attrs[.position] as? NSPoint ?? NSPoint()
        main = attrs[.main] as? Bool ?? false
        minimized = attrs[.minimized] as? Bool ?? false
        focused = attrs[.focused] as? Bool ?? false
        size = attrs[.size] as? NSSize ?? NSSize()
        identifier = attrs[.identifier] as? String ?? ""
        subrole = attrs[.subrole] as? String ?? ""
        role = attrs[.role] as? String ?? ""

        self.runningApp = runningApp
//        screen = NSScreen.screens.filter {
//            guard let bounds = $0.bounds else { return false }
//            return bounds.intersects(frame)
//        }.max(by: { s1, s2 in
//            guard let bounds1 = s1.bounds, let bounds2 = s2.bounds else { return false }
//            return bounds1.intersectedArea(frame) < bounds2.intersectedArea(frame)
//        })
    }

    // MARK: Internal

    let element: UIElement
    let frame: NSRect
    let fullScreen: Bool
    let title: String
    let position: NSPoint
    let main: Bool
    let minimized: Bool
    let focused: Bool
    let size: NSSize
    let identifier: String
    let subrole: String
    let role: String
    let runningApp: NSRunningApplication?
//    let screen: NSScreen?
}

func acquirePrivileges() {
    let options = [
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true as CFBoolean,
    ]
    let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

    guard !accessEnabled else { return }

    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
        if AXIsProcessTrusted() {
            timer.invalidate()
            AppDelegate.instance.statusBar?.showPopover(AppDelegate.instance)
        }
    }
}

extension NSRunningApplication {
    func windows() -> [AXWindow]? {
        guard let app = Application(self) else { return nil }
        do {
            let wins = try app.windows()
            return wins?.compactMap { AXWindow(from: $0, runningApp: self) }
        } catch {
            return nil
        }
    }
}

let OFF_SCREEN_POSITION = CGPoint(x: -999_999, y: -999_999)
var oldDotPosition = OFF_SCREEN_POSITION

func moveDot(offScreen: Bool = true) {
    var newPosition = offScreen ? OFF_SCREEN_POSITION : oldDotPosition
    let controlCenters = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter")
    let windows = controlCenters.compactMap { $0.windows() }.joined()
    guard let positionValue = AXValueCreate(.cgPoint, &newPosition), !windows.isEmpty
    else {
        #if DEBUG
            print("Error in finding dot:")
            print("positionValue: \(AXValueCreate(.cgPoint, &newPosition))")
            print(
                "com.apple.controlcenter: \(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first)"
            )
            print(
                "controlcenter windows: \(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first?.windows())"
            )
        #endif
        return
    }

    for window in windows {
        #if DEBUG
            print(window)
        #endif
        if window.size.width == window.size.height {
            if oldDotPosition == OFF_SCREEN_POSITION {
                oldDotPosition = window.frame.origin
            }
            AXUIElementSetAttributeValue(window.element.element, kAXPositionAttribute as CFString, positionValue)
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var instance: AppDelegate!

    var statusBar: StatusBarController?
    let popover = NSPopover()
    var application = NSApplication.shared
    var observers: Set<AnyCancellable> = []

    var dotHider: Timer?

    func initMenubar() {
        let contentView = ContentView()
        let view = HostingView(rootView: contentView)

        popover.contentViewController = MainViewController()
        popover.contentViewController?.view = view
        popover.contentSize = NSSize(width: FULL_WINDOW_WIDTH, height: 300)
        popover.animates = false

        statusBar = StatusBarController(popover, visible: !Defaults[.hideMenubarIcon])
        Defaults.publisher(.hideMenubarIcon).sink { [self] hidden in
            statusBar?.statusItem.isVisible = !hidden.newValue
            statusBar?.statusItem.button?.image = hidden.newValue ? nil : NSImage(named: "MenubarIcon")
            if let window = popover.contentViewController?.view.window {
                window.isMovableByWindowBackground = hidden.newValue
                statusBar?.showPopover(self)
            }
        }.store(in: &observers)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        statusBar?.showPopover(self)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        statusBar?.showPopover(self)
    }

    func initDotHider(timeInterval: TimeInterval) {
        dotHider?.invalidate()
        dotHider = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            guard !Defaults[.paused] else { return }
            moveDot(offScreen: true)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        initMenubar()
        Defaults[.launchCount] += 1
//        #if !DEBUG
        acquirePrivileges()
//        #endif

        initDotHider(timeInterval: Defaults[.faster] ? 0.3 : 1)

        Defaults.publisher(.paused).sink { paused in
            moveDot(offScreen: !paused.newValue)
        }.store(in: &observers)
        Defaults.publisher(.faster)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { faster in
                self.initDotHider(timeInterval: faster.newValue ? 0.3 : 1)
            }.store(in: &observers)
    }
}

// MARK: - YellowDotApp

@main
struct YellowDotApp: App {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    @Default(.hideMenubarIcon) var hideMenubarIcon

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            if hideMenubarIcon {
                ContentView()
            } else {
                EmptyView()
            }
        }
    }
}
