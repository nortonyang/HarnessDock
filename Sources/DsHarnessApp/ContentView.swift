import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.workspaceURL == nil {
                WelcomeView()
            } else {
                switch model.status {
                case .idle:
                    WelcomeView()
                case .locatingRuntime, .launching:
                    LaunchingView()
                case .running:
                    FullBleedHarnessView()
                case let .failed(message):
                    FailureView(message: message)
                }
            }
        }
        .sheet(isPresented: $model.showLogs) {
            LogSheet()
                .environmentObject(model)
        }
        .sheet(isPresented: $model.showBalanceSettings) {
            BalanceSettingsView()
                .environmentObject(model)
        }
    }
}

private struct FullBleedHarnessView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            HarnessWebView(
                url: model.configuration.serverURL,
                homeRequestID: model.homeRequestID,
                reloadRequestID: model.reloadRequestID,
                balancePresentation: model.balanceWebPresentation,
                onBalanceAction: model.handleBalanceWebAction,
                isLoading: $model.webViewIsLoading,
                loadError: $model.webViewError
            )

            if model.webViewIsLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 10)
            }

            if let error = model.webViewError {
                HStack(spacing: 9) {
                    Image(systemName: "wifi.exclamationmark")
                    Text("页面加载失败：\(error)")
                        .lineLimit(1)
                    Spacer()
                    Button("重载", action: model.requestReload)
                }
                .font(.system(size: 11))
                .padding(10)
                .background(.regularMaterial)
                .padding(12)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isExpanded: Bool

    var body: some View {
        Group {
            if isExpanded {
                expandedSidebar
            } else {
                compactSidebar
            }
        }
        .background(sidebarBackground)
    }

    private var expandedSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                BrandMark()

                VStack(alignment: .leading, spacing: 1) {
                    Text("DS Harness")
                        .font(.system(size: 15, weight: .semibold))
                    Text("for macOS · Preview")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("收起工具栏")
            }
                .padding(.horizontal, 16)
                .padding(.top, 34)
                .padding(.bottom, 18)

            Button(action: model.requestHome) {
                Label("新任务", systemImage: "square.and.pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.accentColor.opacity(0.13))
                    )
            }
            .buttonStyle(.plain)
            .disabled(model.workspaceURL == nil)
            .padding(.horizontal, 12)

            Text("项目")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.7)
                .padding(.horizontal, 17)
                .padding(.top, 24)
                .padding(.bottom, 8)

            ProjectRow()
                .environmentObject(model)
                .padding(.horizontal, 9)

            BalanceCard()
                .environmentObject(model)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            Spacer(minLength: 24)

            ServiceCard()
                .environmentObject(model)
                .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Button {
                    model.showLogs = true
                } label: {
                    Label("日志", systemImage: "text.alignleft")
                }
                .disabled(model.logText.isEmpty)

                Spacer()

                Button(action: model.chooseWorkspace) {
                    Image(systemName: "folder.badge.gearshape")
                }
                .help("选择其他项目")
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var compactSidebar: some View {
        VStack(spacing: 10) {
            BrandMark()
                .padding(.top, 34)
                .padding(.bottom, 4)
                .help("DS Harness")

            RailButton(
                systemImage: "sidebar.right",
                help: "展开工具栏",
                action: { isExpanded = true }
            )

            Divider()
                .padding(.horizontal, 13)
                .padding(.vertical, 4)

            RailButton(
                systemImage: "square.and.pencil",
                help: "新任务",
                isEnabled: model.workspaceURL != nil,
                action: model.requestHome
            )

            RailButton(
                systemImage: model.workspaceURL == nil ? "folder.badge.plus" : "folder.fill",
                help: model.projectName ?? "选择项目",
                tint: model.workspaceURL == nil ? .secondary : .accentColor,
                action: model.chooseWorkspace
            )

            BalanceRailButton()
                .environmentObject(model)

            Spacer(minLength: 20)

            Circle()
                .fill(serviceStatusColor)
                .frame(width: 8, height: 8)
                .shadow(color: serviceStatusColor.opacity(0.45), radius: 3)
                .frame(width: 40, height: 28)
                .help(serviceStatusHelp)

            RailButton(
                systemImage: "text.alignleft",
                help: "Harness 日志",
                isEnabled: !model.logText.isEmpty,
                action: { model.showLogs = true }
            )
            .padding(.bottom, 13)
        }
        .frame(maxWidth: .infinity)
    }

    private var serviceStatusColor: Color {
        switch model.status {
        case .idle: .secondary
        case .locatingRuntime, .launching: .orange
        case .running: .green
        case .failed: .red
        }
    }

    private var serviceStatusHelp: String {
        switch model.status {
        case .idle: "Harness 未启动"
        case .locatingRuntime, .launching: "Harness 启动中"
        case .running: "Harness 已连接"
        case .failed: "Harness 需要处理"
        }
    }

    private var sidebarBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [Color.indigo.opacity(0.045), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.30, green: 0.38, blue: 0.96),
                                 Color(red: 0.47, green: 0.28, blue: 0.93)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 34, height: 34)
        .shadow(color: Color.indigo.opacity(0.25), radius: 8, y: 3)
    }
}

private struct RailButton: View {
    let systemImage: String
    let help: String
    var isEnabled = true
    var tint: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(help)
    }
}

private struct BalanceRailButton: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingDetails = false

    var body: some View {
        Button(action: activate) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "wallet.pass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(balanceTint)
                    .frame(width: 40, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(balanceTint.opacity(0.09))
                    )

                Circle()
                    .fill(indicatorColor)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                    .offset(x: -5, y: 5)
            }
        }
        .buttonStyle(.plain)
        .help("DeepSeek API 余额")
        .popover(isPresented: $showingDetails, arrowEdge: .trailing) {
            BalanceDetailPopover()
                .environmentObject(model)
        }
    }

    private func activate() {
        if case .notConfigured = model.balanceState {
            model.showBalanceSettings = true
        } else {
            showingDetails.toggle()
        }
    }

    private var balanceTint: Color {
        switch model.balanceState {
        case .loaded: .green
        case .failed: .orange
        case .notConfigured, .loading: .secondary
        }
    }

    private var indicatorColor: Color {
        switch model.balanceState {
        case .notConfigured: .secondary
        case .loading: .orange
        case let .loaded(response, _): response.isAvailable ? .green : .orange
        case .failed: .red
        }
    }
}

private struct ProjectRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button(action: model.chooseWorkspace) {
            HStack(spacing: 10) {
                Image(systemName: model.workspaceURL == nil ? "folder.badge.plus" : "folder.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(model.workspaceURL == nil ? Color.secondary : Color.accentColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.projectName ?? "选择一个项目")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(model.workspaceURL?.deletingLastPathComponent().path ?? "打开本地代码目录")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}

private struct BalanceCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingDetails = false

    var body: some View {
        Button(action: activate) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.1))
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tint)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if case .loading = model.balanceState {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.055), lineWidth: 1)
                }
        )
        .popover(isPresented: $showingDetails, arrowEdge: .leading) {
            BalanceDetailPopover()
                .environmentObject(model)
        }
    }

    private func activate() {
        if case .notConfigured = model.balanceState {
            model.showBalanceSettings = true
        } else {
            showingDetails.toggle()
        }
    }

    private var title: String {
        switch model.balanceState {
        case .notConfigured: "配置 API 余额"
        case .loading: "正在查询余额"
        case let .loaded(response, _): response.preferredInfo?.displayTotal ?? "余额已同步"
        case .failed: "余额查询失败"
        }
    }

    private var subtitle: String {
        switch model.balanceState {
        case .notConfigured: "Key 安全存储在钥匙串"
        case .loading: "DeepSeek 开放平台"
        case let .loaded(response, _): response.isAvailable ? "DeepSeek API · 可用" : "DeepSeek API · 暂不可用"
        case .failed: "点击查看原因或重新配置"
        }
    }

    private var tint: Color {
        switch model.balanceState {
        case let .loaded(response, _): response.isAvailable ? .green : .orange
        case .failed: .orange
        case .notConfigured, .loading: .indigo
        }
    }
}

private struct BalanceToolbarButton: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingDetails = false

    var body: some View {
        Button(action: activate) {
            HStack(spacing: 6) {
                if case .loading = model.balanceState {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6, height: 6)
                }

                Image(systemName: "wallet.pass")
                    .font(.system(size: 10, weight: .medium))

                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(indicatorColor.opacity(0.09)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("DeepSeek API 余额")
        .popover(isPresented: $showingDetails, arrowEdge: .top) {
            BalanceDetailPopover()
                .environmentObject(model)
        }
    }

    private func activate() {
        if case .notConfigured = model.balanceState {
            model.showBalanceSettings = true
        } else {
            showingDetails.toggle()
        }
    }

    private var label: String {
        switch model.balanceState {
        case .notConfigured: "配置余额"
        case .loading: "余额"
        case let .loaded(response, _): response.preferredInfo?.displayTotal ?? "余额"
        case .failed: "余额异常"
        }
    }

    private var indicatorColor: Color {
        switch model.balanceState {
        case .notConfigured: .secondary
        case .loading: .orange
        case let .loaded(response, _): response.isAvailable ? .green : .orange
        case .failed: .red
        }
    }
}

private struct BalanceDetailPopover: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "wallet.pass.fill")
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DeepSeek API 余额")
                        .font(.system(size: 13, weight: .semibold))
                    Text(credentialSourceLabel)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            balanceContent

            Divider()

            HStack {
                Button("余额设置") {
                    dismiss()
                    model.showBalanceSettings = true
                }
                Spacer()
                Button(action: model.refreshBalance) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(model.balanceCredentialSource == .none)
            }
            .font(.system(size: 10.5, weight: .medium))
        }
        .padding(16)
        .frame(width: 300)
    }

    @ViewBuilder
    private var balanceContent: some View {
        switch model.balanceState {
        case .notConfigured:
            Text("配置 DeepSeek API Key 后即可在这里查看开放平台账户余额。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("正在向 DeepSeek 查询余额…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        case let .loaded(response, refreshedAt):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(response.balanceInfos) { info in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(info.displayTotal)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                            Spacer()
                            Text(info.currency.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            BalanceBreakdown(label: "赠送余额", amount: info.displayGranted)
                            Spacer()
                            BalanceBreakdown(label: "充值余额", amount: info.displayToppedUp)
                        }
                    }
                    if info.id != response.balanceInfos.last?.id {
                        Divider()
                    }
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(response.isAvailable ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(response.isAvailable ? "账户余额可用" : "账户余额暂不可用")
                    Spacer()
                    Text(refreshedAt, style: .time)
                }
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var credentialSourceLabel: String {
        switch model.balanceCredentialSource {
        case .none: "尚未配置"
        case .environment: "凭据来自 DEEPSEEK_API_KEY"
        case .keychain: "凭据保存在 macOS 钥匙串"
        }
    }
}

private struct BalanceBreakdown: View {
    let label: String
    let amount: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(amount)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
    }
}

private struct ServiceCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .shadow(color: statusColor.opacity(0.4), radius: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(statusSubtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.055), lineWidth: 1)
                }
        )
    }

    private var statusTitle: String {
        switch model.status {
        case .idle: "Harness 未启动"
        case .locatingRuntime: "正在检查环境"
        case .launching: "Harness 启动中"
        case let .running(managed): managed ? "Harness 已连接" : "已连接现有服务"
        case .failed: "Harness 需要处理"
        }
    }

    private var statusSubtitle: String {
        let portLabel = model.configuration.serverURL.absoluteString
            .replacingOccurrences(of: "http://", with: "")
        switch model.status {
        case .idle:
            return "选择项目后自动启动"
        case .locatingRuntime:
            return "查找 Node.js 与 npx"
        case .launching:
            return portLabel
        case .running:
            return "本机回环连接 · \(model.configuration.port)"
        case .failed:
            return "打开日志查看原因"
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .idle: .secondary
        case .locatingRuntime, .launching: .orange
        case .running: .green
        case .failed: .red
        }
    }
}

private struct WorkspaceView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isSidebarExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            workspaceToolbar
            Divider().opacity(0.55)

            Group {
                if model.workspaceURL == nil {
                    WelcomeView()
                } else {
                    switch model.status {
                    case .idle:
                        WelcomeView()
                    case .locatingRuntime, .launching:
                        LaunchingView()
                    case .running:
                        webWorkspace
                    case let .failed(message):
                        FailureView(message: message)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var workspaceToolbar: some View {
        HStack(spacing: 12) {
            if !isSidebarExpanded {
                Button {
                    isSidebarExpanded = true
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help("展开工具栏")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.projectName ?? "欢迎")
                    .font(.system(size: 13, weight: .semibold))
                if let workspaceURL = model.workspaceURL {
                    Text(workspaceURL.path)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("DeepSeek Harness 的原生 Mac 工作区")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            BalanceToolbarButton()
                .environmentObject(model)

            if case .running = model.status {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("本地")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.green.opacity(0.09)))
            }

            Button(action: model.requestReload) {
                Image(systemName: "arrow.clockwise")
            }
            .help("重新加载")
            .disabled(model.workspaceURL == nil)

            Button(action: model.openInBrowser) {
                Image(systemName: "safari")
            }
            .help("在浏览器打开")
            .disabled(model.workspaceURL == nil)
        }
        .buttonStyle(.borderless)
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .frame(height: 52)
        .background(.bar)
    }

    private var webWorkspace: some View {
        ZStack(alignment: .top) {
            HarnessWebView(
                url: model.configuration.serverURL,
                homeRequestID: model.homeRequestID,
                reloadRequestID: model.reloadRequestID,
                isLoading: $model.webViewIsLoading,
                loadError: $model.webViewError
            )

            if model.webViewIsLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 10)
            }

            if let error = model.webViewError {
                HStack(spacing: 9) {
                    Image(systemName: "wifi.exclamationmark")
                    Text("页面加载失败：\(error)")
                        .lineLimit(1)
                    Spacer()
                    Button("重载", action: model.requestReload)
                }
                .font(.system(size: 11))
                .padding(10)
                .background(.regularMaterial)
                .padding(12)
            }
        }
    }
}

private struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.16), Color.purple.opacity(0.07)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 33, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 78, height: 78)
                .shadow(color: Color.indigo.opacity(0.12), radius: 22, y: 10)
                .padding(.bottom, 24)

                Text("让 DeepSeek 在你的 Mac 上工作")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Text("选择一个代码项目，桌面端会启动官方 Harness，\n会话、工具、审批和插件仍由 DeepSeek 原生运行时提供。")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button(action: model.chooseWorkspace) {
                    Label("打开本地项目", systemImage: "folder.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 25)

                HStack(spacing: 12) {
                    FeatureCard(number: "01", title: "选择项目", subtitle: "以本地目录作为工作边界")
                    FeatureCard(number: "02", title: "自动启动", subtitle: "管理 dsh 本地服务与日志")
                    FeatureCard(number: "03", title: "专注工作", subtitle: "在原生窗口中完成任务")
                }
                .padding(.top, 46)
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 42)
            .padding(.vertical, 86)
            .frame(maxWidth: .infinity)
        }
        .background(
            RadialGradient(
                colors: [Color.indigo.opacity(0.055), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 520
            )
        )
    }
}

private struct FeatureCard: View {
    let number: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.indigo)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
        )
    }
}

private struct LaunchingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 7) {
                Text("正在准备 DeepSeek Harness")
                    .font(.system(size: 20, weight: .semibold))
                Text("首次运行可能需要从 npm 下载官方运行时。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            LogPreview(text: model.logText)
                .frame(maxWidth: 620, maxHeight: 210)

            HStack(spacing: 12) {
                Button("查看完整日志") {
                    model.showLogs = true
                }
                .disabled(model.logText.isEmpty)
                Button("停止", action: model.stop)
            }
        }
        .padding(48)
    }
}

private struct FailureView: View {
    @EnvironmentObject private var model: AppModel
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38))
                .foregroundStyle(.orange)

            VStack(spacing: 7) {
                Text("Harness 没有启动")
                    .font(.system(size: 21, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            LogPreview(text: model.logText)
                .frame(maxWidth: 620, maxHeight: 210)

            HStack(spacing: 10) {
                Button("重试", action: model.retry)
                    .buttonStyle(.borderedProminent)
                Button("查看日志") {
                    model.showLogs = true
                }
            }
        }
        .padding(48)
    }
}

private struct LogPreview: View {
    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? "等待运行时输出…" : text)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .id("log-bottom")
            }
            .onChange(of: text) {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("log-bottom", anchor: .bottom)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
        )
    }
}

private struct BalanceSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.indigo.opacity(0.12))
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.indigo)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("配置 DeepSeek API Key")
                        .font(.system(size: 16, weight: .semibold))
                    Text("连接开放平台账户并读取余额")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(18)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                if model.hasEnvironmentBalanceAPIKey {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.balanceCredentialSource == .keychain
                                 ? "环境变量已由钥匙串覆盖"
                                 : "当前使用环境变量")
                                .font(.system(size: 12, weight: .semibold))
                            Text("DEEPSEEK_API_KEY 已随应用启动环境提供；保存下方 Key 后将优先使用钥匙串。")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "terminal.fill")
                            .foregroundStyle(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(model.balanceCredentialSource == .keychain ? "替换 API Key" : "API Key")
                        .font(.system(size: 11, weight: .semibold))

                    SecureField("sk-…", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    Text(model.balanceCredentialSource == .keychain
                         ? "已在钥匙串中保存一项凭据；现有 Key 不会回显。"
                         : "保存后写入 macOS 钥匙串并优先使用，不进入项目文件或 Harness 日志。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.secondary)
                    Text("应用只会向官方 `https://api.deepseek.com/user/balance` 发起只读请求。Harness 自身的登录状态和凭据不会被读取。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let error = model.balanceCredentialError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                }

                Spacer(minLength: 0)

                HStack {
                    if model.balanceCredentialSource == .keychain {
                        Button("移除已保存的 Key", role: .destructive) {
                            model.removeBalanceAPIKey()
                            apiKey = ""
                        }
                    }

                    Spacer()

                    Button("刷新余额", action: model.refreshBalance)
                        .disabled(model.balanceCredentialSource == .none)

                    Button("保存并刷新") {
                        model.saveBalanceAPIKey(apiKey)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 390)
    }
}

private struct LogSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Harness 日志")
                        .font(.system(size: 16, weight: .semibold))
                    Text("本地启动输出，不包含应用保存的 API Key。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("复制", action: model.copyLogs)
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.logText.isEmpty ? "暂无日志。" : model.logText)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .id("log-bottom")
                }
                .onChange(of: model.logText) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("log-bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 440)
    }
}
