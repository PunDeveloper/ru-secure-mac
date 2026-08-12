//
//  SearchWebView.swift
//  RuSecure
//
//  Created by Anton Ivaniv on 12.08.2026.
//

import SwiftUI
import WebKit

/// Небольшой предпросмотр результатов поиска. Любой переход за пределы
/// поисковика перехватывается и отдаётся роутеру: ссылка откроется в нужном
/// браузере, а не внутри оверлея.
struct SearchWebView: NSViewRepresentable {
    var url: URL
    var onOpen: (URL) -> Void
    var onFail: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpen: onOpen, onFail: onFail)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.underPageBackgroundColor = .clear
        // Десктопная вёрстка поисковика шире предпросмотра; масштабируем,
        // чтобы страница помещалась без горизонтальной прокрутки.
        webView.pageZoom = 0.8
        context.coordinator.load(url, into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOpen = onOpen
        context.coordinator.onFail = onFail
        context.coordinator.load(url, into: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var onOpen: (URL) -> Void
        var onFail: () -> Void

        private var currentSearch: URL?
        private var pendingLoads: Set<URL> = []
        private var failed = false
        private var cancelledNavigations = 0

        init(onOpen: @escaping (URL) -> Void, onFail: @escaping () -> Void) {
            self.onOpen = onOpen
            self.onFail = onFail
        }

        func load(_ url: URL, into webView: WKWebView) {
            guard currentSearch != url else { return }
            currentSearch = url
            failed = false
            cancelledNavigations = 0
            pendingLoads.insert(url)
            webView.load(URLRequest(url: url))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            if pendingLoads.remove(url) != nil { return .allow }

            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
            if isMainFrame {
                // Всё в пределах сайта поисковика (редиректы на согласие,
                // региональные домены, пагинация) остаётся в предпросмотре;
                // переходы на другие сайты — ссылки пользователя.
                if let host = url.host, isSameSite(host) { return .allow }
                cancelledNavigations += 1
                onOpen(url)
                return .cancel
            }

            if navigationAction.targetFrame == nil {
                cancelledNavigations += 1
                onOpen(url)
                return .cancel
            }

            return .allow
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            cancelledNavigations = 0
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                onOpen(url)
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            fail(with: error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            fail(with: error)
        }

        private func fail(with error: Error) {
            // Отмена перехваченного перехода тоже приходит ошибкой — не
            // считаем её сбоем загрузки.
            if cancelledNavigations > 0 {
                cancelledNavigations -= 1
                return
            }
            guard (error as NSError).code != NSURLErrorCancelled, !failed else { return }
            failed = true
            onFail()
        }

        private func isSameSite(_ host: String) -> Bool {
            guard let searchHost = currentSearch?.host else { return false }
            return baseDomain(host) == baseDomain(searchHost)
        }

        private func baseDomain(_ host: String) -> String {
            let parts = host.split(separator: ".")
            guard parts.count >= 2 else { return host }
            return parts.suffix(2).joined(separator: ".")
        }
    }
}
