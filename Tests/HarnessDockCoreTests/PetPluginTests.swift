import XCTest
@testable import HarnessDockCore

final class PetPluginTests: XCTestCase {
    func testMinimalManifestUsesCanonicalGeometry() throws {
        let data = Data(#"""
        {
          "id": "nova",
          "name": "Nova",
          "spritesheet": "spritesheet.webp"
        }
        """#.utf8)

        let manifest = try JSONDecoder().decode(PetPluginManifest.self, from: data)
        try manifest.validate()

        XCTAssertEqual(manifest.frameWidth, 192)
        XCTAssertEqual(manifest.frameHeight, 208)
        XCTAssertEqual(manifest.columns, 8)
        XCTAssertEqual(manifest.rows, 9)
    }

    func testHatchedManifestAliasesAreSupported() throws {
        let data = Data(#"""
        {
          "id": "deepwhale",
          "displayName": "DeepWhale",
          "spritesheetPath": "spritesheet.webp"
        }
        """#.utf8)

        let manifest = try JSONDecoder().decode(PetPluginManifest.self, from: data)
        try manifest.validate()

        XCTAssertEqual(manifest.name, "DeepWhale")
        XCTAssertEqual(manifest.spritesheet, "spritesheet.webp")
    }

    func testManifestRejectsPathTraversal() throws {
        let manifest = PetPluginManifest(
            id: "nova",
            name: "Nova",
            spritesheet: "../spritesheet.webp"
        )

        XCTAssertThrowsError(try manifest.validate()) { error in
            XCTAssertEqual(error as? PetPluginManifestError, .invalidSpritesheetPath)
        }
    }

    func testManifestRejectsUnsupportedGeometry() throws {
        let manifest = PetPluginManifest(
            id: "nova",
            name: "Nova",
            frameWidth: 96
        )

        XCTAssertThrowsError(try manifest.validate()) { error in
            XCTAssertEqual(error as? PetPluginManifestError, .unsupportedGeometry)
        }
    }

    func testManifestRejectsHiddenOrWhitespacePaddedIdentifiers() {
        for identifier in [".hidden-pet", " nova "] {
            let manifest = PetPluginManifest(id: identifier, name: "Nova")
            XCTAssertThrowsError(try manifest.validate()) { error in
                XCTAssertEqual(error as? PetPluginManifestError, .invalidIdentifier)
            }
        }
    }

    func testAnimationFrameTiming() {
        let idle = PetAnimationState.idle.layout

        XCTAssertEqual(idle.row, 0)
        XCTAssertEqual(idle.frameCount, 6)
        XCTAssertEqual(idle.frameIndex(at: 0), 0)
        XCTAssertEqual(idle.frameIndex(at: 0.279), 0)
        XCTAssertEqual(idle.frameIndex(at: 0.280), 1)
        XCTAssertEqual(idle.frameIndex(at: 1.099), 5)
        XCTAssertEqual(idle.frameIndex(at: 1.100), 0)
    }

    func testAllAnimationRowsFitCanonicalAtlas() {
        for state in PetAnimationState.allCases {
            XCTAssertLessThan(state.layout.row, PetPluginManifest.canonicalRows)
            XCTAssertLessThanOrEqual(
                state.layout.frameCount,
                PetPluginManifest.canonicalColumns
            )
        }
    }
}
