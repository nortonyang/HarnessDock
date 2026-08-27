import Foundation
import Testing
@testable import HarnessDockCore

struct HarnessConfigurationTests {
    @Test
    func defaultConfigurationUsesOfficialLoopbackWebCommand() {
        let configuration = HarnessConfiguration()

        #expect(configuration.serverURL.absoluteString == "http://127.0.0.1:3080")
        #expect(configuration.npxArguments == [
            "--yes",
            "--prefer-offline",
            "@deepseek-ai/dsh@0.1.0-rc.6",
            "web",
            "--host",
            "127.0.0.1",
            "--port",
            "3080",
        ])
    }

    @Test
    func customPortUpdatesLoopbackURLAndLaunchArguments() {
        let configuration = HarnessConfiguration(port: 4_321)

        #expect(configuration.serverURL.absoluteString == "http://127.0.0.1:4321")
        #expect(configuration.npxArguments.contains("4321"))
    }
}
