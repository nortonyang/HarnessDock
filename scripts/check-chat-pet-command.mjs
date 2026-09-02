import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";

const source = await readFile(
  new URL("../Sources/HarnessDockCore/DeepSeekChatCommandBehavior.swift", import.meta.url),
  "utf8"
);
const webViewSource = await readFile(
  new URL("../Sources/HarnessDockApp/DeepSeekChatWebView.swift", import.meta.url),
  "utf8"
);
const match = source.match(/userScript = #"""([\s\S]*?)"""#/);
assert.ok(match, "Chat pet command user script must exist");
assert.doesNotMatch(match[1], /textContent|innerText|innerHTML/);
assert.match(match[1], /postMessage\(state\)/);
assert.match(webViewSource, /DeepSeekChatCommandBehavior\.userScript/);
assert.match(webViewSource, /DeepSeekChatCommandBehavior\.messageHandlerName/);
assert.match(webViewSource, /PetCommandActivity\(rawValue: rawValue\)/);
assert.doesNotMatch(webViewSource, /message\.body[^\n]*(?:log|append|pasteboard|UserDefaults)/i);

class FakeElement {
  constructor(attributes = {}) {
    this.attributes = new Map(Object.entries(attributes));
    this.isConnected = true;
    this.hidden = false;
    this.visible = true;
  }

  getAttribute(name) {
    return this.attributes.get(name) ?? null;
  }

  getBoundingClientRect() {
    return this.visible
      ? { width: 100, height: 32 }
      : { width: 0, height: 0 };
  }
}

let controls = [];
let errors = [];
let observerCallback;
const posted = [];
const documentMock = {
  documentElement: {},
  querySelectorAll(selector) {
    return selector.includes("role=\"alert\"") ? errors : controls;
  }
};
const windowMock = {
  webkit: {
    messageHandlers: {
      dshPetCommand: {
        postMessage(value) { posted.push(value); }
      }
    }
  },
  getComputedStyle(element) {
    return element.visible
      ? { display: "block", visibility: "visible" }
      : { display: "none", visibility: "hidden" };
  },
  addEventListener() {}
};
class FakeMutationObserver {
  constructor(callback) { observerCallback = callback; }
  observe() {}
  disconnect() {}
}

const oldError = new FakeElement({ role: "alert" });
errors = [oldError];
vm.runInNewContext(match[1], {
  window: windowMock,
  document: documentMock,
  Element: FakeElement,
  MutationObserver: FakeMutationObserver,
  Set,
  WeakSet,
  Array,
});
assert.deepEqual(posted, ["idle"], "Existing errors must only establish a baseline");

const stopButton = new FakeElement({ "aria-label": "停止生成" });
controls = [stopButton];
observerCallback();
assert.deepEqual(posted, ["idle", "running"]);

const newError = new FakeElement({ "data-status": "error" });
errors = [oldError, newError];
observerCallback();
assert.deepEqual(posted, ["idle", "running"]);

controls = [];
observerCallback();
assert.deepEqual(posted, ["idle", "running", "failed"]);

errors = [];
controls = [new FakeElement({ title: "Stop generating" })];
observerCallback();
controls = [];
observerCallback();
assert.deepEqual(posted, ["idle", "running", "failed", "running", "succeeded"]);
assert.ok(posted.every(state => ["idle", "running", "succeeded", "failed"].includes(state)));

console.log("Chat pet command checks passed");
