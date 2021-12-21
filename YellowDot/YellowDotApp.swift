//
//  YellowDotApp.swift
//  YellowDot
//
//  Created by Alin Panaitiu on 21.12.2021.
//

import AXSwift
import SwiftUI

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

func hideDot() {
    var newPosition = CGPoint(x: -999_999, y: -999_999)
    guard let positionValue = AXValueCreate(.cgPoint, &newPosition),
          let controlCenter = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first,
          let windows = controlCenter.windows()
    else {
        return
    }

    for window in windows {
        if window.size.width == window.size.height {
            AXUIElementSetAttributeValue(window.element.element, kAXPositionAttribute as CFString, positionValue)
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        acquirePrivileges()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            hideDot()
        }
    }
}

// MARK: - YellowDotApp

@main
struct YellowDotApp: App {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
