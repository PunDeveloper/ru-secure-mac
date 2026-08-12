import AppKit

final class Router {
    static let shared = Router()

    private(set) var focusTarget: NSRunningApplication?
    private(set) var focusDeadline = Date.distantPast
    private var focusRetry: DispatchWorkItem?

    var isRouting: Bool { Date() < focusDeadline }

    func route(_ url: URL) {
        focusTarget = nil
        focusDeadline = Date().addingTimeInterval(2)

        let host = url.host?.lowercased() ?? ""
        let russian = isRussian(host)
        let candidates = russian
            ? [SettingsStore.russianBrowser, SettingsStore.otherBrowser]
            : [SettingsStore.otherBrowser, SettingsStore.russianBrowser]

        for bundleId in candidates {
            guard let appURL = NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: bundleId) else { continue }
            let configuration = NSWorkspace.OpenConfiguration()
            // Иначе браузер откроет ссылку, но останется в фоне: фокус и
            // переход на Space с фуллскрин-браузером требуют активации.
            configuration.activates = true
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: appURL,
                configuration: configuration
            ) { app, _ in
                // По клику на ссылку macOS активирует RuSecure как браузер по
                // умолчанию; возвращаем активацию браузеру, принявшему ссылку.
                guard let app else { return }
                DispatchQueue.main.async {
                    Router.shared.focusTarget = app
                    Router.shared.attemptFocus()
                }
            }
            return
        }

        // NSWorkspace.open(url) здесь вызывать нельзя: RuSecure — браузер по
        // умолчанию, и ссылка вернулась бы обратно в него бесконечным циклом.
        let alert = NSAlert()
        alert.messageText = "Не удалось открыть ссылку"
        alert.informativeText = "Выбранный браузер не найден. Проверьте настройки RuSecure."
        alert.runModal()
    }

    /// Возвращает фокус браузеру, принявшему ссылку: macOS может активировать
    /// RuSecure (браузер по умолчанию) позже, чем ссылка ушла дальше, поэтому
    /// повторяем попытку, пока цель не станет активной или не истечёт окно.
    func attemptFocus() {
        guard let focusTarget, !focusTarget.isTerminated,
              !focusTarget.isActive, Date() < focusDeadline else {
            focusRetry?.cancel()
            return
        }
        if NSApp.isActive {
            NSApp.yieldActivation(to: focusTarget)
        }
        _ = focusTarget.activate()
        focusRetry?.cancel()
        let item = DispatchWorkItem { Router.shared.attemptFocus() }
        focusRetry = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }

    private func isRussian(_ host: String) -> Bool {
        guard !host.isEmpty else { return false }

        if SiteStore.shared.matches(host, in: .exclude) { return false }
        if SiteStore.shared.matches(host, in: .include) { return true }

        if SettingsStore.useGeosite, GeositeStore.shared.matches(host) {
            return true
        }

        if SettingsStore.useZones {
            return host.hasSuffix(".ru") || host.hasSuffix(".xn--p1ai")
        }

        return false
    }
}
