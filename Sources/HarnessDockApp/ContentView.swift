import AppKit
import HarnessDockCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var petPlugin: PetPluginController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            harnessSurface
                .opacity(model.selectedSurface == .harness ? 1 : 0)
                .allowsHitTesting(model.selectedSurface == .harness)
                .accessibilityHidden(model.selectedSurface != .harness)

            if model.hasOpenedDeepSeekChat {
                DeepSeekChatSurface()
                    .environmentObject(model)
                    .opacity(model.selectedSurface == .chat ? 1 : 0)
                    .allowsHitTesting(model.selectedSurface == .chat)
                    .accessibilityHidden(model.selectedSurface != .chat)
            }

            if model.selectedSurface == .chat,
               petPlugin.isEnabled,
               let package = petPlugin.selectedPackage {
                PetOverlayView(
                    package: package,
                    applicationState: petAnimationState
                )
                .padding(.trailing, 20)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.18), value: petPlugin.isEnabled)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SurfaceSwitcher(
                    selection: Binding(
                        get: { model.selectedSurface },
                        set: model.selectSurface
                    )
                )
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if model.selectedSurface == .chat {
                    Button(action: model.openDeepSeekChatInBrowser) {
                        Image(systemName: "safari")
                    }
                    .help("在 Safari 中打开 DeepSeek Chat")
                }

                if model.selectedSurface == .chat {
                    Button {
                        petPlugin.showSettings = true
                    } label: {
                        Image(systemName: "pawprint.fill")
                    }
                    .help("Chat 原生宠物")
                }
            }
        }
        .sheet(isPresented: $model.showLogs) {
            LogSheet()
                .environmentObject(model)
        }
        .sheet(isPresented: $petPlugin.showSettings) {
            PetPluginSettingsView()
                .environmentObject(petPlugin)
        }
        .onChange(of: model.settingsRequestID) {
            openSettings()
        }
    }

    @ViewBuilder
    private var harnessSurface: some View {
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
    }

    private var petAnimationState: PetAnimationState {
        switch model.selectedSurface {
        case .chat:
            if model.chatWebViewError != nil {
                return .failed
            }
            if model.chatWebViewIsLoading {
                return .running
            }
            return model.chatCommandActivity.animationState
        case .harness:
            if model.webViewError != nil {
                return .failed
            }
            switch model.status {
            case .locatingRuntime, .launching:
                return .running
            case .running:
                return model.webViewIsLoading ? .running : .idle
            case .idle:
                return .waiting
            case .failed:
                return .failed
            }
        }
    }
}

private struct SurfaceSwitcher: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selection: AppSurface
    @Namespace private var selectionBackground

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppSurface.allCases) { surface in
                let isSelected = selection == surface

                Button {
                    selection = surface
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: iconName(for: surface))
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(surface.title)
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .contentShape(Rectangle())
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.indigo.opacity(0.82),
                                            Color.purple.opacity(0.68)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .matchedGeometryEffect(
                                    id: "surface-selection",
                                    in: selectionBackground
                                )
                                .shadow(color: Color.indigo.opacity(0.18), radius: 4, y: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(model.localized("切换到 %@", surface.title))
                .accessibilityValue(isSelected ? model.localized("已选择") : "")
            }
        }
        .padding(3)
        .frame(width: 190, height: 30)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.16), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("主界面")
    }

    private func iconName(for surface: AppSurface) -> String {
        switch surface {
        case .harness:
            "terminal"
        case .chat:
            "message.fill"
        }
    }
}

private struct DeepSeekChatSurface: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            DeepSeekChatWebView(
                url: model.deepSeekChatURL,
                reloadRequestID: model.chatReloadRequestID,
                language: model.appLanguage,
                isLoading: $model.chatWebViewIsLoading,
                loadError: $model.chatWebViewError,
                onCommandActivity: model.handleChatCommandActivity
            )

            if model.chatWebViewIsLoading {
                ProgressView("正在加载 DeepSeek Chat…")
                    .controlSize(.small)
                    .font(.system(size: 10.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 10)
            }

            if let error = model.chatWebViewError {
                HStack(spacing: 9) {
                    Image(systemName: "wifi.exclamationmark")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DeepSeek Chat 加载失败")
                            .fontWeight(.semibold)
                        Text(error)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Safari", action: model.openDeepSeekChatInBrowser)
                    Button("重载", action: model.requestSelectedSurfaceReload)
                        .buttonStyle(.borderedProminent)
                }
                .font(.system(size: 11))
                .padding(12)
                .background(.regularMaterial)
                .padding(12)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct FullBleedHarnessView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HarnessWebView(
                    url: model.configuration.serverURL,
                    homeRequestID: model.homeRequestID,
                    reloadRequestID: model.reloadRequestID,
                    balancePresentation: model.balanceWebPresentation(at: context.date),
                    themeBackgroundPresentation: model.themeBackgroundPresentation,
                    onBalanceAction: model.handleBalanceWebAction,
                    onThemeAction: { model.requestSettings(.themeBackground) },
                    isLoading: $model.webViewIsLoading,
                    loadError: $model.webViewError
                )
            }

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
                    Text(model.localized("页面加载失败：%@", error))
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
                    Text("HarnessDock")
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
                .help("HarnessDock")

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
        case .idle: model.localized("Harness 未启动")
        case .locatingRuntime, .launching: model.localized("Harness 启动中")
        case .running: model.localized("Harness 已连接")
        case .failed: model.localized("Harness 需要处理")
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
            model.requestSettings()
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
            model.requestSettings()
        } else {
            showingDetails.toggle()
        }
    }

    private var title: String {
        switch model.balanceState {
        case .notConfigured: model.localized("配置 API 余额")
        case .loading: model.localized("正在查询余额")
        case let .loaded(response, _): response.preferredInfo?.displayTotal ?? model.localized("余额已同步")
        case .failed: model.localized("余额查询失败")
        }
    }

    private var subtitle: String {
        switch model.balanceState {
        case .notConfigured: model.localized("Key 安全存储在钥匙串")
        case .loading: model.localized("DeepSeek 开放平台")
        case let .loaded(response, _): response.isAvailable
            ? model.localized("DeepSeek API · 可用")
            : model.localized("DeepSeek API · 暂不可用")
        case .failed: model.localized("点击查看原因或重新配置")
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
            model.requestSettings()
        } else {
            showingDetails.toggle()
        }
    }

    private var label: String {
        switch model.balanceState {
        case .notConfigured: model.localized("配置余额")
        case .loading: model.localized("余额")
        case let .loaded(response, _): response.preferredInfo?.displayTotal ?? model.localized("余额")
        case .failed: model.localized("余额异常")
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
                    model.requestSettings()
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
            Text("请在“设置 → API 与余额”中配置 DeepSeek API Key。")
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
                    Text(response.isAvailable
                         ? model.localized("账户余额可用")
                         : model.localized("账户余额暂不可用"))
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
        case .none: model.localized("尚未配置")
        case .environment: model.localized("凭据来自 DEEPSEEK_API_KEY")
        case .keychain: model.localized("凭据保存在 macOS 钥匙串")
        }
    }
}

private struct BalanceBreakdown: View {
    let label: String
    let amount: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(label))
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
        case .idle: model.localized("Harness 未启动")
        case .locatingRuntime: model.localized("正在检查环境")
        case .launching: model.localized("Harness 启动中")
        case let .running(managed): managed
            ? model.localized("Harness 已连接")
            : model.localized("已连接现有服务")
        case .failed: model.localized("Harness 需要处理")
        }
    }

    private var statusSubtitle: String {
        let portLabel = model.configuration.serverURL.absoluteString
            .replacingOccurrences(of: "http://", with: "")
        switch model.status {
        case .idle:
            return model.localized("选择项目后自动启动")
        case .locatingRuntime:
            return model.localized("查找 Node.js 与 npx")
        case .launching:
            return portLabel
        case .running:
            return model.localized("本机回环连接 · %@", String(model.configuration.port))
        case .failed:
            return model.localized("打开日志查看原因")
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
                Text(model.projectName ?? model.localized("欢迎"))
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
                    Text(model.localized("页面加载失败：%@", error))
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

                Text("进入默认工作区，桌面端会启动官方 Harness，\n需要处理现有代码时，可随时切换项目。")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button(action: model.enterDefaultWorkspace) {
                    Label("进入", systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 25)

                HStack(spacing: 12) {
                    FeatureCard(number: "01", title: "直接进入", subtitle: "使用应用专属默认工作区")
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
            Text(LocalizedStringKey(title))
                .font(.system(size: 13, weight: .semibold))
            Text(LocalizedStringKey(subtitle))
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
                Text(model.localized(message))
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

struct AppSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var apiKey = ""
    @State private var isEditingAPIKey = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.indigo.opacity(0.12))
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.indigo)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("设置")
                        .font(.system(size: 16, weight: .semibold))
                    Text("管理 HarnessDock 的本机配置")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(18)

            settingsSectionPicker

            Divider()

            Group {
                switch model.selectedSettingsSection {
                case .apiBalance:
                    VStack(alignment: .leading, spacing: 16) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("API 与余额")
                            .font(.system(size: 14, weight: .semibold))
                        Text("连接 DeepSeek 开放平台账户并读取余额")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.indigo)
                }

                if hasConfiguredAPIKey && !isEditingAPIKey {
                    HStack(alignment: .top, spacing: 12) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(credentialStatusTitle)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(credentialStatusDetail)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: credentialStatusIcon)
                                .foregroundStyle(.green)
                        }

                        Spacer(minLength: 12)

                        Button("更换 API Key") {
                            apiKey = ""
                            isEditingAPIKey = true
                        }
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.green.opacity(0.07))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(model.localized(isEditingAPIKey ? "输入新的 API Key" : "API Key"))
                            .font(.system(size: 11, weight: .semibold))

                        SecureField("sk-…", text: $apiKey)
                            .textFieldStyle(.roundedBorder)

                        Text(model.localized(
                            isEditingAPIKey
                                ? "现有 Key 不会回显；保存后，新 Key 将写入 macOS 钥匙串并优先使用。"
                                : "保存后写入 macOS 钥匙串并优先使用，不进入项目文件或 Harness 日志。"
                        ))
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
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
                    if model.balanceCredentialSource == .keychain && !isEditingAPIKey {
                        Button("移除已保存的 Key", role: .destructive) {
                            model.removeBalanceAPIKey()
                            apiKey = ""
                            isEditingAPIKey = false
                        }
                    }

                    if hasConfiguredAPIKey && isEditingAPIKey {
                        Button("取消更换") {
                            apiKey = ""
                            isEditingAPIKey = false
                        }
                    }

                    Spacer()

                    Button("刷新余额", action: model.refreshBalance)
                        .disabled(!hasConfiguredAPIKey)

                    if !hasConfiguredAPIKey || isEditingAPIKey {
                        Button("保存并刷新") {
                            model.saveBalanceAPIKey(apiKey)
                            if model.balanceCredentialError == nil {
                                apiKey = ""
                                isEditingAPIKey = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                    }
                    .padding(20)
                case .themeBackground:
                    ThemeSettingsPane()
                        .environmentObject(model)
                case .language:
                    LanguageSettingsPane()
                        .environmentObject(model)
                case .diagnostics:
                    DiagnosticsSettingsPane()
                        .environmentObject(model)
                }
            }
        }
        .frame(width: 620, height: 590)
    }

    private var settingsSectionPicker: some View {
        HStack(spacing: 8) {
            ForEach(AppSettingsSection.allCases) { section in
                let isSelected = model.selectedSettingsSection == section

                Button {
                    model.selectSettingsSection(section)
                } label: {
                    Label(model.localized(section.title), systemImage: section.systemImage)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected
                                      ? Color.accentColor.opacity(0.13)
                                      : Color.primary.opacity(0.035))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityValue(isSelected ? "已选择" : "")
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private var hasConfiguredAPIKey: Bool {
        model.balanceCredentialSource != .none
    }

    private var credentialStatusTitle: String {
        switch model.balanceCredentialSource {
        case .none:
            model.localized("尚未配置 API Key")
        case .environment:
            model.localized("已配置 · 环境变量")
        case .keychain:
            model.localized("已配置 · macOS 钥匙串")
        }
    }

    private var credentialStatusDetail: String {
        switch model.balanceCredentialSource {
        case .none:
            ""
        case .environment:
            model.localized("已从本机环境读取 DEEPSEEK_API_KEY，无需再次输入。")
        case .keychain where model.hasEnvironmentBalanceAPIKey:
            model.localized("当前优先使用钥匙串；本机环境中的 DEEPSEEK_API_KEY 已被覆盖。")
        case .keychain:
            model.localized("Key 已安全保存在 macOS 钥匙串中，现有内容不会回显。")
        }
    }

    private var credentialStatusIcon: String {
        model.balanceCredentialSource == .environment ? "terminal.fill" : "key.fill"
    }
}

private struct DiagnosticsSettingsPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var snapshot: HarnessDiagnostics?
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("版本与诊断")
                        .font(.system(size: 14, weight: .semibold))
                    Text("检查应用、服务和本机运行环境")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "stethoscope")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.indigo)
            }

            if let snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 0) {
                            diagnosticsRow(
                                icon: "shippingbox.fill",
                                title: "应用版本",
                                value: snapshot.appVersionDisplay
                            )
                            Divider().padding(.leading, 34)
                            diagnosticsRow(
                                icon: "terminal.fill",
                                title: "Harness 运行时",
                                value: snapshot.harnessPackage
                            )
                            Divider().padding(.leading, 34)
                            diagnosticsRow(
                                icon: "desktopcomputer",
                                title: "系统",
                                value: snapshot.systemDisplay
                            )
                            Divider().padding(.leading, 34)
                            diagnosticsRow(
                                icon: "network",
                                title: "服务状态",
                                value: snapshot.serviceStatus
                            )
                            Divider().padding(.leading, 34)
                            diagnosticsRow(
                                icon: "link",
                                title: "本地地址",
                                value: snapshot.serverURL
                            )
                            Divider().padding(.leading, 34)
                            diagnosticsRow(
                                icon: "folder.fill",
                                title: "工作区",
                                value: snapshot.workspaceName ?? model.localized("尚未选择")
                            )
                        }
                        .padding(.horizontal, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.primary.opacity(0.035))
                        }

                        Text("命令行运行环境")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 7) {
                            runtimeRow(name: "Node", path: snapshot.nodeExecutable)
                            runtimeRow(name: "npx", path: snapshot.npxExecutable)
                            runtimeRow(name: "dsh", path: snapshot.cachedHarnessExecutable)
                        }

                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.secondary)
                            Text("复制内容不会包含 API Key、Cookie、聊天内容、完整日志或完整工作区路径。")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        refresh()
                    } label: {
                        Label("刷新检查", systemImage: "arrow.clockwise")
                    }

                    Spacer()

                    Button {
                        model.copyDiagnostics(snapshot)
                        didCopy = true
                    } label: {
                        Label(
                            didCopy ? "已复制诊断信息" : "复制诊断信息",
                            systemImage: didCopy ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Spacer()
                ProgressView("正在检查运行环境…")
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(20)
        .task {
            refresh()
        }
    }

    private func diagnosticsRow(icon: String, title: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(height: 39)
    }

    private func runtimeRow(name: String, path: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: path == nil ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(path == nil ? Color.orange : Color.green)
            Text(name)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .frame(width: 38, alignment: .leading)
            Text(path ?? model.localized("未找到"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        }
    }

    private func refresh() {
        snapshot = model.diagnosticsSnapshot()
        didCopy = false
    }
}

private struct LanguageSettingsPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("应用语言")
                        .font(.system(size: 14, weight: .semibold))
                    Text("选择 HarnessDock 原生界面的显示语言")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "globe")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.indigo)
            }

            VStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        model.setAppLanguage(language)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: model.appLanguage == language
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .font(.system(size: 15))
                                .foregroundStyle(model.appLanguage == language
                                                 ? Color.accentColor
                                                 : Color.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.localized(language.titleKey))
                                    .font(.system(size: 12, weight: .semibold))
                                Text(model.localized(languageDetailKey(language)))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .contentShape(Rectangle())
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(model.appLanguage == language
                                      ? Color.accentColor.opacity(0.11)
                                      : Color.primary.opacity(0.035))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(model.appLanguage == language
                                        ? model.localized("已选择")
                                        : "")
                }
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "checkmark.arrow.trianglehead.counterclockwise")
                    .foregroundStyle(.secondary)
                Text("切换后立即应用并自动保存，无需重启应用或重新加载当前会话。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "safari")
                    .foregroundStyle(.secondary)
                Text("DeepSeek Chat 与官方 Harness 网页拥有各自的语言设置，本选项只控制 HarnessDock 的原生按钮、菜单和设置界面。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func languageDetailKey(_ language: AppLanguage) -> String {
        switch language {
        case .system:
            "随 macOS 的首选语言自动选择中文或英文"
        case .simplifiedChinese:
            "始终显示简体中文"
        case .english:
            "Always display the interface in English"
        }
    }
}

private struct ThemeSettingsPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("主题背景")
                            .font(.system(size: 14, weight: .semibold))
                        Text("使用一张本地图片个性化 Harness")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.indigo)
                }

                themePreview

                HStack {
                    Button(model.localized(model.hasThemeBackground ? "更换图片…" : "选择图片…")) {
                        model.chooseThemeBackground()
                    }
                    .buttonStyle(.borderedProminent)

                    if model.hasThemeBackground {
                        Button("移除背景", role: .destructive) {
                            model.removeThemeBackground()
                        }
                    }

                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("内容遮罩")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("\(Int(model.themeBackgroundDimmingOpacity * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { model.themeBackgroundDimmingOpacity },
                            set: model.setThemeBackgroundDimmingOpacity
                        ),
                        in: 0.25...0.85
                    )
                    .disabled(!model.hasThemeBackground)

                    Text("数值越高，背景越暗，聊天内容越清晰。调整会立即应用，无需重新加载会话。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }

                if let error = model.themeBackgroundError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                }

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.secondary)
                    Text("导入副本仅保存在这台 Mac 的 Application Support 中，不会写入工作区、发送到 Harness 服务或上传到网络。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var themePreview: some View {
        if let data = model.themeBackgroundData,
           let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: 210, maxHeight: 210)
                .clipped()
                .overlay {
                    Color.black.opacity(model.themeBackgroundDimmingOpacity)
                }
                .overlay(alignment: .bottomLeading) {
                    Label("当前背景", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            VStack(spacing: 10) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("尚未设置背景图片")
                    .font(.system(size: 12, weight: .medium))
                Text("支持 JPEG、PNG、HEIC 等 macOS 可读取的图片")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 210, maxHeight: 210)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                Color.primary.opacity(0.1),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                            )
                    }
            )
        }
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
