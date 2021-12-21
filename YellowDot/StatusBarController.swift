import AppKit
import Cocoa
import SwiftUI

// MARK: - EventMonitor

class EventMonitor {
    // MARK: Lifecycle

    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    // MARK: Public

    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as! NSObject
    }

    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }

    // MARK: Private

    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
}

// MARK: - StatusBarController

class StatusBarController: NSObject, NSPopoverDelegate {
    // MARK: Lifecycle

    init(_ popover: NSPopover, visible: Bool = true) {
        self.popover = popover
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)

        super.init()

        if let statusBarButton = statusItem.button {
            statusBarButton.image = NSImage(named: "MenubarIcon")
            statusBarButton.image?.size = NSSize(width: 18.0, height: 18.0)
            statusBarButton.image?.isTemplate = true

            statusBarButton.action = #selector(togglePopover(sender:))
            statusBarButton.target = self
        }

        if !visible {
            statusItem.isVisible = false
            statusItem.button?.image = nil
        }

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown], handler: mouseEventHandler)
        self.popover.delegate = self
    }

    // MARK: Internal

    var statusItem: NSStatusItem

    func popoverDidClose(_: Notification) {
        let positioningView = statusItem.button?.subviews.first {
            $0.identifier == NSUserInterfaceItemIdentifier(rawValue: "positioningView")
        }
        positioningView?.removeFromSuperview()
    }

    @objc func togglePopover(sender: AnyObject) {
        if popover.isShown {
            hidePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    func showPopover(_ sender: AnyObject) {
        guard let button = statusItem.button else { return }

        let positioningView = NSView(frame: button.bounds)
        positioningView.identifier = NSUserInterfaceItemIdentifier(rawValue: "positioningView")
        button.addSubview(positioningView)

        popover.show(relativeTo: positioningView.bounds, of: positioningView, preferredEdge: .maxY)
        positioningView.bounds = positioningView.bounds.offsetBy(dx: 0, dy: positioningView.bounds.height)
        if let popoverWindow = popover.contentViewController?.view.window {
            if statusItem.isVisible {
                popoverWindow.setFrame(popoverWindow.frame.offsetBy(dx: 0, dy: 12), display: false)
                popoverWindow.isMovableByWindowBackground = false
            } else {
                popoverWindow.center()
                popoverWindow.isMovableByWindowBackground = true
            }
        }
        eventMonitor?.start()
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(sender)
    }

    func hidePopover(_ sender: AnyObject) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }

    func mouseEventHandler(_ event: NSEvent?) {
        if popover.isShown {
            hidePopover(event!)
        }
    }

    // MARK: Private

    private var statusBar: NSStatusBar
    private var popover: NSPopover
    private var eventMonitor: EventMonitor?
}

// MARK: - MainViewController

class MainViewController: NSViewController {
//    override func flagsChanged(with event: NSEvent) {
//        AppDelegate.instance.onFlagsChanged(event: event)
//    }
}

// MARK: - PopoverBackgroundView

class PopoverBackgroundView: NSView {
    override func draw(_: NSRect) {
        NSColor.clear.set()
        bounds.fill()
    }
}

extension NSVisualEffectView {
    private typealias UpdateLayer = @convention(c) (AnyObject) -> Void

    @objc dynamic
    func replacement() {
        super.updateLayer()
        guard let layer = layer, layer.name == "NSPopoverFrame", identifier == MAIN_VIEW_ID else {
            unsafeBitCast(
                updateLayerOriginalIMP, to: Self.UpdateLayer.self
            )(self)
            return
        }
        CATransaction.begin()
        CATransaction.disableActions()

        layer.isOpaque = false
        layer.sublayers?.first?.opacity = 0
        if let window = window {
            window.backgroundColor = .clear
            window.isOpaque = false
            window.styleMask = .borderless
            window.hasShadow = false
        }

        CATransaction.commit()
    }
}

var updateLayerOriginal: Method?
var updateLayerOriginalIMP: IMP?

func swizzlePopoverBackground() {
    let origMethod = #selector(NSVisualEffectView.updateLayer)
    let replacementMethod = #selector(NSVisualEffectView.replacement)

    updateLayerOriginal = class_getInstanceMethod(NSVisualEffectView.self, origMethod)
    updateLayerOriginalIMP = method_getImplementation(updateLayerOriginal!)

    let swizzleMethod: Method? = class_getInstanceMethod(NSVisualEffectView.self, replacementMethod)
    let swizzleImpl = method_getImplementation(swizzleMethod!)
    method_setImplementation(updateLayerOriginal!, swizzleImpl)
}

let MAIN_VIEW_ID = NSUserInterfaceItemIdentifier("MainView")

// MARK: - HostingView

class HostingView: NSHostingView<ContentView> {
    var backgroundView: PopoverBackgroundView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let frameView = window?.contentView?.superview as? NSVisualEffectView {
            frameView.identifier = MAIN_VIEW_ID
            if let window = window {
                window.backgroundColor = .clear
                window.isOpaque = false
                window.styleMask = .borderless
                window.hasShadow = false
            }

            swizzlePopoverBackground()
            frameView.bg = .clear
            if backgroundView == nil {
                backgroundView = PopoverBackgroundView(frame: frameView.bounds)
                backgroundView!.autoresizingMask = NSView.AutoresizingMask([.width, .height])
                frameView.addSubview(backgroundView!, positioned: NSWindow.OrderingMode.below, relativeTo: frameView)
            }
        }
    }
}

extension NSView {
    @objc dynamic var bg: NSColor? {
        get {
            guard let layer = layer, let backgroundColor = layer.backgroundColor else { return nil }
            return NSColor(cgColor: backgroundColor)
        }
        set {
            wantsLayer = true
            layer?.backgroundColor = newValue?.cgColor
        }
    }
}
