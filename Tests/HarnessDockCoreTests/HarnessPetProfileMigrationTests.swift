import Foundation
import Testing
@testable import HarnessDockCore

struct HarnessPetProfileMigrationTests {
    @Test
    func detectsOnlyTheExactLegacyPackage() throws {
        let legacy = Data(#"""
        {
          "dependencies": { "@dsharness/pet": "link:/Applications/DsHarness.app/pet" },
          "dsh": { "profile": { "bundles": ["@deepseek-ai/dsh-base", "@dsharness/pet"] } }
        }
        """#.utf8)
        let current = Data(#"""
        {
          "dependencies": { "@harnessdock/pet": "link:/Applications/HarnessDock.app/Contents/Resources/Plugins/harnessdock-pet" },
          "dsh": { "profile": { "bundles": ["@deepseek-ai/dsh-base", "@harnessdock/pet"] } }
        }
        """#.utf8)

        let legacyState = try #require(HarnessPetProfileMigration.state(from: legacy))
        let currentState = try #require(HarnessPetProfileMigration.state(from: current))

        #expect(legacyState.needsMigration)
        #expect(!legacyState.canBootCurrentPet)
        #expect(!currentState.needsMigration)
        #expect(currentState.canBootCurrentPet)
        #expect(currentState.needsBundledRelink(
            to: URL(fileURLWithPath: "/Applications/New/HarnessDock.app/Contents/Resources/Plugins/harnessdock-pet")
        ))

        let custom = Data(#"""
        {
          "dependencies": { "@harnessdock/pet": "link:/Users/example/dev/harnessdock-pet" },
          "dsh": { "profile": { "bundles": ["@harnessdock/pet"] } }
        }
        """#.utf8)
        let customState = try #require(HarnessPetProfileMigration.state(from: custom))
        #expect(!customState.needsBundledRelink(
            to: URL(fileURLWithPath: "/Applications/HarnessDock.app/Contents/Resources/Plugins/harnessdock-pet")
        ))
    }

    @Test
    func resolvesDefaultAndConfiguredProfileHomes() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let workspace = URL(fileURLWithPath: "/tmp/workspace", isDirectory: true)

        #expect(HarnessPetProfileMigration.manifestURL(
            environment: [:],
            homeDirectory: home,
            currentDirectory: workspace
        ).path == "/Users/example/.dsh/profiles/web/package.json")
        #expect(HarnessPetProfileMigration.manifestURL(
            environment: ["DSH_HOME": "./custom-dsh"],
            homeDirectory: home,
            currentDirectory: workspace
        ).path == "/tmp/workspace/custom-dsh/profiles/web/package.json")
    }
}
