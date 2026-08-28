import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(
  new URL("../Sources/HarnessDockApp/AppModel.swift", import.meta.url),
  "utf8"
);

const launchBlock = source.match(
  /private func launchOrAttach\(in workspace: URL\) async \{[\s\S]*?\n    private func serverIsReachable/
)?.[0];

assert.ok(launchBlock, "launchOrAttach implementation must remain discoverable");
assert.match(
  launchBlock,
  /var environment = ProcessInfo\.processInfo\.environment/,
  "managed Harness must begin with the app launch environment"
);
assert.doesNotMatch(
  launchBlock,
  /removeValue\(forKey:\s*"DEEPSEEK_API_KEY"\)/,
  "managed Harness must not discard DEEPSEEK_API_KEY"
);
assert.doesNotMatch(
  launchBlock,
  /balanceKeychain|balanceAPIKey\(/,
  "Keychain-only balance credentials must not be copied into Harness"
);
assert.match(
  launchBlock,
  /process\.environment = environment/,
  "the inherited environment must be assigned to the Harness process"
);

console.log("Harness environment credential checks passed");
