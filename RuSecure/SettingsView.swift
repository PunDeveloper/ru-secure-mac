//
//  SettingsView.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 11.08.2026.
//


import SwiftUI

struct SettingsView: View {
    @AppStorage("useGeosite") private var useGeosite = true
    @AppStorage("useZones") private var useZones = true
    @AppStorage("russianBrowser") private var russianBrowser = "ru.yandex.desktop.yandex-browser"
    @AppStorage("otherBrowser") private var otherBrowser = "com.apple.Safari"
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.google.rawValue

    @State private var newSite = ""
    @State private var asExclude = false
    @State private var includeList = SiteStore.shared.list(.include)
    @State private var excludeList = SiteStore.shared.list(.exclude)
    @State private var geositeUpdated = GeositeStore.shared.updatedText()

    private let browsers = BrowserList.installed()

    var body: some View {
        Form {
            Section("Geosite") {
                Toggle("Использовать список geosite (category-ru)", isOn: $useGeosite)
                Text("Обновлён: \(geositeUpdated)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Обновить сейчас") {
                    Task {
                        await GeositeStore.shared.update()
                        geositeUpdated = GeositeStore.shared.updatedText()
                    }
                }
            }

            Section("Правила") {
                Toggle("Считать .ru и .рф российскими", isOn: $useZones)
            }

            Section("Браузеры") {
                Picker("Для российских сайтов", selection: $russianBrowser) {
                    ForEach(browsers, id: \.bundle) { b in
                        Text(b.name).tag(b.bundle)
                    }
                }
                Picker("Для остальных сайтов", selection: $otherBrowser) {
                    ForEach(browsers, id: \.bundle) { b in
                        Text(b.name).tag(b.bundle)
                    }
                }
            }

            Section("Поиск") {
                Picker("Поисковик в строке поиска", selection: $searchEngine) {
                    ForEach(SearchEngine.allCases) { e in
                        Text(e.displayName).tag(e.rawValue)
                    }
                }
            }

            Section("Добавить сайт") {
                HStack {
                    TextField("https://gosuslugi.ru", text: $newSite)
                    Toggle("Исключение", isOn: $asExclude)
                    Button("Добавить") { add() }
                        .disabled(newSite.isEmpty)
                }
            }

            Section("Российские сайты") {
                listRows(includeList, .include)
            }

            Section("Исключения") {
                listRows(excludeList, .exclude)
            }

            Section {
                Button("Выйти из RuSecure", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 640)
    }

    @ViewBuilder
    private func listRows(_ items: [String], _ kind: SiteStore.Kind) -> some View {
        if items.isEmpty {
            Text("— пусто —")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(items, id: \.self) { site in
                Text(site)
                    .contextMenu {
                        Button("Удалить", role: .destructive) {
                            SiteStore.shared.remove(site, kind)
                            refresh()
                        }
                    }
            }
        }
    }

    private func add() {
        SiteStore.shared.add(newSite, exclude: asExclude)
        newSite = ""
        asExclude = false
        refresh()
    }

    private func refresh() {
        includeList = SiteStore.shared.list(.include)
        excludeList = SiteStore.shared.list(.exclude)
    }
}