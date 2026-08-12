//
//  AppDelegate.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 11.08.2026.
//

import AppKit
import SwiftUI

final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var searchWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var moveObserver: NSObjectProtocol?
    private var becomeActiveObserver: NSObjectProtocol?
    private var suppressMoveSave = false
    private var suppressAutoShow = false
    private var autoShowWorkItem: DispatchWorkItem?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "lock.shield",
                accessibilityDescription: "RuSecure"
            )
            button.target = self
            button.action = #selector(toggleSearch)
        }
        statusItem = item

        hotkeyManager = HotkeyManager { [weak self] in self?.toggleSearch() }
        hotkeyManager?.register()

        // Если приложение запущено, чтобы обработать ссылку, не показываем
        // оверлей и не перехватываем фокус: ссылка ниже уйдёт в нужный браузер.
        suppressAutoShow = NSAppleEventManager.shared().currentAppleEvent != nil
        if !suppressAutoShow {
            showSearch()
        }

        // По клику на ссылку macOS может активировать RuSecure (браузер по
        // умолчанию) уже после того, как ссылка передана дальше; в этом
        // случае фокус нужно снова отдать целевому браузеру. А если нас
        // активировали без окон (Stage Manager, Dock) — показываем тулбар.
        becomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Router.shared.attemptFocus()
            self?.scheduleAutoShowIfNeeded()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showSearch()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        autoShowWorkItem?.cancel()
        urls.forEach { Router.shared.route($0) }
    }

    @objc private func toggleSearch() {
        // Скрываем только когда окно в фокусе: иначе клик по иконке из
        // другого пространства сначала должен окно показать, а не спрятать.
        if let searchWindow, searchWindow.isVisible, searchWindow.isKeyWindow {
            hideSearch()
        } else {
            showSearch()
        }
    }

    private func showSearch() {
        if searchWindow == nil {
            let window = KeyableWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 90),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .screenSaver
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true

            moveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: window,
                queue: .main
            ) { [weak self] note in
                guard let self, !self.suppressMoveSave,
                      let w = note.object as? NSWindow else { return }
                let d = UserDefaults.standard
                d.set(w.frame.origin.x, forKey: "searchOriginX")
                d.set(w.frame.origin.y, forKey: "searchOriginY")
            }

            searchWindow = window
        }

        guard let window = searchWindow else { return }

        // Свежий контент при каждом показе: пустое поле и фокус.
        window.contentViewController = NSHostingController(rootView: SearchOverlayView(
            onOpenSettings: { [weak self] in self?.openSettings() },
            onClose: { [weak self] in self?.hideSearch() },
            onHideApp: { NSApp.hide(nil) },
            onContentSizeChange: { [weak self] size in
                self?.resizeSearchWindow(to: size)
            }
        ))

        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let d = UserDefaults.standard
        if d.object(forKey: "searchOriginX") != nil {
            window.setFrameOrigin(NSPoint(
                x: d.double(forKey: "searchOriginX"),
                y: d.double(forKey: "searchOriginY")
            ))
        } else {
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(
                x: screen.midX - size.width / 2,
                y: screen.midY - size.height / 2 + screen.height * 0.12
            ))
        }

        if NSApp.isHidden {
            NSApp.unhide(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func resizeSearchWindow(to size: CGSize) {
        guard let window = searchWindow,
              abs(window.frame.width - size.width) > 0.5 ||
              abs(window.frame.height - size.height) > 0.5 else { return }
        suppressMoveSave = true
        let f = window.frame
        window.setFrame(
            NSRect(
                x: f.midX - size.width / 2,
                y: f.maxY - size.height,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        suppressMoveSave = false
    }

    /// Показывает тулбар, когда приложение активировали, а видимых окон нет
    /// (Stage Manager, Dock, Cmd+Tab). Не срабатывает сразу после обработки
    /// ссылки, чтобы не всплывать поверх браузера.
    private func scheduleAutoShowIfNeeded() {
        if suppressAutoShow {
            suppressAutoShow = false
            return
        }
        guard !(searchWindow?.isVisible ?? false),
              !(settingsWindow?.isVisible ?? false) else { return }
        autoShowWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !Router.shared.isRouting, !NSApp.isHidden,
                  !(self.searchWindow?.isVisible ?? false),
                  !(self.settingsWindow?.isVisible ?? false) else { return }
            self.showSearch()
        }
        autoShowWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    private func hideSearch() {
        searchWindow?.orderOut(nil)
    }

    private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "RuSecure"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentViewController = NSHostingController(rootView: SettingsView())
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
