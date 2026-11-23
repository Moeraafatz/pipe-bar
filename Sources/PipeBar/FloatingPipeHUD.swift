import AppKit
@preconcurrency import Carbon
import PipeBarUI
import SwiftUI

private enum PipeHotKeyTrampoline {
    nonisolated(unsafe) static var handler: (@Sendable () -> Void)?
}

private func pipeHotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    PipeHotKeyTrampoline.handler?()
    return noErr
}

@MainActor
final class FloatingPipeHUD {
    private var panel: NSPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let state: PipeAppState

    init(state: PipeAppState) {
        self.state = state
        registerGlobalHotKey()
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show()
    }

    func show() {
        if panel == nil {
            let hosting = NSHostingView(rootView: RootPipeView(state: state, width: 525))
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 525, height: 615),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = true
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isMovableByWindowBackground = true
            newPanel.contentView = hosting
            panel = newPanel
        }

        guard let panel else { return }
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let x = visible.midX - size.width / 2
            let y = visible.maxY - size.height - 90
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func registerGlobalHotKey() {
        PipeHotKeyTrampoline.handler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggle()
            }
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            pipeHotKeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        // Option + Shift + P (non-overlapping with Glass Recall ⌥Space, Quiet Brief ⌥⇧M, Axon Flow ⌥⇧K)
        let hotKeyID = EventHotKeyID(signature: OSType(0x50495045), id: 1) // "PIPE"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(optionKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
