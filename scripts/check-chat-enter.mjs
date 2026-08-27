import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";

class FakeEvent {
  constructor(type, options = {}) {
    this.type = type;
    this.key = options.key;
    this.keyCode = options.keyCode ?? 0;
    this.isComposing = options.isComposing ?? false;
    this.inputType = options.inputType;
    this.shiftKey = options.shiftKey ?? false;
    this.metaKey = options.metaKey ?? false;
    this.altKey = options.altKey ?? false;
    this.ctrlKey = options.ctrlKey ?? false;
    this.defaultPrevented = false;
    this.propagationStopped = false;
    this.immediatePropagationStopped = false;
  }

  preventDefault() {
    this.defaultPrevented = true;
  }

  stopPropagation() {
    this.propagationStopped = true;
  }

  stopImmediatePropagation() {
    this.propagationStopped = true;
    this.immediatePropagationStopped = true;
  }
}

class FakeWindow {
  constructor() {
    this.listeners = new Map();
    this.sendCount = 0;
    this.pageEnterCount = 0;
    this.timers = [];
  }

  addEventListener(type, listener) {
    const listeners = this.listeners.get(type) ?? [];
    listeners.push(listener);
    this.listeners.set(type, listeners);
  }

  setTimeout(callback) {
    this.timers.push(callback);
    return this.timers.length;
  }

  dispatchFrom(target, event) {
    event.target = target;
    event.composedPath = () => [target];
    for (const listener of this.listeners.get(event.type) ?? []) {
      listener(event);
      if (event.immediatePropagationStopped) break;
    }
    if (
      event.type === "keydown"
      && event.key === "Enter"
      && !event.defaultPrevented
      && typeof target.commitComposition === "function"
      && target.compositionText.length > 0
    ) {
      target.commitComposition();
      this.dispatchFrom(target, new FakeEvent("compositionend"));
    }
    return !event.defaultPrevented;
  }
}

class FakeElement {
  constructor(window) {
    this.window = window;
    this.isContentEditable = false;
  }

  dispatchEvent(event) {
    return this.window.dispatchFrom(this, event);
  }

  closest() {
    return this;
  }

  getAttribute() {
    return null;
  }
}

class FakeInputElement extends FakeElement {
  constructor(window) {
    super(window);
    this.type = "text";
    this.disabled = false;
    this.readOnly = false;
  }
}

class FakeTextAreaElement extends FakeElement {
  constructor(window) {
    super(window);
    this.value = "";
    this.selectionStart = 0;
    this.selectionEnd = 0;
    this.compositionText = "";
    this.disabled = false;
    this.readOnly = false;
  }

  setRangeText(replacement, start, end) {
    this.value = this.value.slice(0, start) + replacement + this.value.slice(end);
    this.selectionStart = start + replacement.length;
    this.selectionEnd = this.selectionStart;
  }

  commitComposition() {
    if (!this.compositionText) return;
    this.setRangeText(this.compositionText, this.selectionStart, this.selectionEnd);
    this.compositionText = "";
  }
}

const source = await readFile(
  new URL("../Sources/HarnessDockCore/DeepSeekChatEnterBehavior.swift", import.meta.url),
  "utf8"
);
const match = source.match(/userScript = #"""([\s\S]*?)"""#/);
assert.ok(match, "Chat Enter user script must exist");

const fakeWindow = new FakeWindow();
const fakeDocument = {
  execCommand: () => false,
};
vm.runInNewContext(match[1], {
  window: fakeWindow,
  document: fakeDocument,
  Element: FakeElement,
  HTMLInputElement: FakeInputElement,
  HTMLTextAreaElement: FakeTextAreaElement,
  InputEvent: FakeEvent,
  Set,
});

for (const type of ["keydown", "keypress", "keyup"]) {
  fakeWindow.addEventListener(type, event => {
    if (event.key !== "Enter") return;
    fakeWindow.pageEnterCount += 1;
    if (
      event.type === "keydown"
      && event.target instanceof FakeTextAreaElement
      && event.target.value.trim().length > 0
    ) {
      fakeWindow.sendCount += 1;
    }
  });
}

function resetPageCounters() {
  fakeWindow.sendCount = 0;
  fakeWindow.pageEnterCount = 0;
}

function fireEnter(target, modifiers = {}) {
  return ["keydown", "keypress", "keyup"].map(type => {
    const event = new FakeEvent(type, {
      key: "Enter",
      keyCode: modifiers.keyCode ?? 13,
      ...modifiers,
    });
    target.dispatchEvent(event);
    return event.defaultPrevented;
  });
}

function fireCompositionInput(target) {
  target.dispatchEvent(new FakeEvent("input", {
    isComposing: true,
    inputType: "insertCompositionText",
  }));
}

const multiline = new FakeTextAreaElement(fakeWindow);
multiline.value = "first";
multiline.selectionStart = multiline.selectionEnd = multiline.value.length;
const multilineResults = [
  fireEnter(multiline, { shiftKey: true }),
  fireEnter(multiline, { metaKey: true }),
  fireEnter(multiline, { altKey: true }),
  fireEnter(multiline, { ctrlKey: true }),
];
assert.equal(multiline.value, "first\n\n\n\n");
assert.equal(fakeWindow.sendCount, 0);
assert.equal(fakeWindow.pageEnterCount, 0);
assert.deepEqual(multilineResults, Array(4).fill([true, true, true]));

resetPageCounters();
const singleLineResult = fireEnter(new FakeInputElement(fakeWindow));
assert.deepEqual(singleLineResult, [true, true, true]);
assert.equal(fakeWindow.sendCount, 0);
assert.equal(fakeWindow.pageEnterCount, 0);

resetPageCounters();
const emptyInput = new FakeTextAreaElement(fakeWindow);
const emptyResult = fireEnter(emptyInput);
assert.deepEqual(emptyResult, [false, false, false]);
assert.equal(fakeWindow.sendCount, 0);
assert.equal(fakeWindow.pageEnterCount, 3);

resetPageCounters();
const composingInput = new FakeTextAreaElement(fakeWindow);
composingInput.compositionText = "hello";
fireCompositionInput(composingInput);
const composingResult = fireEnter(composingInput);
assert.deepEqual(composingResult, [false, false, false]);
assert.equal(composingInput.value, "hello");
assert.equal(fakeWindow.sendCount, 0);
assert.equal(fakeWindow.pageEnterCount, 0);

const secondEnterResult = fireEnter(composingInput);
assert.deepEqual(secondEnterResult, [false, false, false]);
assert.equal(fakeWindow.sendCount, 1);
assert.equal(fakeWindow.pageEnterCount, 3);

resetPageCounters();
const buttonResult = fireEnter(new FakeElement(fakeWindow));
assert.deepEqual(buttonResult, [false, false, false]);
assert.equal(fakeWindow.sendCount, 0);
assert.equal(fakeWindow.pageEnterCount, 3);

console.log("Chat Enter checks passed");
