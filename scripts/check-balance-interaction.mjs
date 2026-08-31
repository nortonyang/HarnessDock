import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(
  new URL("../Sources/HarnessDockApp/HarnessWebView.swift", import.meta.url),
  "utf8"
);

const sidebarBlock = source.match(
  /const updateSidebarMode = \(\) => \{[\s\S]*?\n      \};/
)?.[0];

assert.ok(sidebarBlock, "sidebar mode synchronization must remain discoverable");
assert.match(
  sidebarBlock,
  /const wasCompact = root\.dataset\.sidebarCompact === 'true';/,
  "sidebar synchronization must remember the previous compact state"
);
assert.match(
  sidebarBlock,
  /if \(compact && !wasCompact\) setExpanded\(false\);/,
  "the balance panel must close only when the sidebar enters compact mode"
);
assert.doesNotMatch(
  sidebarBlock,
  /if \(compact\) setExpanded\(false\);/,
  "ordinary clicks in an already compact sidebar must not close the balance panel"
);
assert.match(
  source,
  /setExpanded\(root\.dataset\.expanded !== 'true'\);/,
  "the balance button must keep toggling its expanded state"
);

console.log("Balance interaction checks passed");
