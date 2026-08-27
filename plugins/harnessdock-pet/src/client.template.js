window.__ModuleLoader__.load({
  id: "@harnessdock/pet",
  factory: (require) => {
    const module = { exports: {} };
    const exports = module.exports;
    Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });

    const React = require("react");
    const STORAGE_KEY = "harnessdock.pet.preferences.v1";
    const LEGACY_STORAGE_KEYS = Object.freeze(["dsharness.pet.preferences.v1"]);
    const FRAME_WIDTH = 192;
    const FRAME_HEIGHT = 208;
    const COLUMN_COUNT = 8;
    const ROW_COUNT = 9;
    const DISPLAY_WIDTH = 112;
    const DISPLAY_HEIGHT = Math.round(DISPLAY_WIDTH * FRAME_HEIGHT / FRAME_WIDTH);
    const DOCK_EDGES = Object.freeze(["left", "right", "bottom"]);
    const DOCK_LABELS = Object.freeze({ left: "左侧", right: "右侧", bottom: "底部" });
    const OFFSET_MIN = 0.14;
    const OFFSET_MAX = 0.86;
    const STATES = {
      idle: { row: 0, frames: 6, interval: 260 },
      waving: { row: 3, frames: 4, interval: 180 },
      clicked: { row: 4, frames: 5, interval: 150 },
      commandFailed: { row: 5, frames: 8, interval: 150 },
      hovering: { row: 6, frames: 6, interval: 260 },
      dragging: { row: 7, frames: 6, interval: 140 },
      commandRunning: { row: 7, frames: 6, interval: 140 },
      commandSucceeded: { row: 8, frames: 6, interval: 180 }
    };
    const PETS = {
      deepwhale: {
        id: "deepwhale",
        name: "DeepWhale",
        description: "DeepSeek 蓝鲸伙伴",
        asset: __DEEPWHALE_DATA_URL__
      },
      marina: {
        id: "marina",
        name: "Marina",
        description: "蓝发鲸鱼女仆伙伴",
        asset: __MARINA_DATA_URL__
      }
    };
    const DEFAULT_PREFERENCES = Object.freeze({
      petId: "deepwhale",
      visible: true,
      edge: "right",
      offset: 0.62
    });
    const EMPTY_SESSION_LIST = Object.freeze({
      current: undefined,
      byId: Object.freeze({}),
      jobsBySession: Object.freeze({})
    });
    const EMPTY_SESSION_SNAPSHOT = Object.freeze({
      running: false,
      promptError: null,
      lastAgentError: null
    });
    const listeners = new Set();

    function clampOffset(value) {
      return Math.min(OFFSET_MAX, Math.max(OFFSET_MIN, value));
    }

    function nearestDock(clientX, clientY, viewportWidth, viewportHeight) {
      const candidates = [
        { edge: "left", distance: clientX },
        { edge: "right", distance: viewportWidth - clientX },
        { edge: "bottom", distance: viewportHeight - clientY }
      ];
      const nearest = candidates.reduce((best, candidate) => (
        candidate.distance < best.distance ? candidate : best
      ));
      const rawOffset = nearest.edge === "bottom"
        ? clientX / viewportWidth
        : clientY / viewportHeight;
      return { edge: nearest.edge, offset: clampOffset(rawOffset) };
    }

    function normalizePreferences(value) {
      if (!value || typeof value !== "object" || Array.isArray(value)) {
        return DEFAULT_PREFERENCES;
      }
      return {
        petId: Object.prototype.hasOwnProperty.call(PETS, value.petId)
          ? value.petId
          : DEFAULT_PREFERENCES.petId,
        visible: typeof value.visible === "boolean"
          ? value.visible
          : DEFAULT_PREFERENCES.visible,
        edge: DOCK_EDGES.includes(value.edge)
          ? value.edge
          : DEFAULT_PREFERENCES.edge,
        offset: Number.isFinite(value.offset)
          ? clampOffset(value.offset)
          : DEFAULT_PREFERENCES.offset
      };
    }

    function readPreferences() {
      try {
        for (const key of [STORAGE_KEY, ...LEGACY_STORAGE_KEYS]) {
          const value = window.localStorage.getItem(key);
          if (value === null) continue;
          try {
            const normalized = normalizePreferences(JSON.parse(value));
            if (key !== STORAGE_KEY) {
              window.localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
            }
            return normalized;
          } catch (_error) {
            // Ignore a malformed value and continue to a compatible legacy key.
          }
        }
        return DEFAULT_PREFERENCES;
      } catch (_error) {
        return DEFAULT_PREFERENCES;
      }
    }

    let preferences = readPreferences();

    function emitPreferences(next, persist) {
      const normalized = normalizePreferences(next);
      if (normalized.petId === preferences.petId
          && normalized.visible === preferences.visible
          && normalized.edge === preferences.edge
          && normalized.offset === preferences.offset) {
        return;
      }
      preferences = normalized;
      if (persist) {
        try {
          window.localStorage.setItem(STORAGE_KEY, JSON.stringify(preferences));
        } catch (_error) {
          // A blocked storage backend must not prevent the pet from switching now.
        }
      }
      for (const listener of listeners) listener();
    }

    function subscribePreferences(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    }

    function usePreferences() {
      return React.useSyncExternalStore(
        subscribePreferences,
        () => preferences,
        () => DEFAULT_PREFERENCES
      );
    }

    function useReducedMotion() {
      const getSnapshot = () => typeof window.matchMedia === "function"
        && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      const subscribe = (listener) => {
        if (typeof window.matchMedia !== "function") return () => {};
        const media = window.matchMedia("(prefers-reduced-motion: reduce)");
        media.addEventListener("change", listener);
        return () => media.removeEventListener("change", listener);
      };
      return React.useSyncExternalStore(subscribe, getSnapshot, () => false);
    }

    function errorIdentity(error) {
      if (error === null || error === undefined) return null;
      if (typeof error === "string") return error;
      const detail = error.error && typeof error.error === "object" ? error.error : error;
      const code = typeof detail.code === "string" ? detail.code : "unknown";
      const message = typeof detail.message === "string" ? detail.message : "";
      return `${code}:${message}`;
    }

    function commandSignal(listSnapshot, sessionSnapshot) {
      const list = listSnapshot || EMPTY_SESSION_LIST;
      const session = sessionSnapshot || EMPTY_SESSION_SNAPSHOT;
      const sessionId = list.current;
      const summary = sessionId === undefined ? undefined : list.byId?.[sessionId];
      const jobs = sessionId === undefined ? [] : (list.jobsBySession?.[sessionId] || []);
      const busy = summary?.running === true
        || session.running === true
        || jobs.some((job) => job.status === "running" || job.status === "stopping");
      const latestFailedJob = jobs
        .filter((job) => job.status === "failed")
        .reduce((latest, job) => {
          if (latest === null) return job;
          const latestTime = latest.finishedAt ?? latest.startedAt ?? 0;
          const jobTime = job.finishedAt ?? job.startedAt ?? 0;
          return jobTime >= latestTime ? job : latest;
        }, null);
      const errorParts = [
        errorIdentity(session.lastAgentError),
        errorIdentity(session.promptError),
        latestFailedJob === null
          ? null
          : `job:${latestFailedJob.id}:${latestFailedJob.finishedAt ?? latestFailedJob.startedAt ?? 0}`
      ].filter((part) => part !== null);
      return {
        sessionId,
        busy,
        errorToken: errorParts.length === 0 ? null : errorParts.join("|")
      };
    }

    function useHarnessCommandAnimation(sessions) {
      const listStore = sessions?.list;
      const subscribeList = React.useCallback(
        (listener) => listStore?.subscribe(listener) ?? (() => {}),
        [listStore]
      );
      const getListSnapshot = React.useCallback(
        () => listStore?.getSnapshot() ?? EMPTY_SESSION_LIST,
        [listStore]
      );
      const listSnapshot = React.useSyncExternalStore(
        subscribeList,
        getListSnapshot,
        () => EMPTY_SESSION_LIST
      );
      const sessionStore = listSnapshot.current === undefined
        ? undefined
        : sessions?.binding(listSnapshot.current)?.session;
      const subscribeSession = React.useCallback(
        (listener) => sessionStore?.subscribe(listener) ?? (() => {}),
        [sessionStore]
      );
      const getSessionSnapshot = React.useCallback(
        () => sessionStore?.getSnapshot() ?? EMPTY_SESSION_SNAPSHOT,
        [sessionStore]
      );
      const sessionSnapshot = React.useSyncExternalStore(
        subscribeSession,
        getSessionSnapshot,
        () => EMPTY_SESSION_SNAPSHOT
      );
      const signal = commandSignal(listSnapshot, sessionSnapshot);
      const signalRef = React.useRef(signal);
      const previousRef = React.useRef(null);
      const terminalTimer = React.useRef(null);
      const terminalState = React.useRef(null);
      const [commandState, setCommandState] = React.useState(
        signal.busy ? "commandRunning" : null
      );
      signalRef.current = signal;

      React.useEffect(() => {
        const clearTerminal = () => {
          if (terminalTimer.current !== null) {
            window.clearTimeout(terminalTimer.current);
            terminalTimer.current = null;
          }
          terminalState.current = null;
        };
        const playTerminal = (nextState) => {
          clearTerminal();
          terminalState.current = nextState;
          setCommandState(nextState);
          const animation = STATES[nextState];
          terminalTimer.current = window.setTimeout(() => {
            terminalTimer.current = null;
            terminalState.current = null;
            setCommandState(signalRef.current.busy ? "commandRunning" : null);
          }, animation.frames * animation.interval);
        };
        const previous = previousRef.current;
        if (previous === null || previous.sessionId !== signal.sessionId) {
          clearTerminal();
          setCommandState(signal.busy ? "commandRunning" : null);
        } else {
          const hasNewError = signal.errorToken !== null
            && signal.errorToken !== previous.errorToken;
          if (hasNewError) {
            playTerminal("commandFailed");
          } else if (signal.busy && !previous.busy) {
            clearTerminal();
            setCommandState("commandRunning");
          } else if (!signal.busy && previous.busy) {
            playTerminal("commandSucceeded");
          } else if (signal.busy && terminalState.current === null) {
            setCommandState("commandRunning");
          }
        }
        previousRef.current = signal;
      }, [signal.busy, signal.errorToken, signal.sessionId]);

      React.useEffect(() => () => {
        if (terminalTimer.current !== null) window.clearTimeout(terminalTimer.current);
      }, []);

      return commandState;
    }

    function PetSprite({ petId, state = "idle", compact = false }) {
      const [frame, setFrame] = React.useState(0);
      const reducedMotion = useReducedMotion();
      const animation = STATES[state] || STATES.idle;
      const width = compact ? 76 : DISPLAY_WIDTH;
      const height = Math.round(width * FRAME_HEIGHT / FRAME_WIDTH);

      React.useEffect(() => {
        setFrame(0);
        if (reducedMotion || animation.frames <= 1) return undefined;
        const timer = window.setInterval(() => {
          setFrame((current) => (current + 1) % animation.frames);
        }, animation.interval);
        return () => window.clearInterval(timer);
      }, [animation.frames, animation.interval, petId, reducedMotion, state]);

      return React.createElement("span", {
        className: "harnessdock-pet-sprite",
        "aria-hidden": "true",
        style: {
          width: `${width}px`,
          height: `${height}px`,
          backgroundImage: `url(${PETS[petId].asset})`,
          backgroundSize: `${width * COLUMN_COUNT}px ${height * ROW_COUNT}px`,
          backgroundPosition: `${-frame * width}px ${-animation.row * height}px`
        }
      });
    }

    function PetOverlay({ sessions }) {
      const current = usePreferences();
      const reducedMotion = useReducedMotion();
      const commandState = useHarnessCommandAnimation(sessions);
      const [state, setState] = React.useState("idle");
      const [peeking, setPeeking] = React.useState(false);
      const [dragPoint, setDragPoint] = React.useState(null);
      const resetTimer = React.useRef(null);
      const peekTimer = React.useRef(null);
      const reactionTimer = React.useRef(null);
      const pressRef = React.useRef(null);
      const dragPointRef = React.useRef(null);
      const hoverRef = React.useRef(false);
      const suppressClickUntil = React.useRef(0);
      const overlayRef = React.useRef(null);

      React.useEffect(() => {
        if (reducedMotion) {
          setPeeking(false);
          setState("idle");
          return undefined;
        }
        const peek = () => {
          if (dragPointRef.current !== null || hoverRef.current || reactionTimer.current !== null) return;
          setPeeking(true);
          setState("waving");
          if (resetTimer.current !== null) window.clearTimeout(resetTimer.current);
          if (peekTimer.current !== null) window.clearTimeout(peekTimer.current);
          resetTimer.current = window.setTimeout(() => {
            setState("idle");
            resetTimer.current = null;
          }, STATES.waving.frames * STATES.waving.interval);
          peekTimer.current = window.setTimeout(() => {
            setPeeking(false);
            peekTimer.current = null;
          }, 1600);
        };
        const timer = window.setInterval(peek, 10000);
        return () => {
          window.clearInterval(timer);
          if (resetTimer.current !== null) window.clearTimeout(resetTimer.current);
          if (peekTimer.current !== null) window.clearTimeout(peekTimer.current);
        };
      }, [reducedMotion]);

      React.useEffect(() => () => {
        if (reactionTimer.current !== null) window.clearTimeout(reactionTimer.current);
      }, []);

      React.useEffect(() => {
        const consume = (event) => {
          event.preventDefault();
          event.stopPropagation();
        };
        const cancelAutomaticPeek = () => {
          if (resetTimer.current !== null) {
            window.clearTimeout(resetTimer.current);
            resetTimer.current = null;
          }
          if (peekTimer.current !== null) {
            window.clearTimeout(peekTimer.current);
            peekTimer.current = null;
          }
        };
        const isInsidePet = (event) => {
          const element = overlayRef.current;
          if (!element) return false;
          const rect = element.getBoundingClientRect();
          return event.clientX >= rect.left && event.clientX <= rect.right
            && event.clientY >= rect.top && event.clientY <= rect.bottom;
        };
        const isInteractiveTarget = (target) => target instanceof Element
          && target.closest("button, a, input, textarea, select, [contenteditable='true'], [role='button'], [role='link']") !== null;
        const settleAfterReaction = () => {
          reactionTimer.current = null;
          const hovered = hoverRef.current;
          setState(hovered ? "hovering" : "idle");
          setPeeking(hovered);
        };
        const playReaction = (nextState) => {
          cancelAutomaticPeek();
          if (reactionTimer.current !== null) window.clearTimeout(reactionTimer.current);
          setState(nextState);
          setPeeking(true);
          const animation = STATES[nextState] || STATES.idle;
          reactionTimer.current = window.setTimeout(
            settleAfterReaction,
            animation.frames * animation.interval
          );
        };
        const updateHover = (inside) => {
          if (hoverRef.current === inside) return;
          hoverRef.current = inside;
          if (dragPointRef.current !== null || reactionTimer.current !== null) return;
          cancelAutomaticPeek();
          setState(inside ? "hovering" : "idle");
          setPeeking(inside);
        };
        const onPointerDown = (event) => {
          if (!current.visible || event.button !== 0) return;
          pressRef.current = null;
          const inside = isInsidePet(event);
          updateHover(inside);
          if (!inside) return;
          pressRef.current = {
            x: event.clientX,
            y: event.clientY,
            blocked: isInteractiveTarget(event.target) && !event.altKey
          };
        };
        const onPointerMove = (event) => {
          if (dragPointRef.current !== null) {
            const point = { x: event.clientX, y: event.clientY };
            dragPointRef.current = point;
            setDragPoint(point);
            consume(event);
            return;
          }
          updateHover(isInsidePet(event));
          const press = pressRef.current;
          if (press === null || press.blocked) return;
          const distance = Math.hypot(event.clientX - press.x, event.clientY - press.y);
          if (distance < 6) return;
          cancelAutomaticPeek();
          if (reactionTimer.current !== null) {
            window.clearTimeout(reactionTimer.current);
            reactionTimer.current = null;
          }
          const point = { x: event.clientX, y: event.clientY };
          pressRef.current = null;
          dragPointRef.current = point;
          setDragPoint(point);
          setState("dragging");
          setPeeking(true);
          consume(event);
        };
        const finishDrag = (event) => {
          pressRef.current = null;
          if (dragPointRef.current === null) return;
          const dock = nearestDock(
            event.clientX,
            event.clientY,
            window.innerWidth,
            window.innerHeight
          );
          dragPointRef.current = null;
          setDragPoint(null);
          suppressClickUntil.current = Date.now() + 400;
          emitPreferences({ ...current, ...dock }, true);
          playReaction("waving");
          consume(event);
        };
        const cancelDrag = () => {
          pressRef.current = null;
          hoverRef.current = false;
          if (dragPointRef.current === null) {
            if (reactionTimer.current === null) {
              setState("idle");
              setPeeking(false);
            }
            return;
          }
          dragPointRef.current = null;
          setDragPoint(null);
          setState("idle");
          setPeeking(false);
        };
        const onClick = (event) => {
          if (Date.now() < suppressClickUntil.current) {
            suppressClickUntil.current = 0;
            consume(event);
            return;
          }
          if (!current.visible || !isInsidePet(event)) return;
          playReaction("clicked");
        };
        document.addEventListener("pointerdown", onPointerDown, true);
        document.addEventListener("pointermove", onPointerMove, true);
        document.addEventListener("pointerup", finishDrag, true);
        document.addEventListener("pointercancel", cancelDrag, true);
        document.addEventListener("click", onClick, true);
        window.addEventListener("blur", cancelDrag);
        return () => {
          document.removeEventListener("pointerdown", onPointerDown, true);
          document.removeEventListener("pointermove", onPointerMove, true);
          document.removeEventListener("pointerup", finishDrag, true);
          document.removeEventListener("pointercancel", cancelDrag, true);
          document.removeEventListener("click", onClick, true);
          window.removeEventListener("blur", cancelDrag);
        };
      }, [current]);

      if (!current.visible) return null;

      const positionStyle = dragPoint === null
        ? current.edge === "bottom"
          ? { left: `${current.offset * 100}%`, bottom: "0px" }
          : { [current.edge]: "0px", top: `${current.offset * 100}%` }
        : { left: `${dragPoint.x}px`, top: `${dragPoint.y}px` };
      const displayState = commandState ?? state;

      return React.createElement(
        "div",
        {
          ref: overlayRef,
          className: "harnessdock-pet-overlay",
          role: "img",
          "aria-label": `${PETS[current.petId].name} 桌面宠物；可悬停、点击和拖动贴边`,
          "data-edge": current.edge,
          "data-peeking": peeking || commandState !== null ? "true" : "false",
          "data-state": displayState,
          "data-command-state": commandState ?? undefined,
          "data-dragging": dragPoint === null ? undefined : "true",
          style: positionStyle
        },
        React.createElement(PetSprite, { petId: current.petId, state: displayState })
      );
    }

    function PetChoice({ pet, selected, onSelect }) {
      return React.createElement(
        "button",
        {
          type: "button",
          className: "harnessdock-pet-choice",
          role: "radio",
          "aria-checked": selected ? "true" : "false",
          "data-selected": selected ? "true" : undefined,
          onClick: onSelect
        },
        React.createElement(PetSprite, { petId: pet.id, compact: true }),
        React.createElement(
          "span",
          { className: "harnessdock-pet-choice-copy" },
          React.createElement("strong", null, pet.name),
          React.createElement("small", null, pet.description)
        ),
        React.createElement(
          "span",
          { className: "harnessdock-pet-check", "aria-hidden": "true" },
          selected ? "✓" : ""
        )
      );
    }

    function PetSettingsTab() {
      const current = usePreferences();
      const selectPet = (petId) => emitPreferences({ ...current, petId }, true);
      const setVisible = (event) => emitPreferences({ ...current, visible: event.currentTarget.checked }, true);
      const selectEdge = (edge) => emitPreferences({ ...current, edge }, true);

      return React.createElement(
        "section",
        { className: "harnessdock-pet-settings", "aria-labelledby": "harnessdock-pet-heading" },
        React.createElement(
          "div",
          { className: "harnessdock-pet-heading" },
          React.createElement("div", null,
            React.createElement("h3", { id: "harnessdock-pet-heading" }, "桌面宠物"),
            React.createElement("p", null, "选择动画伙伴，并让它贴在应用边缘探头。")
          ),
          React.createElement(
            "label",
            { className: "harnessdock-pet-toggle" },
            React.createElement("input", {
              type: "checkbox",
              checked: current.visible,
              onChange: setVisible
            }),
            React.createElement("span", null, "显示宠物")
          )
        ),
        React.createElement(
          "div",
          { className: "harnessdock-pet-grid", role: "radiogroup", "aria-label": "选择桌面宠物" },
          Object.values(PETS).map((pet) => React.createElement(PetChoice, {
            key: pet.id,
            pet,
            selected: current.petId === pet.id,
            onSelect: () => selectPet(pet.id)
          }))
        ),
        React.createElement(
          "div",
          { className: "harnessdock-pet-dock" },
          React.createElement("strong", null, "停靠边缘"),
          React.createElement(
            "div",
            { className: "harnessdock-pet-dock-options", role: "radiogroup", "aria-label": "选择停靠边缘" },
            DOCK_EDGES.map((edge) => React.createElement(
              "button",
              {
                key: edge,
                type: "button",
                role: "radio",
                "aria-checked": current.edge === edge ? "true" : "false",
                "data-selected": current.edge === edge ? "true" : undefined,
                onClick: () => selectEdge(edge)
              },
              DOCK_LABELS[edge]
            ))
          )
        ),
        React.createElement(
          "p",
          { className: "harnessdock-pet-footnote" },
          "光标、点击和拖动会触发不同动作。可从非控件背景直接拖动；若宠物盖在按钮上，按住 ⌥ Option 可强制拖动。松手吸附最近边框并保存位置，普通点击仍会传给下方控件。"
        )
      );
    }

    const CSS = `
      .harnessdock-pet-overlay {
        position: fixed;
        z-index: 60;
        width: ${DISPLAY_WIDTH}px;
        height: ${DISPLAY_HEIGHT}px;
        pointer-events: none;
        border: 0;
        padding: 0;
        background: transparent;
        filter: drop-shadow(0 7px 8px rgb(0 0 0 / .24));
        user-select: none;
        will-change: transform;
        transition: transform .48s cubic-bezier(.2, .8, .2, 1);
      }
      .harnessdock-pet-overlay[data-edge="left"] { transform: translate(-62%, -50%); }
      .harnessdock-pet-overlay[data-edge="right"] { transform: translate(62%, -50%); }
      .harnessdock-pet-overlay[data-edge="bottom"] { transform: translate(-50%, 55%); }
      .harnessdock-pet-overlay[data-edge="left"] .harnessdock-pet-sprite {
        transform: rotate(22deg) scaleX(-1);
      }
      .harnessdock-pet-overlay[data-edge="right"] .harnessdock-pet-sprite { transform: rotate(-22deg); }
      .harnessdock-pet-overlay[data-edge="left"][data-peeking="true"] { transform: translate(-28%, -50%); }
      .harnessdock-pet-overlay[data-edge="right"][data-peeking="true"] { transform: translate(28%, -50%); }
      .harnessdock-pet-overlay[data-edge="bottom"][data-peeking="true"] { transform: translate(-50%, 22%); }
      .harnessdock-pet-overlay[data-edge="left"][data-peeking="true"] .harnessdock-pet-sprite {
        transform: rotate(6deg) scaleX(-1);
      }
      .harnessdock-pet-overlay[data-edge="right"][data-peeking="true"] .harnessdock-pet-sprite {
        transform: rotate(-6deg);
      }
      .harnessdock-pet-overlay[data-dragging="true"] {
        transform: translate(-50%, -50%);
        transition: none;
        filter: drop-shadow(0 9px 12px rgb(0 0 0 / .32));
      }
      .harnessdock-pet-overlay[data-edge="left"][data-dragging="true"] .harnessdock-pet-sprite {
        transform: scaleX(-1);
      }
      .harnessdock-pet-overlay[data-edge="right"][data-dragging="true"] .harnessdock-pet-sprite {
        transform: none;
      }
      .harnessdock-pet-sprite {
        display: block;
        flex: none;
        background-repeat: no-repeat;
        image-rendering: pixelated;
        transform-origin: 50% 100%;
        transition: transform .48s cubic-bezier(.2, .8, .2, 1);
        will-change: transform;
      }
      .harnessdock-pet-settings {
        box-sizing: border-box;
        width: 100%;
        max-width: 760px;
        color: var(--dsw-alias-label-primary, #f5f5f5);
        display: flex;
        flex-direction: column;
        gap: 18px;
      }
      .harnessdock-pet-heading {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 24px;
      }
      .harnessdock-pet-heading h3 { margin: 0 0 5px; font-size: 16px; }
      .harnessdock-pet-heading p, .harnessdock-pet-footnote {
        margin: 0;
        color: var(--dsw-alias-label-tertiary, #9ca3af);
        font-size: 13px;
        line-height: 20px;
      }
      .harnessdock-pet-toggle { display: inline-flex; align-items: center; gap: 8px; white-space: nowrap; font-size: 13px; }
      .harnessdock-pet-toggle input { accent-color: var(--dsw-alias-state-business-primary, #8b5cf6); }
      .harnessdock-pet-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
      .harnessdock-pet-choice {
        box-sizing: border-box;
        min-height: 116px;
        display: flex;
        align-items: center;
        gap: 12px;
        color: inherit;
        text-align: left;
        font: inherit;
        cursor: pointer;
        border: 1px solid var(--dsw-alias-border-l2, #4b5563);
        border-radius: 12px;
        padding: 10px 12px;
        background: var(--dsw-alias-bg-layer-3, #303034);
      }
      .harnessdock-pet-choice:hover { background: var(--dsw-alias-interactive-bg-hover, #3b3b40); }
      .harnessdock-pet-choice[data-selected="true"] {
        border-color: var(--dsw-alias-state-business-primary, #8b5cf6);
        box-shadow: 0 0 0 2px color-mix(in srgb, var(--dsw-alias-state-business-primary, #8b5cf6) 20%, transparent);
      }
      .harnessdock-pet-choice:focus-visible { outline: 2px solid var(--dsw-alias-state-business-primary, #8b5cf6); outline-offset: 2px; }
      .harnessdock-pet-choice-copy { min-width: 0; display: flex; flex: 1; flex-direction: column; gap: 4px; }
      .harnessdock-pet-choice-copy strong { font-size: 14px; }
      .harnessdock-pet-choice-copy small { color: var(--dsw-alias-label-tertiary, #9ca3af); font-size: 12px; }
      .harnessdock-pet-check {
        width: 22px;
        height: 22px;
        display: grid;
        place-items: center;
        color: white;
        border-radius: 999px;
        background: var(--dsw-alias-state-business-primary, #8b5cf6);
        opacity: 0;
      }
      .harnessdock-pet-choice[data-selected="true"] .harnessdock-pet-check { opacity: 1; }
      .harnessdock-pet-dock { display: flex; align-items: center; justify-content: space-between; gap: 18px; }
      .harnessdock-pet-dock > strong { font-size: 13px; }
      .harnessdock-pet-dock-options { display: inline-flex; gap: 8px; }
      .harnessdock-pet-dock-options button {
        min-width: 64px;
        color: inherit;
        font: inherit;
        font-size: 12px;
        cursor: pointer;
        border: 1px solid var(--dsw-alias-border-l2, #4b5563);
        border-radius: 8px;
        padding: 6px 10px;
        background: var(--dsw-alias-bg-layer-3, #303034);
      }
      .harnessdock-pet-dock-options button[data-selected="true"] {
        color: white;
        border-color: var(--dsw-alias-state-business-primary, #8b5cf6);
        background: var(--dsw-alias-state-business-primary, #8b5cf6);
      }
      .harnessdock-pet-dock-options button:focus-visible { outline: 2px solid var(--dsw-alias-state-business-primary, #8b5cf6); outline-offset: 2px; }
      @media (prefers-reduced-motion: reduce) {
        .harnessdock-pet-overlay, .harnessdock-pet-sprite { transition: none; }
      }
      @media (width <= 680px) {
        .harnessdock-pet-grid { grid-template-columns: minmax(0, 1fr); }
        .harnessdock-pet-heading { align-items: flex-start; flex-direction: column; gap: 10px; }
        .harnessdock-pet-dock { align-items: flex-start; flex-direction: column; }
      }
    `;

    const inject = ["sessions", "slots"];

    function apply(ctx) {
      ctx.effect(() => {
        const style = document.createElement("style");
        style.dataset.plugin = "@harnessdock/pet";
        style.dataset.pluginCss = "@harnessdock/pet/client.css";
        style.textContent = CSS;
        document.head.appendChild(style);
        return () => style.remove();
      }, "harnessdock-pet: styles");

      ctx.effect(() => {
        const onStorage = (event) => {
          if ([STORAGE_KEY, ...LEGACY_STORAGE_KEYS].includes(event.key)) {
            emitPreferences(readPreferences(), false);
          }
        };
        window.addEventListener("storage", onStorage);
        return () => window.removeEventListener("storage", onStorage);
      }, "harnessdock-pet: preference synchronization");

      function PetOverlayEntry() {
        return React.createElement(PetOverlay, { sessions: ctx.sessions });
      }

      ctx.slots.inject("shell.overlay", () => ctx.slots.register({
        name: "shell.overlay",
        id: "harnessdock-pet-overlay",
        order: 60
      }, PetOverlayEntry));

      ctx.slots.inject("settings.plugins.tab", () => ctx.slots.register({
        name: "settings.plugins.tab",
        id: "desktop-pet",
        order: 30,
        label: "桌面宠物"
      }, PetSettingsTab));
    }

    exports.apply = apply;
    exports.inject = inject;
    exports.__test = { commandSignal, nearestDock, normalizePreferences, readPreferences };
    return module.exports;
  }
});
