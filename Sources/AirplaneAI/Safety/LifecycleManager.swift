import Foundation
#if canImport(AppKit)
import AppKit
#endif

// Spec §12.7: observe terminate / sleep / wake. Route to a single handler.
@MainActor
public final class LifecycleManager {
    public struct Handlers: Sendable {
        public var onWillTerminate: @Sendable () -> Void
        public var onWillSleep: @Sendable () -> Void
        public var onDidWake: @Sendable () -> Void
        public init(
            onWillTerminate: @escaping @Sendable () -> Void = {},
            onWillSleep: @escaping @Sendable () -> Void = {},
            onDidWake: @escaping @Sendable () -> Void = {}
        ) {
            self.onWillTerminate = onWillTerminate
            self.onWillSleep = onWillSleep
            self.onDidWake = onDidWake
        }
    }

    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func install(handlers: Handlers) {
        #if canImport(AppKit)
        let nc = NSWorkspace.shared.notificationCenter
        observers.append(
            NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                handlers.onWillTerminate()
            }
        )
        observers.append(
            nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
                handlers.onWillSleep()
            }
        )
        observers.append(
            nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                handlers.onDidWake()
            }
        )
        #endif
    }

    public func stop() {
        for o in observers { NotificationCenter.default.removeObserver(o) }
        #if canImport(AppKit)
        for o in observers { NSWorkspace.shared.notificationCenter.removeObserver(o) }
        #endif
        observers.removeAll()
    }
}
