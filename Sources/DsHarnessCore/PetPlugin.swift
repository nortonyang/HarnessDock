import Foundation

public enum PetAnimationState: String, CaseIterable, Codable, Sendable {
    case idle
    case runningRight = "running-right"
    case runningLeft = "running-left"
    case waving
    case jumping
    case failed
    case waiting
    case running
    case review

    public var layout: PetAnimationLayout {
        switch self {
        case .idle:
            PetAnimationLayout(row: 0, frameDurationsMilliseconds: [280, 110, 110, 140, 140, 320])
        case .runningRight:
            PetAnimationLayout(row: 1, frameDurationsMilliseconds: [120, 120, 120, 120, 120, 120, 120, 220])
        case .runningLeft:
            PetAnimationLayout(row: 2, frameDurationsMilliseconds: [120, 120, 120, 120, 120, 120, 120, 220])
        case .waving:
            PetAnimationLayout(row: 3, frameDurationsMilliseconds: [140, 140, 140, 280])
        case .jumping:
            PetAnimationLayout(row: 4, frameDurationsMilliseconds: [140, 140, 140, 140, 280])
        case .failed:
            PetAnimationLayout(row: 5, frameDurationsMilliseconds: [140, 140, 140, 140, 140, 140, 140, 240])
        case .waiting:
            PetAnimationLayout(row: 6, frameDurationsMilliseconds: [150, 150, 150, 150, 150, 260])
        case .running:
            PetAnimationLayout(row: 7, frameDurationsMilliseconds: [120, 120, 120, 120, 120, 220])
        case .review:
            PetAnimationLayout(row: 8, frameDurationsMilliseconds: [150, 150, 150, 150, 150, 280])
        }
    }
}

public struct PetAnimationLayout: Equatable, Sendable {
    public let row: Int
    public let frameDurationsMilliseconds: [Int]

    public init(row: Int, frameDurationsMilliseconds: [Int]) {
        self.row = row
        self.frameDurationsMilliseconds = frameDurationsMilliseconds
    }

    public var frameCount: Int {
        frameDurationsMilliseconds.count
    }

    public var cycleDurationMilliseconds: Int {
        frameDurationsMilliseconds.reduce(0, +)
    }

    public func frameIndex(at elapsedTime: TimeInterval) -> Int {
        guard !frameDurationsMilliseconds.isEmpty,
              cycleDurationMilliseconds > 0
        else {
            return 0
        }

        let elapsedMilliseconds = max(0, Int(elapsedTime * 1_000))
            % cycleDurationMilliseconds
        var boundary = 0
        for (index, duration) in frameDurationsMilliseconds.enumerated() {
            boundary += duration
            if elapsedMilliseconds < boundary {
                return index
            }
        }
        return frameDurationsMilliseconds.count - 1
    }
}

public struct PetPluginManifest: Codable, Equatable, Sendable {
    public static let canonicalFrameWidth = 192
    public static let canonicalFrameHeight = 208
    public static let canonicalColumns = 8
    public static let canonicalRows = 9

    public let id: String
    public let name: String
    public let version: String?
    public let author: String?
    public let description: String?
    public let spritesheet: String
    public let frameWidth: Int
    public let frameHeight: Int
    public let columns: Int
    public let rows: Int

    public init(
        id: String,
        name: String,
        version: String? = nil,
        author: String? = nil,
        description: String? = nil,
        spritesheet: String = "spritesheet.webp",
        frameWidth: Int = canonicalFrameWidth,
        frameHeight: Int = canonicalFrameHeight,
        columns: Int = canonicalColumns,
        rows: Int = canonicalRows
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.description = description
        self.spritesheet = spritesheet
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.columns = columns
        self.rows = rows
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName
        case version
        case author
        case description
        case spritesheet
        case spritesheetPath
        case frameWidth
        case frameHeight
        case columns
        case rows
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        if let legacyName = try values.decodeIfPresent(String.self, forKey: .name) {
            name = legacyName
        } else {
            name = try values.decode(String.self, forKey: .displayName)
        }
        version = try values.decodeIfPresent(String.self, forKey: .version)
        author = try values.decodeIfPresent(String.self, forKey: .author)
        description = try values.decodeIfPresent(String.self, forKey: .description)
        spritesheet = try values.decodeIfPresent(String.self, forKey: .spritesheet)
            ?? values.decodeIfPresent(String.self, forKey: .spritesheetPath)
            ?? "spritesheet.webp"
        frameWidth = try values.decodeIfPresent(Int.self, forKey: .frameWidth)
            ?? Self.canonicalFrameWidth
        frameHeight = try values.decodeIfPresent(Int.self, forKey: .frameHeight)
            ?? Self.canonicalFrameHeight
        columns = try values.decodeIfPresent(Int.self, forKey: .columns)
            ?? Self.canonicalColumns
        rows = try values.decodeIfPresent(Int.self, forKey: .rows)
            ?? Self.canonicalRows
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(name, forKey: .name)
        try values.encodeIfPresent(version, forKey: .version)
        try values.encodeIfPresent(author, forKey: .author)
        try values.encodeIfPresent(description, forKey: .description)
        try values.encode(spritesheet, forKey: .spritesheet)
        try values.encode(frameWidth, forKey: .frameWidth)
        try values.encode(frameHeight, forKey: .frameHeight)
        try values.encode(columns, forKey: .columns)
        try values.encode(rows, forKey: .rows)
    }

    public func validate() throws {
        let identifier = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty,
              identifier == id,
              identifier != ".",
              identifier != "..",
              identifier.count <= 100,
              identifier.unicodeScalars.first.map(
                  CharacterSet.alphanumerics.contains
              ) == true,
              identifier.unicodeScalars.allSatisfy(Self.allowedIdentifierCharacters.contains)
        else {
            throw PetPluginManifestError.invalidIdentifier
        }
        guard !displayName.isEmpty else {
            throw PetPluginManifestError.invalidName
        }
        guard frameWidth == Self.canonicalFrameWidth,
              frameHeight == Self.canonicalFrameHeight,
              columns == Self.canonicalColumns,
              rows == Self.canonicalRows
        else {
            throw PetPluginManifestError.unsupportedGeometry
        }
        guard !spritesheet.isEmpty,
              URL(fileURLWithPath: spritesheet).lastPathComponent == spritesheet,
              spritesheet != ".",
              spritesheet != ".."
        else {
            throw PetPluginManifestError.invalidSpritesheetPath
        }
    }

    public func spritesheetURL(in packageDirectory: URL) throws -> URL {
        try validate()
        let resolvedPackageDirectory = packageDirectory.resolvingSymlinksInPath()
        let candidate = packageDirectory
            .appendingPathComponent(spritesheet, isDirectory: false)
            .resolvingSymlinksInPath()
        let packagePath = resolvedPackageDirectory.standardizedFileURL.path
        let candidatePath = candidate.standardizedFileURL.path
        guard candidatePath.hasPrefix(packagePath + "/") else {
            throw PetPluginManifestError.invalidSpritesheetPath
        }
        return candidate
    }

    private static let allowedIdentifierCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-_."))
}

public enum PetPluginManifestError: LocalizedError, Equatable {
    case invalidIdentifier
    case invalidName
    case invalidSpritesheetPath
    case unsupportedGeometry

    public var errorDescription: String? {
        switch self {
        case .invalidIdentifier:
            "宠物 ID 只能包含字母、数字、连字符、下划线和句点。"
        case .invalidName:
            "宠物名称不能为空。"
        case .invalidSpritesheetPath:
            "宠物图集必须是包目录内的单个文件。"
        case .unsupportedGeometry:
            "宠物图集必须使用 192×208 单格、8 列、9 行。"
        }
    }
}
