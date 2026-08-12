//
//  SearchOverlayView.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 12.08.2026.
//

import SwiftUI

struct SearchOverlayView: View {
    var onOpenSettings: () -> Void
    var onClose: () -> Void
    var onHideApp: () -> Void
    var onContentSizeChange: (CGSize) -> Void

    @AppStorage("searchEngine") private var engineRaw = SearchEngine.google.rawValue

    /// Компактный тулбар (поле + подсказки); при поиске разворачивается
    /// в большое окно с предпросмотром результатов.
    @State private var compact = true
    @State private var text = ""
    @State private var suggestions: [String] = []
    @State private var selected = -1
    @State private var previewURL: URL?
    @State private var suggestTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private var engine: SearchEngine { SearchEngine(rawValue: engineRaw) ?? .google }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !compact {
                HStack(spacing: 8) {
                    TrafficLight(
                        color: .trafficClose,
                        symbol: "xmark",
                        help: "Закрыть",
                        action: onClose
                    )
                    TrafficLight(
                        color: .trafficMinimize,
                        symbol: "minus",
                        help: "Скрыть",
                        action: onHideApp
                    )
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    if let ghost = ghostCompletion {
                        Text(ghost)
                            .font(.title2)
                            .lineLimit(1)
                            .allowsHitTesting(false)
                    }
                    TextField("Поиск или адрес", text: $text)
                        .textFieldStyle(.plain)
                        .font(.title2)
                        .focused($focused)
                        .onSubmit(submit)
                        .onKeyPress(.tab) {
                            guard selected >= 0,
                                  selected < suggestions.count else { return .ignored }
                            acceptCompletion()
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            moveSelection(1)
                            return .handled
                        }
                        .onKeyPress(.upArrow) {
                            moveSelection(-1)
                            return .handled
                        }
                        .onChange(of: text) { _, newValue in
                            selected = -1
                            updateSuggestions(for: newValue)
                        }
                }
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Настройки")
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2)))

            if previewURL == nil, !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions.indices, id: \.self) { index in
                        let item = suggestions[index]
                        Button {
                            submitText(item)
                        } label: {
                            Text(item)
                                .font(.title3)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.accentColor
                                            .opacity(index == selected ? 0.25 : 0))
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let previewURL {
                SearchWebView(
                    url: previewURL,
                    onOpen: { url in Router.shared.route(url) },
                    onFail: openPreviewInBrowser
                )
                .frame(height: 560)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .frame(width: compact ? 680 : 920)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { onContentSizeChange(proxy.size) }
                    .onChange(of: proxy.size) { _, size in
                        onContentSizeChange(size)
                    }
            }
        )
        .onAppear { focused = true }
        .onExitCommand(perform: handleEscape)
    }

    private func updateSuggestions(for query: String) {
        suggestTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isURLLike(trimmed) else {
            suggestions = []
            return
        }
        suggestTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled,
                  let url = engine.suggestURL(query: trimmed) else { return }
            do {
                var request = URLRequest(url: url)
                // Без браузерного User-Agent Google отдаёт кириллицу
                // в Windows-1251, и JSON парсится пустым.
                request.setValue(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    + "AppleWebKit/537.36 (KHTML, like Gecko) "
                    + "Chrome/126.0.0.0 Safari/537.36",
                    forHTTPHeaderField: "User-Agent"
                )
                let (data, _) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return }
                suggestions = SearchEngine.parseSuggestions(data)
            } catch {}
        }
    }

    private func submit() {
        if selected >= 0, selected < suggestions.count {
            submitText(suggestions[selected])
            return
        }
        submitText(text)
    }

    private func moveSelection(_ delta: Int) {
        guard !suggestions.isEmpty else { return }
        if selected < 0 {
            selected = delta > 0 ? 0 : suggestions.count - 1
        } else {
            selected = (selected + delta + suggestions.count) % suggestions.count
        }
    }

    /// Дополнение в строке: введённая часть остаётся как есть, хвост
    /// подсказки рисуется полупрозрачным позади поля ввода.
    private var ghostCompletion: AttributedString? {
        guard selected >= 0, selected < suggestions.count else { return nil }
        let suggestion = suggestions[selected]
        guard suggestion.count > text.count,
              suggestion.lowercased().hasPrefix(text.lowercased()) else { return nil }
        var attr = AttributedString(suggestion)
        let split = attr.index(attr.startIndex, offsetByCharacters: text.count)
        attr[attr.startIndex..<split].foregroundColor = Color.clear
        attr[split..<attr.endIndex].foregroundColor = Color.primary.opacity(0.35)
        return attr
    }

    private func acceptCompletion() {
        guard selected >= 0, selected < suggestions.count else { return }
        text = suggestions[selected]
    }

    private func handleEscape() {
        if previewURL != nil {
            previewURL = nil
            compact = true
            focused = true
        } else {
            onClose()
        }
    }

    private func submitText(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isURLLike(trimmed) {
            let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
            guard let url = URL(string: withScheme) else { return }
            Router.shared.route(url)
            onClose()
            return
        }

        // Не адрес, а запрос: разворачиваемся в большое окно и показываем
        // результаты поиска во встроенном web view; клики по ним
        // перехватываются роутером.
        guard let url = engine.searchURL(query: trimmed) else { return }
        compact = false
        suggestions = []
        selected = -1
        previewURL = url
    }

    private func openPreviewInBrowser() {
        guard let url = previewURL else { return }
        Router.shared.route(url)
        onClose()
    }

    private func isURLLike(_ s: String) -> Bool {
        if s.contains("://") { return true }
        if s.contains(" ") { return false }
        return s.contains(".")
    }
}

/// Кнопки закрытия и скрытия в виде «светофоров» обычного окна.
private struct TrafficLight: View {
    let color: Color
    let symbol: String
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                Circle()
                    .strokeBorder(.black.opacity(0.2), lineWidth: 0.5)
                Image(systemName: symbol)
                    .font(.system(size: 6, weight: .heavy))
                    .foregroundStyle(.black.opacity(hovering ? 0.55 : 0))
            }
            .frame(width: 12, height: 12)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

extension Color {
    static let trafficClose = Color(red: 1.0, green: 0.37, blue: 0.34)
    static let trafficMinimize = Color(red: 1.0, green: 0.74, blue: 0.18)
}
