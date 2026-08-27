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
        entries: [],
        pricing: nil,
        labels: BalanceWebPresentation.Labels(
            language: "zh-Hans",
            themeBackground: "主题背景",
            themeBackgroundConfigured: "主题背景，已设置",
            balanceHeading: "DeepSeek API 余额",
            peakPeriod: "高峰期",
            offPeakPeriod: "谷时",
            collapseBalanceDetails: "收起余额明细",
            collapse: "收起",
            grantedPrefix: "赠送",
            toppedUpPrefix: "充值",
            loadingBalance: "正在向 DeepSeek 查询余额…",
            sessionTokens: "当前会话 tokens",
            noUsage: "暂无用量",
            input: "输入",
            output: "输出",
            viewModelPricing: "查看模型价格",
            cacheHit: "命中",
            cacheMiss: "未命中",
            configureAPIKey: "配置 API Key",
            refresh: "刷新"
        )
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
        #dsh-native-balance-title-row { min-width:0; display:flex; align-items:center; gap:6px; }
        #dsh-native-balance-title { min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font-size:13px; font-weight:620; line-height:16px; }
        #dsh-native-pricing-badge { display:none; flex:0 0 auto; align-items:center; min-height:17px; padding:1px 6px; border-radius:999px; font-size:9px; font-weight:720; line-height:13px; }
        #dsh-native-balance[data-pricing-period="peak"] #dsh-native-pricing-badge { display:inline-flex; color:#ffd197; background:rgba(255,159,10,.20); box-shadow:0 0 0 1px rgba(255,159,10,.12) inset; }
        #dsh-native-balance[data-pricing-period="offPeak"] #dsh-native-pricing-badge { display:inline-flex; color:#b7f7ca; background:rgba(48,209,88,.16); box-shadow:0 0 0 1px rgba(48,209,88,.10) inset; }
        #dsh-native-balance-subtitle { display:block; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; color:#8f8f96; font-size:10.5px; line-height:14px; }
        #dsh-native-balance-chevron { color:#6f6f76; font-size:14px; margin-right:2px; transition:transform .16s ease; }
        #dsh-native-balance[data-expanded="true"] #dsh-native-balance-chevron { transform:rotate(90deg); }
        #dsh-native-balance-panel {
          display: none;
          position: absolute;
          left: 0;
          bottom: 94px;
          z-index: 2;
          width: min(340px, calc(100vw - 24px));
          max-height: calc(100vh - 154px);
          overflow-y: auto;
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
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-panel {
          bottom:86px;
          max-height:calc(100vh - 146px);
        }
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
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-theme-icon,
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-icon {
          width:24px;
          height:24px;
          flex:0 0 24px;
          transform:translateX(2px);
        }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-theme-icon svg {
          width:24px;
          height:24px;
        }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-compact-icon {
          width:18px;
          height:18px;
          display:flex;
          align-items:center;
          justify-content:center;
          border:1.5px solid currentColor;
          border-radius:999px;
          font-size:11px;
          font-weight:700;
        }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-dot {
          top:0;
          right:0;
        }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-theme-label { display:none; }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-theme-button:hover,
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-button:hover { background:rgba(255,255,255,.07); }
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-copy,
        #dsh-native-balance[data-sidebar-compact="true"] #dsh-native-balance-chevron { display:none; }
        .dsh-balance-header { display:flex; align-items:center; justify-content:space-between; gap:8px; margin:0 0 8px; }
        .dsh-balance-heading-row { min-width:0; display:flex; align-items:center; gap:7px; }
        .dsh-balance-heading { font-weight:650; }
        .dsh-balance-close { width:24px; height:24px; border:0; border-radius:7px; padding:0; background:transparent; color:#8e8e95; font:18px/24px -apple-system, sans-serif; cursor:pointer; }
        .dsh-balance-close:hover { background:rgba(255,255,255,.08); color:#e5e7eb; }
        .dsh-balance-entry { padding:9px 0; border-top:1px solid rgba(255,255,255,.07); }
        .dsh-balance-total { display:flex; justify-content:space-between; align-items:baseline; font-size:19px; font-weight:650; }
        .dsh-balance-currency { color:#8e8e95; font:9px ui-monospace, SFMono-Regular, Menlo, monospace; }
        .dsh-balance-breakdown { display:flex; justify-content:space-between; gap:10px; margin-top:6px; color:#9b9ba1; font-size:9.5px; }
        .dsh-balance-error { color:#ffb340; font-size:10.5px; line-height:15px; }
        .dsh-balance-updated { margin-top:8px; color:#77777e; font-size:9px; }
        .dsh-session-usage { display:flex; align-items:center; justify-content:space-between; gap:9px; margin-top:9px; padding:8px 9px; border-radius:8px; background:rgba(255,255,255,.045); }
        .dsh-session-usage-label { flex:0 0 auto; color:#8f8f96; font-size:9px; }
        .dsh-session-usage-values { min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; color:#d4d4d9; font-size:9.5px; font-weight:620; text-align:right; }
        .dsh-pricing-status { margin-bottom:2px; padding:1px 0 8px; }
        .dsh-pricing-pill { flex:0 0 auto; border-radius:999px; padding:4px 9px; color:#b7f7ca; background:rgba(48,209,88,.16); font-size:10px; font-weight:720; }
        #dsh-native-balance-panel[data-pricing-period="peak"] .dsh-pricing-pill { color:#ffd197; background:rgba(255,159,10,.16); }
        .dsh-pricing-next { color:#d0d0d5; font-size:10.5px; font-weight:600; }
        .dsh-pricing-schedule { margin-top:3px; color:#83838a; font-size:9px; line-height:13px; }
        .dsh-pricing-details { margin-top:9px; }
        .dsh-pricing-details > summary { min-height:32px; display:flex; align-items:center; justify-content:space-between; gap:8px; padding:7px 9px; border-radius:8px; color:#c7c7cc; background:rgba(255,255,255,.055); cursor:pointer; list-style:none; }
        .dsh-pricing-details > summary::-webkit-details-marker { display:none; }
        .dsh-pricing-details > summary::after { content:'›'; color:#7f7f87; font-size:15px; transition:transform .16s ease; }
        .dsh-pricing-details[open] > summary::after { transform:rotate(90deg); }
        .dsh-pricing-summary-label { font-size:10.5px; font-weight:620; }
        .dsh-pricing-summary-copy { min-width:0; display:flex; align-items:baseline; gap:7px; }
        .dsh-pricing-unit { color:#77777e; font-size:8.5px; }
        .dsh-pricing-model { margin-top:7px; padding:9px; border:1px solid rgba(255,255,255,.065); border-radius:9px; background:rgba(255,255,255,.025); }
        .dsh-pricing-model-name { font-size:10.5px; font-weight:650; }
        .dsh-pricing-model-id { margin-top:1px; color:#73737b; font:8px ui-monospace, SFMono-Regular, Menlo, monospace; }
        .dsh-pricing-grid { display:grid; grid-template-columns:42px repeat(3, minmax(0, 1fr)); gap:2px; margin-top:7px; font-size:8.5px; text-align:right; }
        .dsh-pricing-cell { min-width:0; padding:3px 2px; border-radius:5px; white-space:nowrap; }
        .dsh-pricing-grid-header { color:#77777e; font-size:8px; }
        .dsh-pricing-period { text-align:left; color:#919198; font-weight:650; }
        .dsh-pricing-current-row { color:#f1f1f4; background:rgba(91,108,255,.16); }
        .dsh-pricing-source { width:100%; margin-top:8px; padding:5px 8px; border:0; border-radius:7px; color:#aeb7ff; background:rgba(91,108,255,.11); font:9px -apple-system, sans-serif; cursor:pointer; }
        .dsh-pricing-source:hover { background:rgba(91,108,255,.20); }
        .dsh-balance-actions { display:flex; justify-content:space-between; gap:7px; margin-top:11px; }
        .dsh-balance-action { border:0; border-radius:7px; padding:5px 8px; background:rgba(255,255,255,.07); color:#d8d8dc; font:10px -apple-system, sans-serif; cursor:pointer; }
        .dsh-balance-action:hover { background:rgba(255,255,255,.12); }
        .dsh-balance-action-primary { flex:1; background:rgba(91,108,255,.22); color:#dfe3ff; font-weight:600; }
        .dsh-balance-action-primary:hover { background:rgba(91,108,255,.32); }
        #dsh-settings-guide-launcher {
          min-height: 36px;
          display:inline-flex;
          align-items:center;
          gap:6px;
          margin-right:8px;
          padding:0 13px;
          border:1px solid rgba(145,134,255,.34);
          border-radius:999px;
          background:rgba(105,89,255,.13);
          color:#d9d5ff;
          font:600 13px/1 -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
          cursor:pointer;
          appearance:none;
          -webkit-appearance:none;
        }
        #dsh-settings-guide-launcher:hover { background:rgba(105,89,255,.22); }
        #dsh-settings-guide-launcher:focus-visible { outline:2px solid rgba(145,134,255,.78); outline-offset:2px; }
        #dsh-settings-guide-root { position:fixed; inset:0; z-index:2147483647; font-family:-apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; }
        #dsh-settings-guide-backdrop { position:fixed; inset:0; background:rgba(5,6,10,.66); cursor:default; }
        #dsh-settings-guide-root[data-has-target="true"] #dsh-settings-guide-backdrop { background:transparent; }
        #dsh-settings-guide-highlight {
          position:fixed;
          display:none;
          border:2px solid #8f83ff;
          border-radius:13px;
          box-shadow:0 0 0 9999px rgba(5,6,10,.66), 0 0 0 5px rgba(143,131,255,.18);
          pointer-events:none;
          transition:left .18s ease, top .18s ease, width .18s ease, height .18s ease;
        }
        #dsh-settings-guide-card {
          position:fixed;
          left:50%;
          bottom:28px;
          width:min(470px, calc(100vw - 40px));
          transform:translateX(-50%);
          padding:22px;
          border:1px solid rgba(255,255,255,.13);
          border-radius:18px;
          background:rgba(37,37,42,.98);
          color:#f4f4f7;
          box-shadow:0 24px 80px rgba(0,0,0,.48);
          backdrop-filter:blur(24px);
          -webkit-backdrop-filter:blur(24px);
        }
        #dsh-settings-guide-card[data-placement="top"] { top:88px; bottom:auto; }
        .dsh-settings-guide-kicker { color:#a9a0ff; font-size:11px; font-weight:720; letter-spacing:.05em; }
        .dsh-settings-guide-heading { margin:8px 0 7px; font-size:20px; line-height:1.28; }
        .dsh-settings-guide-body { margin:0; color:#c7c7ce; font-size:13px; line-height:1.65; }
        .dsh-settings-guide-tips { margin:13px 0 0; padding:12px 14px 12px 30px; border-radius:11px; background:rgba(255,255,255,.055); color:#dedee4; font-size:12px; line-height:1.55; }
        .dsh-settings-guide-tips li + li { margin-top:4px; }
        .dsh-settings-guide-recommendation { margin-top:12px; color:#c9f5d5; font-size:12px; font-weight:620; line-height:1.5; }
        .dsh-settings-guide-footer { display:flex; align-items:center; gap:8px; margin-top:18px; }
        .dsh-settings-guide-progress { display:flex; gap:5px; margin-right:auto; }
        .dsh-settings-guide-dot { width:6px; height:6px; border-radius:999px; background:#606067; }
        .dsh-settings-guide-dot[data-active="true"] { width:17px; background:#8f83ff; }
        .dsh-settings-guide-action { min-height:34px; padding:0 13px; border:0; border-radius:9px; background:rgba(255,255,255,.08); color:#e8e8ec; font:600 12px/1 -apple-system, sans-serif; cursor:pointer; }
        .dsh-settings-guide-action:hover { background:rgba(255,255,255,.13); }
        .dsh-settings-guide-action-primary { background:#6657e8; color:white; }
        .dsh-settings-guide-action-primary:hover { background:#7566f1; }
        .dsh-settings-guide-action:disabled { opacity:.38; cursor:default; }
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
          .dsh-pricing-next { color:#505057; }
          .dsh-pricing-details > summary { color:#34343a; background:rgba(0,0,0,.04); }
          .dsh-session-usage { background:rgba(0,0,0,.035); }
          .dsh-session-usage-label { color:#717178; }
          .dsh-session-usage-values { color:#34343a; }
          .dsh-pricing-schedule,
          .dsh-pricing-unit,
          .dsh-pricing-model-id,
          .dsh-pricing-grid-header { color:#73737a; }
          .dsh-pricing-model { border-color:rgba(0,0,0,.07); background:rgba(0,0,0,.018); }
          .dsh-pricing-current-row { color:#263181; background:rgba(74,91,230,.12); }
          .dsh-balance-action { background:rgba(0,0,0,.06); color:#333338; }
          .dsh-balance-action-primary { background:rgba(74,91,230,.14); color:#3342ad; }
          .dsh-balance-close:hover { background:rgba(0,0,0,.06); color:#202124; }
          #dsh-settings-guide-launcher { border-color:rgba(80,67,202,.25); background:rgba(80,67,202,.09); color:#4437a5; }
          #dsh-settings-guide-card { border-color:rgba(0,0,0,.10); background:rgba(251,251,253,.98); color:#202124; box-shadow:0 24px 80px rgba(0,0,0,.24); }
          .dsh-settings-guide-body { color:#5d5d64; }
          .dsh-settings-guide-tips { background:rgba(0,0,0,.045); color:#36363c; }
          .dsh-settings-guide-recommendation { color:#23733b; }
          .dsh-settings-guide-action { background:rgba(0,0,0,.07); color:#303036; }
          .dsh-settings-guide-action-primary { background:#594bd0; color:white; }
        }
      `;
      document.head.appendChild(style);

      const root = document.createElement('div');
      root.id = 'dsh-native-balance';
      root.dataset.tone = 'neutral';
      root.dataset.state = 'notConfigured';
      root.dataset.expanded = 'false';
      root.dataset.sidebarCompact = 'false';

      const labels = {
        language: 'zh-Hans',
        themeBackground: '主题背景',
        themeBackgroundConfigured: '主题背景，已设置',
        balanceHeading: 'DeepSeek API 余额',
        peakPeriod: '高峰期',
        offPeakPeriod: '谷时',
        collapseBalanceDetails: '收起余额明细',
        collapse: '收起',
        grantedPrefix: '赠送',
        toppedUpPrefix: '充值',
        loadingBalance: '正在向 DeepSeek 查询余额…',
        sessionTokens: '当前会话 tokens',
        noUsage: '暂无用量',
        input: '输入',
        output: '输出',
        viewModelPricing: '查看模型价格',
        cacheHit: '命中',
        cacheMiss: '未命中',
        configureAPIKey: '配置 API Key',
        refresh: '刷新'
      };

      const panel = document.createElement('div');
      panel.id = 'dsh-native-balance-panel';

      const themeButton = document.createElement('button');
      themeButton.id = 'dsh-native-theme-button';
      themeButton.type = 'button';
      themeButton.dataset.active = 'false';
      themeButton.setAttribute('aria-label', labels.themeBackground);
      themeButton.title = labels.themeBackground;

      const themeIcon = document.createElement('span');
      themeIcon.id = 'dsh-native-theme-icon';
      themeIcon.setAttribute('aria-hidden', 'true');
      themeIcon.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><circle cx="9" cy="10" r="1.5"/><path d="m5.5 17 4.2-4.2 3.2 3.1 2.2-2.1 3.4 3.2"/></svg>';
      const themeLabel = document.createElement('span');
      themeLabel.id = 'dsh-native-theme-label';
      themeLabel.textContent = labels.themeBackground;
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
      const titleRow = document.createElement('span');
      titleRow.id = 'dsh-native-balance-title-row';
      const title = document.createElement('span');
      title.id = 'dsh-native-balance-title';
      const pricingBadge = document.createElement('span');
      pricingBadge.id = 'dsh-native-pricing-badge';
      const subtitle = document.createElement('span');
      subtitle.id = 'dsh-native-balance-subtitle';
      titleRow.append(title, pricingBadge);
      copy.append(titleRow, subtitle);

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

      const settingsGuideStorageKey = 'dsh-settings-guide-seen-v3';
      const settingsGuideStepsByLanguage = {
        'zh-Hans': [
        {
          section: '先认识这页',
          title: '设置只决定 Harness 怎么工作',
          body: '这里配置的是代码智能体，不是 DeepSeek 免费聊天。带“默认”含义的选项通常作用于新会话，语言和外观则会直接改变界面。',
          tips: [
            '不确定时先保留默认值，之后随时可以回来修改。',
            '右上角“打开配置文件”适合熟悉配置格式后再使用。'
          ],
          recommendation: '建议：第一次只了解通用设置、权限和模型即可。',
          targetLabels: ['通用设置', 'General'],
          targetZone: 'sidebar'
        },
        {
          section: '默认工作方式',
          title: 'Agent 预设：新会话采用哪套工作习惯',
          body: '预设会组合智能体的默认行为。截图里的“标准模式”适合大多数日常开发；正在运行的会话通常会继续使用它开始时的预设。',
          tips: [
            '标准模式：优先选择，适合读代码、修改文件和运行验证。',
            '需要特殊流程时，再到左侧“Agent 预设”管理或切换。'
          ],
          recommendation: '建议：先保持“标准模式”。',
          targetLabels: ['Agent 预设', 'Agent preset'],
          targetZone: 'main'
        },
        {
          section: '最重要的安全选项',
          title: '权限：决定智能体能操作到哪里',
          body: '权限会影响读取文件、修改代码和执行工具的范围。权限越大越方便，也越需要确认当前项目和指令是否可信。',
          tips: [
            'Workspace Write：允许在当前工作区内读写，适合正常开发。',
            '更严格的模式更安全，但部分自动修改或验证可能无法完成。',
            '只有理解用途时，才选择范围更大的权限。'
          ],
          recommendation: '建议：日常项目使用 Workspace Write。',
          targetLabels: ['权限', 'Permissions'],
          targetZone: 'main'
        },
        {
          section: '界面偏好',
          title: '语言与外观：只改变使用体验',
          body: '语言决定界面文案；浅色、深色和跟随系统只影响显示效果，不会改变模型能力、费用或文件权限。',
          tips: [
            '中文：适合直接阅读界面说明。',
            '跟随系统：会随 macOS 的浅色/深色模式自动切换。'
          ],
          recommendation: '建议：中文 + 跟随系统。',
          targetLabels: ['外观', 'Appearance'],
          targetZone: 'main'
        },
        {
          section: '智能体忙碌时',
          title: 'Enter 键行为：新消息现在发还是排队',
          body: '这一项只在智能体正在执行任务时生效。“排队发送”会把新消息放到后面，避免当前工作被意外打断；Cmd/Ctrl+Enter 会使用另一种行为。',
          tips: [
            '补充不紧急的信息时，排队发送更稳妥。',
            '需要立刻调整当前方向时，再使用另一种发送行为。'
          ],
          recommendation: '建议：先保持“排队发送”。',
          targetLabels: ['繁忙时 Enter 键行为', 'Enter key behavior while busy'],
          targetZone: 'main'
        },
        {
          section: '左侧其他入口',
          title: '模型、插件和 Agent 预设分别管什么',
          body: '模型决定 Harness 调用哪个模型服务；插件为 Harness 增加能力；Agent 预设用于管理可重复使用的工作方式。它们都与顶部的 DeepSeek 免费 Chat 登录相互独立。',
          tips: [
            '模型：选择或配置 Harness 实际使用的模型。',
            '插件：扩展工具和界面，只启用你信任的来源。',
            'Agent 预设：创建或管理适合不同任务的默认工作方式。'
          ],
          recommendation: '建议：先确认模型可用；插件和自定义预设按需开启。',
          targetLabels: ['模型', 'Models'],
          targetZone: 'sidebar'
        }
        ],
        en: [
          {
            section: 'Start here',
            title: 'Settings control how Harness works',
            body: 'These settings configure the coding agent, not DeepSeek Chat. Defaults usually affect new sessions, while language and appearance update the interface directly.',
            tips: [
              'Keep the defaults when you are unsure; you can return at any time.',
              'Use “Open config file” only after you are familiar with the configuration format.'
            ],
            recommendation: 'Recommended: start with General, Permissions, and Models.',
            targetLabels: ['通用设置', 'General'],
            targetZone: 'sidebar'
          },
          {
            section: 'Default workflow',
            title: 'Agent preset: choose the habits for new sessions',
            body: 'A preset combines the agent’s default behaviors. Standard mode works well for most development tasks; running sessions usually keep the preset they started with.',
            tips: [
              'Standard mode is a good default for reading code, editing files, and running checks.',
              'Create or switch presets only when you need a specialized workflow.'
            ],
            recommendation: 'Recommended: keep Standard mode at first.',
            targetLabels: ['Agent 预设', 'Agent preset'],
            targetZone: 'main'
          },
          {
            section: 'Most important safety control',
            title: 'Permissions decide what the agent can access',
            body: 'Permissions control the scope for reading files, editing code, and running tools. Broader access is convenient, but requires more confidence in the project and instructions.',
            tips: [
              'Workspace Write allows normal read and write work inside the current workspace.',
              'Stricter modes are safer, but may prevent some automatic edits or checks.',
              'Choose broader access only when you understand why it is needed.'
            ],
            recommendation: 'Recommended: use Workspace Write for everyday projects.',
            targetLabels: ['权限', 'Permissions'],
            targetZone: 'main'
          },
          {
            section: 'Interface preferences',
            title: 'Language and appearance affect only the experience',
            body: 'Language changes interface text. Light, dark, and system appearance affect only visuals—not model capability, pricing, or file permissions.',
            tips: [
              'Choose the language that makes the settings easiest to understand.',
              'Follow System tracks the macOS light and dark appearance.'
            ],
            recommendation: 'Recommended: your preferred language + Follow System.',
            targetLabels: ['外观', 'Appearance'],
            targetZone: 'main'
          },
          {
            section: 'While the agent is busy',
            title: 'Enter key behavior: send now or queue a message',
            body: 'This setting applies only while the agent is running. Queueing adds a message after the current work and avoids accidental interruption; Cmd/Ctrl+Enter uses the alternate behavior.',
            tips: [
              'Queue non-urgent context to keep the current task stable.',
              'Use the alternate behavior when you need to redirect the current work immediately.'
            ],
            recommendation: 'Recommended: keep Queue Send at first.',
            targetLabels: ['繁忙时 Enter 键行为', 'Enter key behavior while busy'],
            targetZone: 'main'
          },
          {
            section: 'Other sections',
            title: 'Models, plugins, and agent presets have different jobs',
            body: 'Models choose the service Harness calls. Plugins add capabilities. Agent presets store reusable workflows. All three are independent from DeepSeek Chat login.',
            tips: [
              'Models: choose or configure the model Harness actually uses.',
              'Plugins: extend tools and interface; enable only trusted sources.',
              'Agent presets: manage reusable defaults for different tasks.'
            ],
            recommendation: 'Recommended: confirm a model works first; add plugins and custom presets as needed.',
            targetLabels: ['模型', 'Models'],
            targetZone: 'sidebar'
          }
        ]
      };
      const settingsGuideSteps = [...settingsGuideStepsByLanguage['zh-Hans']];
      const settingsGuideCopyByLanguage = {
        'zh-Hans': {
          dialogLabel: 'Harness 设置快速上手',
          launcher: '？ 新手引导',
          launcherLabel: '打开 Harness 设置新手引导',
          later: '稍后再看',
          previous: '上一步',
          next: '下一步',
          done: '完成'
        },
        en: {
          dialogLabel: 'Harness Settings Quick Start',
          launcher: '? Quick Start',
          launcherLabel: 'Open the Harness settings quick start',
          later: 'Later',
          previous: 'Previous',
          next: 'Next',
          done: 'Done'
        }
      };
      const settingsGuideCopy = { ...settingsGuideCopyByLanguage['zh-Hans'] };
      let settingsGuideRoot = null;
      let settingsGuideLauncher = null;
      let settingsGuideStep = 0;
      let settingsGuideAutoScheduled = false;

      const settingsGuideIsVisible = element => {
        if (!element || !element.isConnected) return false;
        const style = getComputedStyle(element);
        if (style.display === 'none' || style.visibility === 'hidden') return false;
        const rect = element.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      };
      const settingsGuideNormalizedText = element =>
        (element?.textContent || '').replace(/\s+/g, ' ').trim();
      const settingsGuideFindButton = labels => Array.from(document.querySelectorAll('button'))
        .find(candidate => {
          if (candidate.id === 'dsh-settings-guide-launcher') return false;
          if (!settingsGuideIsVisible(candidate)) return false;
          const name = accessibleName(candidate);
          return labels.some(label => name === label || name.includes(label));
        });
      const settingsGuideExpandTarget = (element, zone) => {
        const directButton = element.closest?.('button, [role="button"]');
        if (directButton && settingsGuideIsVisible(directButton)) return directButton;
        if (zone !== 'main') return element;
        let candidate = element;
        while (candidate.parentElement && candidate.parentElement !== document.body) {
          const parent = candidate.parentElement;
          const rect = parent.getBoundingClientRect();
          if (rect.width >= 420 && rect.height >= 48 && rect.height <= 300) return parent;
          candidate = parent;
        }
        return element;
      };
      const settingsGuideFindTarget = step => {
        const candidates = Array.from(document.querySelectorAll(
          'button, [role="button"], h1, h2, h3, label, div, span, p'
        )).filter(candidate => {
          if (settingsGuideRoot?.contains(candidate)) return false;
          if (!settingsGuideIsVisible(candidate)) return false;
          const value = settingsGuideNormalizedText(candidate);
          if (!value || value.length > 90) return false;
          if (!step.targetLabels.some(label => value === label || value.includes(label))) return false;
          const rect = candidate.getBoundingClientRect();
          if (step.targetZone === 'main' && rect.left < window.innerWidth * .28) return false;
          if (step.targetZone === 'sidebar' && rect.left > window.innerWidth * .48) return false;
          return true;
        });
        candidates.sort((left, right) => {
          const leftExact = step.targetLabels.includes(settingsGuideNormalizedText(left)) ? 0 : 1;
          const rightExact = step.targetLabels.includes(settingsGuideNormalizedText(right)) ? 0 : 1;
          if (leftExact !== rightExact) return leftExact - rightExact;
          const leftRect = left.getBoundingClientRect();
          const rightRect = right.getBoundingClientRect();
          return leftRect.width * leftRect.height - rightRect.width * rightRect.height;
        });
        return candidates.length ? settingsGuideExpandTarget(candidates[0], step.targetZone) : null;
      };
      const settingsGuideWasSeen = () => {
        try { return localStorage.getItem(settingsGuideStorageKey) === 'true'; }
        catch (_storageUnavailable) { return false; }
      };
      const settingsGuideMarkSeen = () => {
        try { localStorage.setItem(settingsGuideStorageKey, 'true'); }
        catch (_storageUnavailable) {}
      };
      const closeSettingsGuide = (markSeen = true) => {
        if (markSeen) settingsGuideMarkSeen();
        settingsGuideRoot?.remove();
        settingsGuideRoot = null;
        settingsGuideLauncher?.setAttribute('aria-expanded', 'false');
      };
      const renderSettingsGuide = () => {
        if (!settingsGuideRoot) return;
        const step = settingsGuideSteps[settingsGuideStep];
        settingsGuideRoot.querySelector('.dsh-settings-guide-kicker').textContent =
          `${settingsGuideStep + 1} / ${settingsGuideSteps.length} · ${step.section}`;
        settingsGuideRoot.querySelector('.dsh-settings-guide-heading').textContent = step.title;
        settingsGuideRoot.querySelector('.dsh-settings-guide-body').textContent = step.body;
        const tips = settingsGuideRoot.querySelector('.dsh-settings-guide-tips');
        tips.replaceChildren(...step.tips.map(value => {
          const item = document.createElement('li');
          item.textContent = value;
          return item;
        }));
        settingsGuideRoot.querySelector('.dsh-settings-guide-recommendation').textContent =
          step.recommendation;
        const previous = settingsGuideRoot.querySelector('[data-guide-action="previous"]');
        const next = settingsGuideRoot.querySelector('[data-guide-action="next"]');
        previous.disabled = settingsGuideStep === 0;
        next.textContent = settingsGuideStep === settingsGuideSteps.length - 1
          ? settingsGuideCopy.done
          : settingsGuideCopy.next;
        const progress = settingsGuideRoot.querySelector('.dsh-settings-guide-progress');
        progress.replaceChildren(...settingsGuideSteps.map((_value, index) => {
          const dot = document.createElement('span');
          dot.className = 'dsh-settings-guide-dot';
          dot.dataset.active = index === settingsGuideStep ? 'true' : 'false';
          return dot;
        }));

        const target = settingsGuideFindTarget(step);
        const highlight = settingsGuideRoot.querySelector('#dsh-settings-guide-highlight');
        const card = settingsGuideRoot.querySelector('#dsh-settings-guide-card');
        settingsGuideRoot.dataset.hasTarget = target ? 'true' : 'false';
        if (!target) {
          highlight.style.display = 'none';
          card.dataset.placement = 'bottom';
          return;
        }
        const rect = target.getBoundingClientRect();
        const inset = 8;
        highlight.style.display = 'block';
        highlight.style.left = `${Math.max(6, rect.left - inset)}px`;
        highlight.style.top = `${Math.max(6, rect.top - inset)}px`;
        highlight.style.width = `${Math.min(window.innerWidth - 12, rect.width + inset * 2)}px`;
        highlight.style.height = `${Math.min(window.innerHeight - 12, rect.height + inset * 2)}px`;
        card.dataset.placement = rect.top + rect.height / 2 > window.innerHeight * .56
          ? 'top'
          : 'bottom';
      };
      const openSettingsGuide = () => {
        if (settingsGuideRoot) return;
        settingsGuideStep = 0;
        const overlay = document.createElement('div');
        overlay.id = 'dsh-settings-guide-root';
        overlay.setAttribute('role', 'dialog');
        overlay.setAttribute('aria-modal', 'true');
        overlay.setAttribute('aria-label', settingsGuideCopy.dialogLabel);
        overlay.innerHTML = `
          <div id="dsh-settings-guide-backdrop"></div>
          <div id="dsh-settings-guide-highlight"></div>
          <section id="dsh-settings-guide-card" tabindex="-1">
            <div class="dsh-settings-guide-kicker"></div>
            <h2 class="dsh-settings-guide-heading"></h2>
            <p class="dsh-settings-guide-body"></p>
            <ul class="dsh-settings-guide-tips"></ul>
            <div class="dsh-settings-guide-recommendation"></div>
            <div class="dsh-settings-guide-footer">
              <div class="dsh-settings-guide-progress" aria-hidden="true"></div>
              <button class="dsh-settings-guide-action" data-guide-action="skip" type="button"></button>
              <button class="dsh-settings-guide-action" data-guide-action="previous" type="button"></button>
              <button class="dsh-settings-guide-action dsh-settings-guide-action-primary" data-guide-action="next" type="button"></button>
            </div>
          </section>`;
        overlay.querySelector('[data-guide-action="skip"]').textContent = settingsGuideCopy.later;
        overlay.querySelector('[data-guide-action="previous"]').textContent = settingsGuideCopy.previous;
        overlay.querySelector('[data-guide-action="next"]').textContent = settingsGuideCopy.next;
        for (const eventName of ['pointerdown', 'mousedown', 'click']) {
          overlay.addEventListener(eventName, event => event.stopPropagation());
        }
        overlay.querySelector('#dsh-settings-guide-backdrop').addEventListener(
          'click',
          () => closeSettingsGuide()
        );
        overlay.querySelector('[data-guide-action="skip"]').addEventListener(
          'click',
          () => closeSettingsGuide()
        );
        overlay.querySelector('[data-guide-action="previous"]').addEventListener('click', () => {
          settingsGuideStep = Math.max(0, settingsGuideStep - 1);
          renderSettingsGuide();
        });
        overlay.querySelector('[data-guide-action="next"]').addEventListener('click', () => {
          if (settingsGuideStep >= settingsGuideSteps.length - 1) {
            closeSettingsGuide();
            return;
          }
          settingsGuideStep += 1;
          renderSettingsGuide();
        });
        document.body.appendChild(overlay);
        settingsGuideRoot = overlay;
        settingsGuideLauncher?.setAttribute('aria-expanded', 'true');
        renderSettingsGuide();
        overlay.querySelector('#dsh-settings-guide-card').focus();
      };
      const ensureSettingsGuideLauncher = () => {
        const configButton = settingsGuideFindButton(['打开配置文件', 'Open config file']);
        if (!configButton) {
          if (settingsGuideRoot) closeSettingsGuide();
          settingsGuideLauncher = null;
          return;
        }
        if (!settingsGuideLauncher?.isConnected) {
          const launcher = document.createElement('button');
          launcher.id = 'dsh-settings-guide-launcher';
          launcher.type = 'button';
          launcher.textContent = settingsGuideCopy.launcher;
          launcher.setAttribute('aria-label', settingsGuideCopy.launcherLabel);
          launcher.setAttribute('aria-expanded', 'false');
          launcher.addEventListener('click', openSettingsGuide);
          configButton.parentElement?.insertBefore(launcher, configButton);
          settingsGuideLauncher = launcher;
        }
        if (!settingsGuideAutoScheduled && !settingsGuideWasSeen()) {
          settingsGuideAutoScheduled = true;
          window.setTimeout(() => {
            if (settingsGuideLauncher?.isConnected) openSettingsGuide();
          }, 260);
        }
      };
      const updateSettingsGuideLanguage = language => {
        const resolvedLanguage = language === 'en' ? 'en' : 'zh-Hans';
        settingsGuideSteps.splice(
          0,
          settingsGuideSteps.length,
          ...settingsGuideStepsByLanguage[resolvedLanguage]
        );
        Object.assign(settingsGuideCopy, settingsGuideCopyByLanguage[resolvedLanguage]);
        if (settingsGuideLauncher) {
          settingsGuideLauncher.textContent = settingsGuideCopy.launcher;
          settingsGuideLauncher.setAttribute('aria-label', settingsGuideCopy.launcherLabel);
        }
        if (settingsGuideRoot) {
          settingsGuideRoot.setAttribute('aria-label', settingsGuideCopy.dialogLabel);
          settingsGuideRoot.querySelector('[data-guide-action="skip"]').textContent =
            settingsGuideCopy.later;
          settingsGuideRoot.querySelector('[data-guide-action="previous"]').textContent =
            settingsGuideCopy.previous;
          renderSettingsGuide();
        }
      };
      let settingsGuideUpdateQueued = false;
      const queueSettingsGuideUpdate = () => {
        if (settingsGuideUpdateQueued) return;
        settingsGuideUpdateQueued = true;
        requestAnimationFrame(() => {
          settingsGuideUpdateQueued = false;
          ensureSettingsGuideLauncher();
          if (settingsGuideRoot) renderSettingsGuide();
        });
      };
      new MutationObserver(mutations => {
        const relevant = mutations.some(mutation => {
          if (settingsGuideRoot?.contains(mutation.target)) return false;
          if (settingsGuideLauncher?.contains(mutation.target)) return false;
          return true;
        });
        if (relevant) queueSettingsGuideUpdate();
      }).observe(document.body, {
        subtree: true,
        childList: true
      });
      document.addEventListener('keydown', event => {
        if (!settingsGuideRoot) return;
        if (event.key === 'Escape') {
          event.preventDefault();
          event.stopImmediatePropagation();
          closeSettingsGuide();
        } else if (event.key === 'ArrowLeft' && settingsGuideStep > 0) {
          settingsGuideStep -= 1;
          renderSettingsGuide();
        } else if (event.key === 'ArrowRight') {
          if (settingsGuideStep >= settingsGuideSteps.length - 1) closeSettingsGuide();
          else {
            settingsGuideStep += 1;
            renderSettingsGuide();
          }
        }
      }, true);
      window.addEventListener('resize', queueSettingsGuideUpdate);
      queueSettingsGuideUpdate();

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

      let latestBalanceTitle = '';
      let latestBalanceSubtitle = '';
      let sessionUsage = null;
      let sessionUsageUpdateQueued = false;
      const sessionUsagePatterns = [
        /输入\s*([\d.,]+\s*[KMB]?)\s*tok\s*[·|]?\s*输出\s*([\d.,]+\s*[KMB]?)\s*tok/i,
        /Input\s*([\d.,]+\s*[KMB]?)\s*tokens?\s*[·|]?\s*Output\s*([\d.,]+\s*[KMB]?)\s*tokens?/i
      ];
      const updateSessionUsageView = () => {
        const values = sessionUsage
          ? `${labels.input} ${sessionUsage.input} · ${labels.output} ${sessionUsage.output}`
          : labels.noUsage;
        subtitle.textContent = sessionUsage ? values : latestBalanceSubtitle;
        const usageValues = document.getElementById('dsh-session-usage-values');
        if (usageValues && usageValues.textContent !== values) usageValues.textContent = values;
        button.setAttribute(
          'aria-label',
          [latestBalanceTitle, pricingBadge.textContent, subtitle.textContent]
            .filter(Boolean)
            .join('，')
        );
      };
      const readSessionUsage = () => {
        let match = null;
        let matchLength = Number.POSITIVE_INFINITY;
        for (const candidate of document.querySelectorAll('div, span')) {
          if (root.contains(candidate)) continue;
          const value = (candidate.textContent || '').replace(/\s+/g, ' ').trim();
          if (!value || value.length > 240 || value.length >= matchLength) continue;
          for (const pattern of sessionUsagePatterns) {
            const result = value.match(pattern);
            if (!result) continue;
            match = {
              input: result[1].replace(/\s+/g, ''),
              output: result[2].replace(/\s+/g, '')
            };
            matchLength = value.length;
            break;
          }
        }
        const changed = match?.input !== sessionUsage?.input
          || match?.output !== sessionUsage?.output;
        if (!changed) return;
        sessionUsage = match;
        updateSessionUsageView();
      };
      const queueSessionUsageUpdate = () => {
        if (sessionUsageUpdateQueued) return;
        sessionUsageUpdateQueued = true;
        window.setTimeout(() => {
          sessionUsageUpdateQueued = false;
          readSessionUsage();
        }, 500);
      };
      new MutationObserver(queueSessionUsageUpdate).observe(document.body, {
        subtree: true,
        childList: true,
        characterData: true
      });
      queueSessionUsageUpdate();

      window.__dshBalanceUpdate = payload => {
        Object.assign(labels, payload.labels || {});
        updateSettingsGuideLanguage(labels.language);
        themeLabel.textContent = labels.themeBackground;
        themeButton.title = labels.themeBackground;
        themeButton.setAttribute(
          'aria-label',
          themeButton.dataset.active === 'true'
            ? labels.themeBackgroundConfigured
            : labels.themeBackground
        );
        root.dataset.tone = payload.tone;
        root.dataset.state = payload.state;
        const pricing = payload.pricing;
        root.dataset.pricingPeriod = pricing ? pricing.currentPeriod : 'none';
        latestBalanceTitle = payload.title;
        latestBalanceSubtitle = payload.subtitle;
        title.textContent = payload.title;
        pricingBadge.textContent = pricing
          ? (pricing.currentPeriod === 'peak' ? labels.peakPeriod : labels.offPeakPeriod)
          : '';
        updateSessionUsageView();
        panel.replaceChildren();

        const header = document.createElement('div');
        header.className = 'dsh-balance-header';
        const headingRow = document.createElement('div');
        headingRow.className = 'dsh-balance-heading-row';
        headingRow.appendChild(text('div', labels.balanceHeading, 'dsh-balance-heading'));
        if (pricing) {
          headingRow.appendChild(text(
            'span',
            pricing.currentPeriod === 'peak' ? labels.peakPeriod : labels.offPeakPeriod,
            'dsh-pricing-pill'
          ));
        }
        header.appendChild(headingRow);
        const close = text('button', '×', 'dsh-balance-close');
        close.type = 'button';
        close.setAttribute('aria-label', labels.collapseBalanceDetails);
        close.title = labels.collapse;
        close.addEventListener('click', event => { event.stopPropagation(); setExpanded(false); });
        header.appendChild(close);
        panel.appendChild(header);

        if (pricing) {
          panel.dataset.pricingPeriod = pricing.currentPeriod;
          const status = document.createElement('div');
          status.className = 'dsh-pricing-status';
          status.append(
            text('div', pricing.nextSwitchLabel, 'dsh-pricing-next'),
            text('div', pricing.scheduleLabel, 'dsh-pricing-schedule')
          );
          panel.appendChild(status);
        } else {
          delete panel.dataset.pricingPeriod;
        }

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
          breakdown.append(
            text('span', `${labels.grantedPrefix} ${entry.granted}`),
            text('span', `${labels.toppedUpPrefix} ${entry.toppedUp}`)
          );
          item.append(total, breakdown);
          panel.appendChild(item);
        }

        if (payload.state === 'loading') {
          panel.appendChild(text('div', labels.loadingBalance, 'dsh-balance-updated'));
        } else if (payload.updatedLabel) {
          panel.appendChild(text('div', payload.updatedLabel, 'dsh-balance-updated'));
        }

        const usage = document.createElement('div');
        usage.className = 'dsh-session-usage';
        usage.append(
          text('span', labels.sessionTokens, 'dsh-session-usage-label'),
          text('span', '', 'dsh-session-usage-values')
        );
        usage.lastChild.id = 'dsh-session-usage-values';
        panel.appendChild(usage);
        updateSessionUsageView();

        if (pricing) {
          const details = document.createElement('details');
          details.className = 'dsh-pricing-details';
          const summary = document.createElement('summary');
          const summaryCopy = document.createElement('span');
          summaryCopy.className = 'dsh-pricing-summary-copy';
          summaryCopy.append(
            text('span', labels.viewModelPricing, 'dsh-pricing-summary-label'),
            text('span', pricing.unitLabel, 'dsh-pricing-unit')
          );
          summary.appendChild(summaryCopy);
          details.appendChild(summary);

          for (const model of pricing.models || []) {
            const card = document.createElement('div');
            card.className = 'dsh-pricing-model';
            card.append(
              text('div', model.displayName, 'dsh-pricing-model-name'),
              text('div', model.id, 'dsh-pricing-model-id')
            );

            const grid = document.createElement('div');
            grid.className = 'dsh-pricing-grid';
            for (const label of ['', labels.cacheHit, labels.cacheMiss, labels.output]) {
              grid.appendChild(text('div', label, 'dsh-pricing-cell dsh-pricing-grid-header'));
            }
            for (const [label, key] of [
              [labels.offPeakPeriod, 'offPeak'],
              [labels.peakPeriod, 'peak']
            ]) {
              const rate = model[key];
              const rowClass = key === pricing.currentPeriod ? ' dsh-pricing-current-row' : '';
              grid.appendChild(text('div', label, `dsh-pricing-cell dsh-pricing-period${rowClass}`));
              for (const value of [rate.cacheHitInput, rate.cacheMissInput, rate.output]) {
                grid.appendChild(text('div', value, `dsh-pricing-cell${rowClass}`));
              }
            }
            card.appendChild(grid);
            details.appendChild(card);
          }

          const source = text('button', pricing.sourceLabel, 'dsh-pricing-source');
          source.type = 'button';
          source.addEventListener('click', event => { event.stopPropagation(); send('pricing'); });
          details.appendChild(source);
          panel.appendChild(details);
        }

        const actions = document.createElement('div');
        actions.className = 'dsh-balance-actions';
        const settings = text(
          'button',
          labels.configureAPIKey,
          'dsh-balance-action dsh-balance-action-primary'
        );
        settings.type = 'button';
        settings.addEventListener('click', event => { event.stopPropagation(); send('settings'); });
        const refresh = text('button', labels.refresh, 'dsh-balance-action');
        refresh.type = 'button';
        refresh.addEventListener('click', event => { event.stopPropagation(); send('refresh'); });
        actions.append(settings, refresh);
        panel.appendChild(actions);
      };
      if (window.__dshPendingBalancePayload) {
        window.__dshBalanceUpdate(window.__dshPendingBalancePayload);
        window.__dshPendingBalancePayload = null;
      }

      window.__dshThemeUpdate = payload => {
        const imageDataURL = payload.imageDataURL || '';
        const enabled = imageDataURL.length > 0;
        document.documentElement.classList.toggle('dsh-has-theme', enabled);
        themeButton.dataset.active = enabled ? 'true' : 'false';
        themeButton.setAttribute(
          'aria-label',
          enabled ? labels.themeBackgroundConfigured : labels.themeBackground
        );

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
            guard action == "settings" || action == "refresh" || action == "pricing" else {
                return
            }
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
            webView.evaluateJavaScript("""
            window.__dshPendingBalancePayload = \(json);
            if (window.__dshBalanceUpdate) {
              window.__dshBalanceUpdate(window.__dshPendingBalancePayload);
              window.__dshPendingBalancePayload = null;
            }
            """)
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
