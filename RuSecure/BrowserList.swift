//
//  BrowserList.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 11.08.2026.
//


import AppKit

enum BrowserList {
    static func installed() -> [(name: String, bundle: String)] {
        guard let probe = URL(string: "https://example.com") else { return [] }

        let urls = NSWorkspace.shared.urlsForApplications(toOpen: probe)

        return urls.compactMap { url -> (String, String)? in
            guard let b = Bundle(url: url),
                  let id = b.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier else { return nil }

            let name = (b.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (b.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent

            return (name, id)
        }
        .sorted { $0.name < $1.name }
    }
}