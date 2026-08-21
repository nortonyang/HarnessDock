import AppKit
import SwiftUI
import WebKit

struct HarnessWebView: NSViewRepresentable {
    let url: URL
    let homeRequestID: Int
    let reloadRequestID: Int
    var balancePresentation = BalanceWebPresentation(
        title: "配置 API 余额",
        subtitle: "安全存储在 macOS 钥匙串",
        tone: "neutral",
        state: "notConfigured",
        error: nil,
        updatedLabel: nil,
        entries: []
    )
    var themeBackgroundPresentation = ThemeBackgroundPresentation(
        imageDataURL: nil,
        dimmingOpacity: 0.62
    )
    var onBalanceAction: (String) -> Void = { _ in }
    var onThemeAction: () -> Void = {}
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.balanceBridgeScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
        configuration.userContentController.add(
            WeakScriptMessageHandler(delegate: context.coordinator),
            name: "dshBalance"
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.lastHomeRequestID = homeRequestID
        context.coordinator.lastReloadRequestID = reloadRequestID
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateBalance(in: webView)
        context.coordinator.updateThemeBackground(in: webView)

        if context.coordinator.lastHomeRequestID != homeRequestID {
            context.coordinator.lastHomeRequestID = homeRequestID
            webView.load(URLRequest(url: url))
        } else if context.coordinator.lastReloadRequestID != reloadRequestID {
            context.coordinator.lastReloadRequestID = reloadRequestID
            webView.reload()
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: "dshBalance"
        )
    }

    private static let balanceBridgeScript = #"""
    (() => {
      if (window.__dshBalanceInstalled) return;
      window.__dshBalanceInstalled = true;

      const style = document.createElement('style');
      style.id = 'dsh-native-balance-style';
      style.textContent = `
        html.dsh-has-theme body {
          --dsh-theme-scrim-color: 12,13,18;
          min-height:100%;
          background-color:rgb(12,13,18) !important;
          background-image:
            linear-gradient(
              rgba(var(--dsh-theme-scrim-color), var(--dsh-theme-dimming)),
              rgba(var(--dsh-theme-scrim-color), var(--dsh-theme-dimming))
            ),
            var(--dsh-theme-image) !important;
          background-position:center !important;
          background-size:cover !important;
          background-repeat:no-repeat !important;
          background-attachment:fixed !important;
        }
        html.dsh-has-theme body:not([data-ds-dark-theme]) {
          --dsh-theme-scrim-color: 246,246,248;
          background-color:rgb(246,246,248) !important;
        }
        html.dsh-has-theme #root,
        html.dsh-has-theme #root > div,
        html.dsh-has-theme #root > div > div {
          background-color:transparent !important;
        }
        html.dsh-has-theme .dsh-theme-transparent-surface {
          background-color:transparent !important;
          background-image:none !important;
        }
        #dsh-native-balance {
          position: fixed;
          left: 12px;
          bottom: 48px;
          width: var(--dsh-balance-expanded-width, 232px);
          display:flex;
          flex-direction:column;
          gap:2px;
          transition: width .18s ease;
          z-index: 2147483646;
          color: #e5e7eb;
          font: 12px -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
        }
        #dsh-native-balance * { box-sizing: border-box; }
        #dsh-native-theme-button,
        #dsh-native-balance-button {
          width: 100%;
          min-height: 44px;
          display: flex;
          align-items: center;
          gap: 5px;
          padding: 6px 14px 6px 4px;
          border: 0;
          border-radius: 8px;
          background: transparent;
          color: inherit;
          text-align: left;
          cursor: pointer;
          box-shadow: none;
          appearance: none;
          -webkit-appearance: none;
          position: relative;
        }
        #dsh-native-theme-button {
          order:-1;
        }
        #dsh-native-theme-button:hover,
        #dsh-native-balance-button:hover { background: rgba(255,255,255,.06); }
        #dsh-native-theme-button:focus-visible,
        #dsh-native-balance-button:focus-visible { outline:2px solid rgba(92,124,250,.72); outline-offset:-2px; }
        #dsh-native-theme-icon {
          width:18px;
          height:18px;
          flex:0 0 18px;
          display:flex;
          align-items:center;
          justify-content:center;
          color:#d0d0d5;
        }
        #dsh-native-theme-icon svg { width:16px; height:16px; }
        #dsh-native-theme-label { min-width:0; flex:1; font-size:13px; font-weight:520; line-height:16px; }
        #dsh-native-theme-button[data-active="true"] #dsh-native-theme-icon { color:#9aa8ff; }
        #dsh-native-balance-icon {
          width:18px;
          height:18px;
          flex:0 0 18px;
          display:flex;
          align-items:center;
          justify-content:center;
          position:relative;
        }
        #dsh-native-balance-dot {
          position:absolute;
          top:-2px;
          right:-3px;
          width:5px;
          height:5px;
          border-radius: 999px;
          background: #8b8b92;
          box-shadow: 0 0 0 2px rgba(139,139,146,.12);
        }
        #dsh-native-balance[data-tone="success"] #dsh-native-balance-dot { background:#30d158; box-shadow:0 0 0 2px rgba(48,209,88,.12); }
        #dsh-native-balance[data-tone="loading"] #dsh-native-balance-dot,
        #dsh-native-balance[data-tone="warning"] #dsh-native-balance-dot { background:#ff9f0a; box-shadow:0 0 0 2px rgba(255,159,10,.12); }
        #dsh-native-balance[data-tone="error"] #dsh-native-balance-dot { background:#ff453a; box-shadow:0 0 0 2px rgba(255,69,58,.12); }
        #dsh-native-balance-copy { min-width: 0; flex: 1; }
        #dsh-native-balance-compact-icon { display:block; color:#d0d0d5; font-size:14px; font-weight:650; line-height:1; }
        #dsh-native-balance-title { display:block; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font-size:13px; font-weight:620; line-height:16px; }
        #dsh-native-balance-subtitle { display:block; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; color:#8f8f96; font-size:10.5px; line-height:14px; }
        #dsh-native-balance-chevron { color:#6f6f76; font-size:14px; margin-right:2px; transition:transform .16s ease; }
        #dsh-native-balance[data-expanded="true"] #dsh-native-balance-chevron { transform:rotate(90deg); }
        #dsh-native-balance-panel {
          display: none;
          position: absolute;
          left: 0;
          bottom: 50px;
          width: var(--dsh-balance-expanded-width, 232px);
          padding: 13px;
          border: 1px solid rgba(255,255,255,.09);
          border-radius: 13px;
          background: rgba(32,32,35,.98);
          box-shadow: 0 16px 42px rgba(0,0,0,.34);
          backdrop-filter: blur(22px);
          -webkit-backdrop-filter: blur(22px);
        }
        #dsh-native-balance[data-expanded="true"] #dsh-native-balance-panel { display:block; }
        #dsh-native-balance[data-sidebar-compact="true"] { left:6px; width:40px; }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-button {
          width:40px;
          min-height:40px;
          height:40px;
          justify-content:center;
          padding:0;
          border-color:transparent;
          background:transparent;
          box-shadow:none;
          backdrop-filter:none;
          -webkit-backdrop-filter:none;
        }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-theme-button {
          width:40px;
          min-height:40px;
          height:40px;
          justify-content:center;
          padding:0;
          background:transparent;
        }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-theme-label { display:none; }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-theme-button:hover,
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-button:hover { background:rgba(255,255,255,.07); }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-copy,
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-chevron { display:none; }
        .dsh-balance-header { display:flex; align-items:center; justify-content:space-between; margin:0 0 10px; }
        .dsh-balance-heading { font-weight:650; }
        .dsh-balance-close { width:24px; height:24px; border:0; border-radius:7px; padding:0; background:transparent; color:#8e8e95; font:18px/24px -apple-system, sans-serif; cursor:pointer; }
        .dsh-balance-close:hover { background:rgba(255,255,255,.08); color:#e5e7eb; }
        .dsh-balance-entry { padding:9px 0; border-top:1px solid rgba(255,255,255,.07); }
        .dsh-balance-total { display:flex; justify-content:space-between; align-items:baseline; font-size:19px; font-weight:650; }
        .dsh-balance-currency { color:#8e8e95; font:9px ui-monospace, SFMono-Regular, Menlo, monospace; }
        .dsh-balance-breakdown { display:flex; justify-content:space-between; gap:10px; margin-top:6px; color:#9b9ba1; font-size:9.5px; }
        .dsh-balance-error { color:#ffb340; font-size:10.5px; line-height:15px; }
        .dsh-balance-updated { margin-top:8px; color:#77777e; font-size:9px; }
        .dsh-balance-actions { display:flex; justify-content:space-between; gap:7px; margin-top:11px; }
        .dsh-balance-action { border:0; border-radius:7px; padding:5px 8px; background:rgba(255,255,255,.07); color:#d8d8dc; font:10px -apple-system, sans-serif; cursor:pointer; }
        .dsh-balance-action:hover { background:rgba(255,255,255,.12); }
        .dsh-balance-action-primary { flex:1; background:rgba(91,108,255,.22); color:#dfe3ff; font-weight:600; }
        .dsh-balance-action-primary:hover { background:rgba(91,108,255,.32); }
        @media (prefers-color-scheme: light) {
          #dsh-native-balance { color:#202124; }
          #dsh-native-theme-button,
          #dsh-native-balance-button { background:transparent; box-shadow:none; }
          #dsh-native-theme-button:hover,
          #dsh-native-balance-button:hover { background:rgba(0,0,0,.055); }
          #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-theme-button:hover,
          #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-button:hover { background:rgba(0,0,0,.06); }
          #dsh-native-balance-subtitle { color:#6e6e73; }
          #dsh-native-balance-panel { border-color:rgba(0,0,0,.09); background:rgba(250,250,252,.98); box-shadow:0 16px 42px rgba(0,0,0,.16); }
          .dsh-balance-entry { border-color:rgba(0,0,0,.07); }
          .dsh-balance-action { background:rgba(0,0,0,.06); color:#333338; }
          .dsh-balance-action-primary { background:rgba(74,91,230,.14); color:#3342ad; }
          .dsh-balance-close:hover { background:rgba(0,0,0,.06); color:#202124; }
        }
      `;
      document.head.appendChild(style);

      const root = document.createElement('div');
      root.id = 'dsh-native-balance';
      root.dataset.tone = 'neutral';
      root.dataset.state = 'notConfigured';
      root.dataset.expanded = 'false';
      root.dataset.sidebarCompact = 'false';

      const panel = document.createElement('div');
      panel.id = 'dsh-native-balance-panel';

      const themeButton = document.createElement('button');
      themeButton.id = 'dsh-native-theme-button';
      themeButton.type = 'button';
      themeButton.dataset.active = 'false';
      themeButton.setAttribute('aria-label', '主题背景');
      themeButton.title = '主题背景';

      const themeIcon = document.createElement('span');
      themeIcon.id = 'dsh-native-theme-icon';
      themeIcon.setAttribute('aria-hidden', 'true');
      themeIcon.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><circle cx="9" cy="10" r="1.5"/><path d="m5.5 17 4.2-4.2 3.2 3.1 2.2-2.1 3.4 3.2"/></svg>';
      const themeLabel = document.createElement('span');
      themeLabel.id = 'dsh-native-theme-label';
      themeLabel.textContent = '主题背景';
      themeButton.append(themeIcon, themeLabel);

      const button = document.createElement('button');
      button.id = 'dsh-native-balance-button';
      button.type = 'button';

      const dot = document.createElement('span');
      dot.id = 'dsh-native-balance-dot';

      const icon = document.createElement('span');
      icon.id = 'dsh-native-balance-icon';
      icon.setAttribute('aria-hidden', 'true');

      const compactIcon = document.createElement('span');
      compactIcon.id = 'dsh-native-balance-compact-icon';
      compactIcon.textContent = '¥';
      icon.append(compactIcon, dot);

      const copy = document.createElement('span');
      copy.id = 'dsh-native-balance-copy';
      const title = document.createElement('span');
      title.id = 'dsh-native-balance-title';
      const subtitle = document.createElement('span');
      subtitle.id = 'dsh-native-balance-subtitle';
      copy.append(title, subtitle);

      const chevron = document.createElement('span');
      chevron.id = 'dsh-native-balance-chevron';
      chevron.textContent = '›';
      button.append(icon, copy, chevron);
      button.setAttribute('aria-expanded', 'false');
      root.append(panel, themeButton, button);
      document.body.appendChild(root);

      const setExpanded = expanded => {
        root.dataset.expanded = expanded ? 'true' : 'false';
        button.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      };
      const send = action => {
        setExpanded(false);
        window.webkit.messageHandlers.dshBalance.postMessage(action);
      };
      button.addEventListener('click', () => {
        if (root.dataset.state === 'notConfigured') {
          send('settings');
          return;
        }
        setExpanded(root.dataset.expanded !== 'true');
      });
      themeButton.addEventListener('click', () => {
        setExpanded(false);
        window.webkit.messageHandlers.dshBalance.postMessage('theme');
      });

      document.addEventListener('click', event => {
        if (!root.contains(event.target)) setExpanded(false);
      });
      document.addEventListener('keydown', event => {
        if (event.key === 'Escape') setExpanded(false);
      });

      const accessibleName = element => [
        element.getAttribute('aria-label'),
        element.getAttribute('title'),
        element.textContent
      ].filter(Boolean).join(' ').replace(/\s+/g, ' ').trim();

      const collapsedSidebarNames = ['打开侧边栏', 'Open sidebar', 'Expand sidebar', 'Show sidebar'];
      const expandedSidebarNames = ['收起侧边栏', 'Close sidebar', 'Collapse sidebar', 'Hide sidebar'];
      const expandedSidebarWidth = button => {
        let candidate = button;
        let sidebarWidth = null;
        while (candidate && candidate !== document.body) {
          const rect = candidate.getBoundingClientRect();
          if (rect.left <= 3
              && rect.width >= 180
              && rect.width <= 360
              && rect.height >= window.innerHeight * .7) {
            sidebarWidth = rect.width;
          }
          candidate = candidate.parentElement;
        }
        return sidebarWidth;
      };
      const updateSidebarMode = () => {
        let compact = null;
        for (const candidate of document.querySelectorAll('button')) {
          if (root.contains(candidate)) continue;
          const name = accessibleName(candidate);
          if (collapsedSidebarNames.some(label => name.includes(label))) {
            compact = true;
            break;
          }
          if (expandedSidebarNames.some(label => name.includes(label))) {
            compact = false;
            const sidebarWidth = expandedSidebarWidth(candidate);
            if (sidebarWidth) {
              root.style.setProperty(
                '--dsh-balance-expanded-width',
                `${Math.max(196, Math.round(sidebarWidth) - 24)}px`
              );
            }
            break;
          }
        }
        if (compact === null) return;
        root.dataset.sidebarCompact = compact ? 'true' : 'false';
        if (compact) setExpanded(false);
      };

      let sidebarUpdateQueued = false;
      const queueSidebarUpdate = () => {
        if (sidebarUpdateQueued) return;
        sidebarUpdateQueued = true;
        requestAnimationFrame(() => {
          sidebarUpdateQueued = false;
          updateSidebarMode();
        });
      };
      new MutationObserver(mutations => {
        const relevant = mutations.some(mutation => {
          if (root.contains(mutation.target)) return false;
          if (mutation.target.matches?.('button')) return true;
          return Array.from(mutation.addedNodes).some(node =>
            node.nodeType === Node.ELEMENT_NODE
              && (node.matches?.('button') || node.querySelector?.('button'))
          );
        });
        if (!relevant) return;
        queueSidebarUpdate();
      }).observe(document.body, {
        subtree: true,
        childList: true,
        attributes: true,
        attributeFilter: ['aria-label', 'title', 'data-state']
      });
      document.addEventListener('click', () => setTimeout(queueSidebarUpdate, 0), true);
      window.addEventListener('resize', queueSidebarUpdate);
      queueSidebarUpdate();

      let themeSurfaceUpdateQueued = false;
      const updateThemeSurfaces = () => {
        const pageRoot = document.getElementById('root');
        if (!pageRoot) return;

        const enabled = document.documentElement.classList.contains('dsh-has-theme');
        const viewportArea = Math.max(1, window.innerWidth * window.innerHeight);
        const candidates = [
          pageRoot,
          ...pageRoot.querySelectorAll('div, main, aside, section')
        ];

        for (const candidate of candidates) {
          const rect = candidate.getBoundingClientRect();
          const coversLargeArea = rect.width * rect.height >= viewportArea * .28;
          const isTallLayoutSurface = rect.width >= 160
            && rect.height >= window.innerHeight * .72;
          const shouldBeTransparent = enabled
            && (candidate === pageRoot || coversLargeArea || isTallLayoutSurface);
          candidate.classList.toggle(
            'dsh-theme-transparent-surface',
            shouldBeTransparent
          );
        }
      };
      const queueThemeSurfaceUpdate = () => {
        if (themeSurfaceUpdateQueued) return;
        themeSurfaceUpdateQueued = true;
        requestAnimationFrame(() => {
          themeSurfaceUpdateQueued = false;
          updateThemeSurfaces();
        });
      };
      new MutationObserver(queueThemeSurfaceUpdate).observe(document.body, {
        subtree: true,
        childList: true
      });
      document.addEventListener(
        'click',
        () => setTimeout(queueThemeSurfaceUpdate, 0),
        true
      );
      window.addEventListener('resize', queueThemeSurfaceUpdate);

      const text = (tag, value, className) => {
        const node = document.createElement(tag);
        node.textContent = value;
        if (className) node.className = className;
        return node;
      };

      window.__dshBalanceUpdate = payload => {
        root.dataset.tone = payload.tone;
        root.dataset.state = payload.state;
        title.textContent = payload.title;
        subtitle.textContent = payload.subtitle;
        button.setAttribute('aria-label', `${payload.title}，${payload.subtitle}`);
        panel.replaceChildren();

        const header = document.createElement('div');
        header.className = 'dsh-balance-header';
        header.appendChild(text('div', 'DeepSeek API 余额', 'dsh-balance-heading'));
        const close = text('button', '×', 'dsh-balance-close');
        close.type = 'button';
        close.setAttribute('aria-label', '收起余额明细');
        close.title = '收起';
        close.addEventListener('click', event => { event.stopPropagation(); setExpanded(false); });
        header.appendChild(close);
        panel.appendChild(header);

        if (payload.error) {
          panel.appendChild(text('div', payload.error, 'dsh-balance-error'));
        }

        for (const entry of payload.entries || []) {
          const item = document.createElement('div');
          item.className = 'dsh-balance-entry';
          const total = document.createElement('div');
          total.className = 'dsh-balance-total';
          total.append(text('span', entry.total), text('span', entry.currency, 'dsh-balance-currency'));
          const breakdown = document.createElement('div');
          breakdown.className = 'dsh-balance-breakdown';
          breakdown.append(text('span', `赠送 ${entry.granted}`), text('span', `充值 ${entry.toppedUp}`));
          item.append(total, breakdown);
          panel.appendChild(item);
        }

        if (payload.state === 'loading') {
          panel.appendChild(text('div', '正在向 DeepSeek 查询余额…', 'dsh-balance-updated'));
        } else if (payload.updatedLabel) {
          panel.appendChild(text('div', payload.updatedLabel, 'dsh-balance-updated'));
        }

        const actions = document.createElement('div');
        actions.className = 'dsh-balance-actions';
        const settings = text('button', '配置 API Key', 'dsh-balance-action dsh-balance-action-primary');
        settings.type = 'button';
        settings.addEventListener('click', event => { event.stopPropagation(); send('settings'); });
        const refresh = text('button', '刷新', 'dsh-balance-action');
        refresh.type = 'button';
        refresh.addEventListener('click', event => { event.stopPropagation(); send('refresh'); });
        actions.append(settings, refresh);
        panel.appendChild(actions);
      };

      window.__dshThemeUpdate = payload => {
        const imageDataURL = payload.imageDataURL || '';
        const enabled = imageDataURL.length > 0;
        document.documentElement.classList.toggle('dsh-has-theme', enabled);
        themeButton.dataset.active = enabled ? 'true' : 'false';
        themeButton.setAttribute('aria-label', enabled ? '主题背景，已设置' : '主题背景');

        if (!enabled) {
          document.body.style.removeProperty('--dsh-theme-image');
          document.body.style.removeProperty('--dsh-theme-dimming');
          queueThemeSurfaceUpdate();
          return;
        }

        const dimming = Math.min(.85, Math.max(.25, Number(payload.dimmingOpacity) || .62));
        document.body.style.setProperty('--dsh-theme-image', `url("${imageDataURL}")`);
        document.body.style.setProperty('--dsh-theme-dimming', String(dimming));
        queueThemeSurfaceUpdate();
      };
      if (window.__dshPendingThemePayload) {
        window.__dshThemeUpdate(window.__dshPendingThemePayload);
        window.__dshPendingThemePayload = null;
      }
    })();
    """#

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: HarnessWebView
        var lastHomeRequestID = 0
        var lastReloadRequestID = 0
        private var lastBalanceJSON: String?
        private var lastThemeBackgroundJSON: String?

        init(parent: HarnessWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.loadError = nil
            lastBalanceJSON = nil
            lastThemeBackgroundJSON = nil
            updateBalance(in: webView)
            updateThemeBackground(in: webView)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "dshBalance",
                  let action = message.body as? String
            else {
                return
            }
            if action == "theme" {
                parent.onThemeAction()
                return
            }
            guard action == "settings" || action == "refresh" else { return }
            parent.onBalanceAction(action)
        }

        func updateBalance(in webView: WKWebView) {
            guard let data = try? JSONEncoder().encode(parent.balancePresentation),
                  let json = String(data: data, encoding: .utf8),
                  json != lastBalanceJSON
            else {
                return
            }
            lastBalanceJSON = json
            webView.evaluateJavaScript("window.__dshBalanceUpdate?.(\(json));")
        }

        func updateThemeBackground(in webView: WKWebView) {
            guard let data = try? JSONEncoder().encode(parent.themeBackgroundPresentation),
                  let json = String(data: data, encoding: .utf8),
                  json != lastThemeBackgroundJSON
            else {
                return
            }
            lastThemeBackgroundJSON = json
            webView.evaluateJavaScript("""
            window.__dshPendingThemePayload = \(json);
            if (window.__dshThemeUpdate) {
              window.__dshThemeUpdate(window.__dshPendingThemePayload);
              window.__dshPendingThemePayload = null;
            }
            """)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            updateFailure(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            updateFailure(error)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let destination = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let allowedHosts = Set(["127.0.0.1", "localhost"])
            if let host = destination.host, !allowedHosts.contains(host) {
                NSWorkspace.shared.open(destination)
                decisionHandler(.cancel)
                return
            }

            if navigationAction.targetFrame == nil {
                NSWorkspace.shared.open(destination)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let destination = navigationAction.request.url {
                NSWorkspace.shared.open(destination)
            }
            return nil
        }

        private func updateFailure(_ error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
