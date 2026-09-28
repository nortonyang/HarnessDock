import AppKit
import Combine
import HarnessDockCore
import SwiftUI

extension PetPluginPackage {
    /// Crop one atlas cell using AppKit's bottom-left image coordinates.
    func menuBarImage(row: Int, frame: Int) -> NSImage {
        let frameWidth = image.size.width / CGFloat(PetPluginManifest.canonicalColumns)
        let frameHeight = image.size.height / CGFloat(PetPluginManifest.canonicalRows)
        let size = NSSize(width: 22 * frameWidth / frameHeight, height: 22)
        let icon = NSImage(size: size)
        icon.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(x: CGFloat(frame) * frameWidth,
                         y: image.size.height - CGFloat(row + 1) * frameHeight,
                         width: frameWidth, height: frameHeight),
            operation: .sourceOver,
            fraction: 1
        )
        icon.unlockFocus()
        icon.isTemplate = false
        return icon
    }
}

/// Drives the actual menu bar image, even when its popover is closed.
@MainActor
final class PetMenuBarAnimator: ObservableObject {
    @Published private(set) var image: NSImage?
    private var playback: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init(model: AppModel, controller: PetPluginController) {
        let activity = Publishers.CombineLatest3(
            model.$selectedSurface,
            model.$harnessCommandActivity,
            model.$chatCommandActivity
        ).map { surface, harness, chat in
            surface == .harness ? harness : chat
        }.removeDuplicates()
        Publishers.CombineLatest3(
            controller.$selectedPackageID,
            controller.$packages,
            activity
        )
        .sink { [weak self] id, packages, activity in
            self?.play(package: packages.first { $0.id == id }, state: activity.animationState)
        }
        .store(in: &subscriptions)
    }

    private func play(package: PetPluginPackage?, state: PetAnimationState) {
        playback?.cancel()
        guard let package else {
            image = nil
            return
        }
        let layout = state.layout
        let frames = (0..<layout.frameCount).map {
            package.menuBarImage(row: layout.row, frame: $0)
        }
        image = frames[0]
        playback = Task { @MainActor [weak self] in
            var frame = 0
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds:
                        UInt64(layout.frameDurationsMilliseconds[frame]) * 1_000_000)
                } catch { return }
                guard !Task.isCancelled else { return }
                frame = (frame + 1) % frames.count
                self?.image = frames[
                    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : frame
                ]
            }
        }
    }

    deinit { playback?.cancel() }
}

struct PetMenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var controller: PetPluginController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            if let package = controller.selectedPackage {
                Text(package.displayName).font(.headline)
            }
            Picker("宠物", selection: Binding(
                get: { controller.selectedPackageID ?? "" },
                set: { controller.selectPackage(id: $0) }
            )) {
                ForEach(controller.packages) { package in
                    Text(package.displayName).tag(package.id)
                }
            }
            Toggle("在 Chat 页面显示原生宠物", isOn: $controller.isEnabled)
            Divider()
            Button("打开 HarnessDock") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            Button("退出 HarnessDock") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}
