//
//  HotkeyManager.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 13.08.2026.
//

import Carbon.HIToolbox
import Foundation

/// Глобальная горячая клавиша ⌥Space: показывает и скрывает окно поиска
/// из любого приложения, без прав Accessibility.
final class HotkeyManager {
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func register() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = Self.fourCharCode("RuSc")
        hotKeyID.id = 1

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>
                    .fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.handler() }
                return noErr
            },
            1,
            &eventType,
            context,
            nil
        )

        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
