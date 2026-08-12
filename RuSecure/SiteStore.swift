//
//  SiteStore.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 11.08.2026.
//


import Foundation

final class SiteStore {
    static let shared = SiteStore()
    private let d = UserDefaults.standard

    enum Kind: String {
        case include = "sites_include"
        case exclude = "sites_exclude"
    }

    private let defaults = [
        "gosuslugi.ru", "nalog.gov.ru", "mos.ru",
        "gosuslugi.mosreg.ru", "kremlin.ru", "government.ru"
    ]

    func seedDefaultsIfNeeded() {
        guard d.object(forKey: "seeded") == nil else { return }
        d.set(defaults, forKey: Kind.include.rawValue)
        d.set(true, forKey: "seeded")
    }

    func list(_ kind: Kind) -> [String] {
        (d.stringArray(forKey: kind.rawValue) ?? []).sorted()
    }

    func add(_ raw: String, exclude: Bool) {
        let site = normalize(raw)
        guard !site.isEmpty else { return }

        var inc = Set(d.stringArray(forKey: Kind.include.rawValue) ?? [])
        var exc = Set(d.stringArray(forKey: Kind.exclude.rawValue) ?? [])

        if exclude { exc.insert(site); inc.remove(site) }
        else       { inc.insert(site); exc.remove(site) }

        d.set(inc.sorted(), forKey: Kind.include.rawValue)
        d.set(exc.sorted(), forKey: Kind.exclude.rawValue)
    }

    func remove(_ site: String, _ kind: Kind) {
        var set = Set(d.stringArray(forKey: kind.rawValue) ?? [])
        set.remove(site)
        d.set(set.sorted(), forKey: kind.rawValue)
    }

    func matches(_ host: String, in kind: Kind) -> Bool {
        list(kind).contains { rule in
            if rule.hasPrefix(".") {
                return host.hasSuffix(rule) || host == String(rule.dropFirst())
            }
            return host == rule || host.hasSuffix("." + rule)
        }
    }

    private func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix(".") || s.hasPrefix("*") {
            s = s.drop { $0 == "*" }.trimmingCharacters(in: .whitespaces)
            if !s.hasPrefix(".") && !s.contains(".") { s = "." + s }
            return s
        }
        if !s.contains("://") { s = "http://" + s }
        var host = URL(string: s)?.host ?? ""
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
}