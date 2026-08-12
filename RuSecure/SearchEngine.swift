//
//  SearchEngine.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 12.08.2026.
//

import Foundation

enum SearchEngine: String, CaseIterable, Identifiable {
    case google
    case yandex
    case duckduckgo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google: "Google"
        case .yandex: "Яндекс"
        case .duckduckgo: "DuckDuckGo"
        }
    }

    func suggestURL(query: String) -> URL? {
        let q = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return switch self {
        case .google:
            URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&hl=ru&q=\(q)")
        case .yandex:
            URL(string: "https://suggest.yandex.net/suggest-ff.cgi?part=\(q)&uilang=ru")
        case .duckduckgo:
            URL(string: "https://duckduckgo.com/ac/?q=\(q)&type=list")
        }
    }

    func searchURL(query: String) -> URL? {
        let q = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return switch self {
        case .google:
            URL(string: "https://www.google.com/search?q=\(q)")
        case .yandex:
            URL(string: "https://yandex.ru/search/?text=\(q)")
        case .duckduckgo:
            URL(string: "https://duckduckgo.com/?q=\(q)")
        }
    }

    static func parseSuggestions(_ data: Data) -> [String] {
        if let items = parseJSON(data) { return items }
        // Fallback: некоторые ответы приходят в Windows-1251.
        let cfEncoding = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.windowsCyrillic.rawValue)
        )
        if let text = String(data: data, encoding: String.Encoding(rawValue: cfEncoding)),
           let utf8 = text.data(using: .utf8) {
            return parseJSON(utf8) ?? []
        }
        return []
    }

    private static func parseJSON(_ data: Data) -> [String]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        if let nested = json.dropFirst().first as? [Any] {
            return nested.compactMap { $0 as? String }
        }
        return json.compactMap { $0 as? String }
    }
}
