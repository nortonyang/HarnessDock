import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const appSource = await readFile(
  new URL("../Sources/HarnessDockApp/AppModel.swift", import.meta.url),
  "utf8"
);
const migrationSource = await readFile(
  new URL("../Sources/HarnessDockCore/HarnessPetProfileMigration.swift", import.meta.url),
  "utf8"
);

const launchBlock = appSource.match(
  /private func launchOrAttach\(in workspace: URL\) async \{[\s\S]*?\n    private func resolvedHarnessEnvironment/
)?.[0];
const migrationBlock = appSource.match(
  /private func migrateLegacyPetProfileIfNeeded\([\s\S]*?\n    private nonisolated static func runHarnessCommand/
)?.[0];

assert.ok(launchBlock, "Harness launch implementation must remain discoverable");
assert.ok(migrationBlock, "Pet profile migration must remain discoverable");
assert.match(
  launchBlock,
  /migrateLegacyPetProfileIfNeeded\(/,
  "legacy pet profile migration must run before managed Harness launches"
);
assert.match(
  migrationBlock,
  /initialState\.needsMigration/,
  "migration must be gated by an exact legacy-profile state"
);
assert.match(
  migrationBlock,
  /needsBundledRelink/,
  "app-owned plugin links must follow the current app bundle after moves"
);

const addPosition = migrationBlock.indexOf('"plugin", "--profile", "web", "add"');
const removePosition = migrationBlock.indexOf('"plugin", "--profile", "web", "remove"');
assert.ok(addPosition >= 0, "migration must add the bundled current plugin");
assert.ok(removePosition > addPosition, "migration must add the current plugin before removing legacy");
assert.match(
  migrationBlock,
  /migratedState\.canBootCurrentPet/,
  "migration must verify the final profile before starting Harness"
);
assert.doesNotMatch(
  migrationBlock,
  /write\(|writeFile|createFile|removeItem/,
  "AppModel must not edit profile or lock files directly"
);
assert.match(migrationSource, /legacyPackageName = "@dsharness\/pet"/);
assert.match(migrationSource, /currentPackageName = "@harnessdock\/pet"/);

console.log("Pet profile migration checks passed");
