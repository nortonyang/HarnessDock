import SwiftUI

@main
struct DsHarnessApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("DS Harness") {
            ContentView()
                .environmentObject(model)
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
                Button("选择项目…") {
                    model.chooseWorkspace()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("新任务") {
                    model.requestHome()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model.workspaceURL == nil)
            }

            CommandGroup(after: .toolbar) {
                Button("切换到 Harness") {
                    model.selectSurface(.harness)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("切换到 DeepSeek 免费聊天") {
                    model.selectSurface(.chat)
                }
                .keyboardShortcut("2", modifiers: .command)

                Divider()

                Button(model.selectedSurface == .harness
                       ? "重新加载 Harness"
                       : "重新加载 DeepSeek Chat") {
                    model.requestSelectedSurfaceReload()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(
                    model.selectedSurface == .harness
                        ? model.workspaceURL == nil
                        : !model.hasOpenedDeepSeekChat
                )

                Button("在 Safari 中打开 DeepSeek Chat") {
                    model.openDeepSeekChatInBrowser()
                }
                .disabled(model.selectedSurface != .chat)

                Divider()

                Button("API 余额设置…") {
                    model.showBalanceSettings = true
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("主题背景…") {
                    model.showThemeSettings = true
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("查看 Harness 日志") {
                    model.showLogs = true
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(model.logText.isEmpty)
            }
        }
    }
}
