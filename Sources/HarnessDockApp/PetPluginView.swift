import HarnessDockCore
import SwiftUI

struct PetOverlayView: View {
    @EnvironmentObject private var controller: PetPluginController
    @EnvironmentObject private var model: AppModel

    let package: PetPluginPackage
    let applicationState: PetAnimationState

    @State private var interactionState: PetAnimationState?
    @State private var interactionTask: Task<Void, Never>?

    var body: some View {
        Button(action: wave) {
            PetSpriteView(
                image: package.image,
                state: displayedState
            )
            .frame(
                width: 96 * controller.displayScale,
                height: 104 * controller.displayScale
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
        .help(model.localized("点击和 %@ 打招呼", package.displayName))
        .accessibilityLabel(model.localized("桌面宠物 %@", package.displayName))
        .accessibilityHint(model.localized("点击播放挥手动画"))
        .contextMenu {
            Button("宠物设置…") {
                controller.showSettings = true
            }
            Button("隐藏宠物") {
                controller.isEnabled = false
            }
        }
        .onDisappear {
            interactionTask?.cancel()
        }
    }

    private func wave() {
        interactionTask?.cancel()
        interactionState = .waving
        interactionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            interactionState = nil
        }
    }

    private var displayedState: PetAnimationState {
        switch applicationState {
        case .running, .review, .failed:
            applicationState
        default:
            interactionState ?? applicationState
        }
    }
}

struct PetSpriteView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationStartedAt = Date()

    let image: NSImage
    let state: PetAnimationState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let layout = state.layout
            let frameIndex = reduceMotion
                ? 0
                : layout.frameIndex(at: context.date.timeIntervalSince(animationStartedAt))

            GeometryReader { geometry in
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .frame(
                        width: geometry.size.width
                            * CGFloat(PetPluginManifest.canonicalColumns),
                        height: geometry.size.height
                            * CGFloat(PetPluginManifest.canonicalRows),
                        alignment: .topLeading
                    )
                    .offset(
                        x: -geometry.size.width * CGFloat(frameIndex),
                        y: -geometry.size.height * CGFloat(layout.row)
                    )
            }
            .clipped()
        }
        .aspectRatio(
            CGFloat(PetPluginManifest.canonicalFrameWidth)
                / CGFloat(PetPluginManifest.canonicalFrameHeight),
            contentMode: .fit
        )
        .onChange(of: state) {
            animationStartedAt = Date()
        }
    }
}

struct PetPluginSettingsView: View {
    @EnvironmentObject private var controller: PetPluginController
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.indigo.opacity(0.12))
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.indigo)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Chat 原生宠物")
                        .font(.system(size: 18, weight: .semibold))
                    Text("兼容 Codex 8×9 动画宠物包")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("完成") {
                    controller.showSettings = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                Toggle("在 Chat 页面显示原生宠物", isOn: $controller.isEnabled)
                    .font(.system(size: 13, weight: .medium))

                if controller.packages.isEmpty {
                    emptyState
                } else {
                    packageSettings
                }

                if let error = controller.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("重新扫描") {
                        controller.refreshPackages()
                    }

                    Button("导入宠物包…") {
                        controller.importPackage(language: model.appLanguage)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Text("只读取图片与 JSON，不执行插件代码")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(20)
        }
        .frame(width: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var packageSettings: some View {
        if let package = controller.selectedPackage {
            HStack(alignment: .center, spacing: 18) {
                PetSpriteView(image: package.image, state: .idle)
                    .frame(width: 92, height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.035))
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Picker(
                        "宠物",
                        selection: Binding(
                            get: { controller.selectedPackageID ?? "" },
                            set: controller.selectPackage
                        )
                    ) {
                        ForEach(controller.packages) { candidate in
                            Text(candidate.displayName).tag(candidate.id)
                        }
                    }

                    LabeledContent("来源") {
                        Text(model.localized(package.origin.title))
                            .foregroundStyle(.secondary)
                    }

                    if let author = package.manifest.author, !author.isEmpty {
                        LabeledContent("作者") {
                            Text(author)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 10) {
                        Text("尺寸")
                        Slider(
                            value: Binding(
                                get: { controller.displayScale },
                                set: controller.setDisplayScale
                            ),
                            in: 0.65...1.45
                        )
                        Text("\(Int(controller.displayScale * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }

            if let description = package.manifest.description,
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Text(description)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 25))
                .foregroundStyle(.secondary)
            Text("没有找到可用宠物")
                .font(.system(size: 13, weight: .semibold))
            Text("可以导入包含 pet.json 和 1536×1872 图集的文件夹，\n也可以把 Codex 宠物安装到 ~/.codex/pets。")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }
}
