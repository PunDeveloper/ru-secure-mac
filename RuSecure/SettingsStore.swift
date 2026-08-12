//
//  SettingsStore.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 11.08.2026.
//


import Foundation

enum SettingsStore {
    private static let d = UserDefaults.standard

    static var useGeosite: Bool {
        get { d.object(forKey: "useGeosite") as? Bool ?? true }
        set { d.set(newValue, forKey: "useGeosite") }
    }

    static var useZones: Bool {
        get { d.object(forKey: "useZones") as? Bool ?? true }
        set { d.set(newValue, forKey: "useZones") }
    }

    static var russianBrowser: String {
        get { d.string(forKey: "russianBrowser") ?? "ru.yandex.desktop.yandex-browser" }
        set { d.set(newValue, forKey: "russianBrowser") }
    }

    static var otherBrowser: String {
        get { d.string(forKey: "otherBrowser") ?? "com.apple.Safari" }
        set { d.set(newValue, forKey: "otherBrowser") }
    }
}