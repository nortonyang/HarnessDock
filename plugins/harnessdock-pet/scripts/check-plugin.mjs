import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const pluginDir = resolve(scriptDir, "..");
const manifest = JSON.parse(await readFile(resolve(pluginDir, "package.json"), "utf8"));
const patch = await readFile(resolve(pluginDir, "cordis.patch.yml"), "utf8");
const client = await readFile(resolve(pluginDir, "lib/client.js"), "utf8");
const assets = JSON.parse(await readFile(resolve(pluginDir, "lib/assets.json"), "utf8"));

assert.equal(manifest.name, "@harnessdock/pet");
assert.equal(manifest.dsh.bundle.patch, "./cordis.patch.yml");
assert.equal(manifest.dsh.client.platform, "web");
assert.equal(manifest.exports["./client"], "./lib/client.js");
assert.match(patch, /id:\s*pet/);
assert.match(patch, /name:\s*'@harnessdock\/pet'/);
assert.match(client, /window\.__ModuleLoader__\.load/);
assert.match(client, /id:\s*"@harnessdock\/pet"/);
assert.match(client, /ctx\.slots\.inject\("shell\.overlay"/);
assert.match(client, /ctx\.slots\.inject\("settings\.plugins\.tab"/);
assert.match(client, /data:image\/webp;base64,/);
assert.match(client, /const DISPLAY_WIDTH = 112;/);
assert.match(client, /width:\s*\$\{DISPLAY_WIDTH\}px/);
assert.match(client, /pointer-events:\s*none/);
assert.match(client, /const DOCK_EDGES = Object\.freeze\(\["left", "right", "bottom"\]\)/);
assert.match(client, /event\.altKey/);
assert.match(client, /document\.addEventListener\("pointerdown", onPointerDown, true\)/);
assert.match(client, /document\.addEventListener\("click", onClick, true\)/);
assert.match(client, /clicked:\s*\{ row: 4, frames: 5, interval: 150 \}/);
assert.match(client, /hovering:\s*\{ row: 6, frames: 6, interval: 260 \}/);
assert.match(client, /dragging:\s*\{ row: 7, frames: 6, interval: 140 \}/);
assert.match(client, /commandRunning:\s*\{ row: 7, frames: 6, interval: 140 \}/);
assert.match(client, /commandSucceeded:\s*\{ row: 8, frames: 6, interval: 180 \}/);
assert.match(client, /commandFailed:\s*\{ row: 5, frames: 8, interval: 150 \}/);
assert.match(client, /sessions\?\.binding\(listSnapshot\.current\)\?\.session/);
assert.match(client, /data-command-state/);
assert.match(client, /STATES\.waving\.frames \* STATES\.waving\.interval/);
assert.match(client, /animation\.frames \* animation\.interval/);
assert.match(client, /Math\.hypot/);
assert.match(client, /isInteractiveTarget\(event\.target\) && !event\.altKey/);
assert.match(client, /data-edge/);
assert.match(client, /data-state/);
assert.match(client, /translate\(-62%, -50%\)/);
assert.match(client, /translate\(62%, -50%\)/);
assert.match(client, /translate\(-50%, 55%\)/);
assert.match(client, /translate\(-28%, -50%\)/);
assert.match(client, /translate\(28%, -50%\)/);
assert.match(client, /translate\(-50%, 22%\)/);
assert.match(
  client,
  /\.harnessdock-pet-overlay\[data-edge="left"\] \.harnessdock-pet-sprite\s*\{\s*transform:\s*rotate\(22deg\) scaleX\(-1\);\s*\}/
);
assert.match(client, /data-edge="right"\] \.harnessdock-pet-sprite \{ transform: rotate\(-22deg\); \}/);
assert.match(client, /transform-origin:\s*50% 100%/);
assert.match(client, /data-edge="left"\]\[data-dragging="true"\][\s\S]{0,100}scaleX\(-1\)/);
assert.match(client, /data-edge="right"\]\[data-dragging="true"\][\s\S]{0,100}transform:\s*none/);
assert.doesNotMatch(client, /data-edge="bottom"\] \.harnessdock-pet-sprite/);
assert.doesNotMatch(client, /className:\s*"harnessdock-pet-overlay"[\s\S]{0,200}onClick:/);
assert.doesNotMatch(client, /__(?:DEEPWHALE|MARINA)_DATA_URL__/);
assert.match(assets.deepwhale.sha256, /^[a-f0-9]{64}$/);
assert.match(assets.marina.sha256, /^[a-f0-9]{64}$/);

let handoff;
const effects = [];
const registrations = [];
const styleNodes = [];
const storageValues = new Map([
  ["dsharness.pet.preferences.v1", JSON.stringify({
    petId: "marina",
    visible: false,
    edge: "left",
    offset: 0.3
  })]
]);
const windowMock = {
  __ModuleLoader__: { load(value) { handoff = value; } },
  localStorage: {
    getItem(key) { return storageValues.get(key) ?? null; },
    setItem(key, value) { storageValues.set(key, value); }
  },
  addEventListener() {},
  removeEventListener() {}
};
const documentMock = {
  head: { appendChild(node) { styleNodes.push(node); } },
  createElement() { return { dataset: {}, remove() {} }; }
};

vm.runInNewContext(client, { window: windowMock, document: documentMock }, { filename: "lib/client.js" });
assert.equal(handoff.id, "@harnessdock/pet");
const browserPlugin = handoff.factory((specifier) => {
  if (specifier === "react") return {};
  throw new Error(`unexpected client require: ${specifier}`);
});
assert.deepEqual([...browserPlugin.inject], ["sessions", "slots"]);
assert.deepEqual(
  JSON.parse(storageValues.get("harnessdock.pet.preferences.v1")),
  { petId: "marina", visible: false, edge: "left", offset: 0.3 }
);
assert.equal(browserPlugin.__test.readPreferences().petId, "marina");
assert.equal(browserPlugin.__test.nearestDock(5, 300, 1000, 800).edge, "left");
assert.equal(browserPlugin.__test.nearestDock(995, 300, 1000, 800).edge, "right");
assert.equal(browserPlugin.__test.nearestDock(500, 795, 1000, 800).edge, "bottom");
assert.equal(browserPlugin.__test.nearestDock(5, 0, 1000, 800).offset, 0.14);
const normalized = browserPlugin.__test.normalizePreferences({
  petId: "unknown",
  visible: "yes",
  edge: "top",
  offset: 2
});
assert.equal(normalized.petId, "deepwhale");
assert.equal(normalized.visible, true);
assert.equal(normalized.edge, "right");
assert.equal(normalized.offset, 0.86);
const sessionList = {
  current: "session-1",
  byId: { "session-1": { running: true } },
  jobsBySession: {}
};
assert.equal(browserPlugin.__test.commandSignal(sessionList, {}).busy, true);
assert.equal(browserPlugin.__test.commandSignal({
  ...sessionList,
  byId: { "session-1": { running: false } },
  jobsBySession: { "session-1": [{ id: "bash-1", status: "stopping", startedAt: 10 }] }
}, {}).busy, true);
assert.match(
  browserPlugin.__test.commandSignal(sessionList, { lastAgentError: "model failed" }).errorToken,
  /model failed/
);
assert.match(browserPlugin.__test.commandSignal({
  ...sessionList,
  byId: { "session-1": { running: false } },
  jobsBySession: {
    "session-1": [{ id: "bash-2", status: "failed", startedAt: 10, finishedAt: 20 }]
  }
}, {}).errorToken, /job:bash-2:20/);
const emptyStore = {
  subscribe() { return () => {}; },
  getSnapshot() { return { current: undefined, byId: {}, jobsBySession: {} }; }
};
browserPlugin.apply({
  effect(effect) {
    const disposer = effect();
    if (typeof disposer === "function") effects.push(disposer);
  },
  sessions: {
    list: emptyStore,
    binding() { return undefined; }
  },
  slots: {
    inject(_name, register) { return register(); },
    register(options, component) {
      registrations.push({ options, component });
      return () => {};
    }
  }
});
assert.deepEqual(
  registrations.map(({ options }) => `${options.name}:${options.id}`),
  ["shell.overlay:harnessdock-pet-overlay", "settings.plugins.tab:desktop-pet"]
);
assert.equal(styleNodes.length, 1);
for (const dispose of effects.reverse()) dispose();

console.log("@harnessdock/pet checks passed");
