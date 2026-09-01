import SwiftUI

@main
struct HarnessDockApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var petPlugin = PetPluginController()

    var body: some Scene {
        WindowGroup("HarnessDock") {
            ContentView()
                .environmentObject(model)
                .environmentObject(petPlugin)
                .environment(\.locale, model.appLanguage.locale)
                .frame(minWidth: 980, minHeight: 680)
                .onAppear {
                    model.restoreWorkspaceIfNeeded()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification
                    )
                ) { _ in
                    model.stop()
                }
        }
        .defaultSize(width: 1_320, height: 840)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(model.localized("选择项目…")) {
                    model.chooseWorkspace()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(model.localized("新任务")) {
                    model.requestHome()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model.workspaceURL == nil)
            }

            CommandGroup(after: .toolbar) {
                Button(model.localized("切换到 Harness")) {
                    model.selectSurface(.harness)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button(model.localized("切换到 DeepSeek 免费聊天")) {
                    model.selectSurface(.chat)
                }
                .keyboardShortcut("2", modifiers: .command)

                Divider()

                Button(model.selectedSurface == .harness
                       ? model.localized("重新加载 Harness")
                       : model.localized("重新加载 DeepSeek Chat")) {
                    model.requestSelectedSurfaceReload()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(
                    model.selectedSurface == .harness
                        ? model.workspaceURL == nil
                        : !model.hasOpenedDeepSeekChat
                )

                Button(model.localized("在 Safari 中打开 DeepSeek Chat")) {
                    model.openDeepSeekChatInBrowser()
                }
                .disabled(model.selectedSurface != .chat)

                Divider()

                Button(model.localized("Chat 原生宠物…")) {
                    petPlugin.showSettings = true
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(model.selectedSurface != .chat)

                Button(model.localized("API 与余额设置…")) {
                    model.requestSettings(.apiBalance)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button(model.localized("主题背景…")) {
                    model.requestSettings(.themeBackground)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button(model.localized("版本与诊断…")) {
                    model.requestSettings(.diagnostics)
                }

                Button(model.localized("查看 Harness 日志")) {
                    model.showLogs = true
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(model.logText.isEmpty)

                Divider()

                Button(model.localized("语言…")) {
                    model.requestSettings(.language)
                }
            }
        }

        Settings {
            AppSettingsView()
                .environmentObject(model)
                .environment(\.locale, model.appLanguage.locale)
        }
    }
}
