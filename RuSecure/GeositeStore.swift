//
//  GeositeStore.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 11.08.2026.
//


import Foundation

final class GeositeStore {
    static let shared = GeositeStore()

    private let url = URL(string:
        "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat_plain.yml"
    )!

    private var suffixes: Set<String> = []
    private var fulls: Set<String> = []
    private var regexes: [NSRegularExpression] = []

    private let d = UserDefaults.standard

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("geosite_category_ru.yml")
    }

    func load() {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        parse(text)
    }

    func updateIfNeededAsync() {
        let updated = d.double(forKey: "geosite_updated")
        let day: Double = 24 * 60 * 60
        guard Date().timeIntervalSince1970 - updated > day else { return }
        Task { await update() }
    }

    @discardableResult
    func update() async -> Bool {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let text = String(data: data, encoding: .utf8) else { return false }
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            d.set(Date().timeIntervalSince1970, forKey: "geosite_updated")
            parse(text)
            return true
        } catch {
            return false
        }
    }

    func updatedText() -> String {
        let t = d.double(forKey: "geosite_updated")
        guard t > 0 else { return "не обновлялся" }
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f.string(from: Date(timeIntervalSince1970: t))
    }

    func matches(_ host: String) -> Bool {
        if fulls.contains(host) { return true }

        var h = host
        while !h.isEmpty {
            if suffixes.contains(h) { return true }
            guard let i = h.firstIndex(of: ".") else { break }
            h = String(h[h.index(after: i)...])
        }

        return regexes.contains { $0.firstMatch(in: host, range: NSRange(host.startIndex..., in: host)) != nil }
    }

    private func parse(_ text: String) {
        var suf = Set<String>()
        var ful = Set<String>()
        var reg: [NSRegularExpression] = []
        var inTarget = false

        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("- name:") {
                let name = line
                    .replacingOccurrences(of: "- name:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                inTarget = name.lowercased() == "category-ru"
                continue
            }

            guard inTarget, line.hasPrefix("- \"") else { continue }

            let rule = line
                .replacingOccurrences(of: "- ", with: "")
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            if rule.hasPrefix("regexp:") {
                if let r = try? NSRegularExpression(pattern: String(rule.dropFirst(7))) {
                    reg.append(r)
                }
            } else if rule.hasPrefix("full:") {
                ful.insert(rule.dropFirst(5).lowercased())
            } else if rule.hasPrefix("domain:") {
                suf.insert(rule.dropFirst(7).lowercased())
            }
        }

        suffixes = suf
        fulls = ful
        regexes = reg
    }
}