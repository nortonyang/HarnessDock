import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(
  new URL("../Sources/HarnessDockApp/AppModel.swift", import.meta.url),
  "utf8"
);
const resolverSource = await readFile(
  new URL("../Sources/HarnessDockCore/LoginShellEnvironment.swift", import.meta.url),
  "utf8"
);

const launchBlock = source.match(
  /private func launchOrAttach\(in workspace: URL\) async \{[\s\S]*?\n    private func serverIsReachable/
)?.[0];

assert.ok(launchBlock, "launchOrAttach implementation must remain discoverable");
assert.match(
  launchBlock,
  /var environment = await resolvedHarnessEnvironment\(\)/,
  "managed Harness must resolve its environment before launch"
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

const resolverBlock = source.match(
  /private func resolvedHarnessEnvironment\(\) async -> \[String: String\] \{[\s\S]*?\n    private func serverIsReachable/
)?.[0];

assert.ok(resolverBlock, "Harness environment resolver must remain discoverable");
assert.match(
  resolverBlock,
  /LoginShellEnvironment\.value\([\s\S]*?for: "DEEPSEEK_API_KEY"/,
  "Finder launches must resolve DEEPSEEK_API_KEY from the login shell"
);
assert.doesNotMatch(
  resolverBlock,
  /balanceKeychain|balanceAPIKey\(/,
  "Keychain-only balance credentials must not be copied into Harness"
);
assert.doesNotMatch(
  resolverBlock,
  /appendLog|print\(/,
  "resolved credentials must never be written to logs"
);
assert.match(
  resolverSource,
  /\/usr\/bin\/printenv/,
  "the login shell resolver must request one exported variable"
);
assert.match(
  resolverSource,
  /standardError = FileHandle\.nullDevice/,
  "shell startup diagnostics must not leak into app logs"
);
assert.doesNotMatch(
  resolverSource,
  /\/usr\/bin\/env\b|printenv\s+-0/,
  "the resolver must not import the shell's full environment"
);

console.log("Harness environment credential checks passed");
