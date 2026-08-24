window.__ModuleLoader__.load({
  id: "@dsharness/pet",
  factory: (require) => {
    const module = { exports: {} };
    const exports = module.exports;
    Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });

    const React = require("react");
    const STORAGE_KEY = "dsharness.pet.preferences.v1";
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
      clicked: { row: 4, frames: 6, interval: 120 },
      hovering: { row: 5, frames: 6, interval: 220 },
      dragging: { row: 6, frames: 6, interval: 140 }
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
        const value = window.localStorage.getItem(STORAGE_KEY);
        return value === null ? DEFAULT_PREFERENCES : normalizePreferences(JSON.parse(value));
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
        className: "dshpet-sprite",
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

    function PetOverlay() {
      const current = usePreferences();
      const reducedMotion = useReducedMotion();
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
          }, 900);
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
        const playReaction = (nextState, duration) => {
          cancelAutomaticPeek();
          if (reactionTimer.current !== null) window.clearTimeout(reactionTimer.current);
          setState(nextState);
          setPeeking(true);
          reactionTimer.current = window.setTimeout(settleAfterReaction, duration);
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
          playReaction("waving", 900);
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
          playReaction("clicked", 900);
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

      return React.createElement(
        "div",
        {
          ref: overlayRef,
          className: "dshpet-overlay",
          role: "img",
          "aria-label": `${PETS[current.petId].name} 桌面宠物；可悬停、点击和拖动贴边`,
          "data-edge": current.edge,
          "data-peeking": peeking ? "true" : "false",
          "data-state": state,
          "data-dragging": dragPoint === null ? undefined : "true",
          style: positionStyle
        },
        React.createElement(PetSprite, { petId: current.petId, state })
      );
    }

    function PetChoice({ pet, selected, onSelect }) {
      return React.createElement(
        "button",
        {
          type: "button",
          className: "dshpet-choice",
          role: "radio",
          "aria-checked": selected ? "true" : "false",
          "data-selected": selected ? "true" : undefined,
          onClick: onSelect
        },
        React.createElement(PetSprite, { petId: pet.id, compact: true }),
        React.createElement(
          "span",
          { className: "dshpet-choice-copy" },
          React.createElement("strong", null, pet.name),
          React.createElement("small", null, pet.description)
        ),
        React.createElement(
          "span",
          { className: "dshpet-check", "aria-hidden": "true" },
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
        { className: "dshpet-settings", "aria-labelledby": "dshpet-heading" },
        React.createElement(
          "div",
          { className: "dshpet-heading" },
          React.createElement("div", null,
            React.createElement("h3", { id: "dshpet-heading" }, "桌面宠物"),
            React.createElement("p", null, "选择动画伙伴，并让它贴在应用边缘探头。")
          ),
          React.createElement(
            "label",
            { className: "dshpet-toggle" },
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
          { className: "dshpet-grid", role: "radiogroup", "aria-label": "选择桌面宠物" },
          Object.values(PETS).map((pet) => React.createElement(PetChoice, {
            key: pet.id,
            pet,
            selected: current.petId === pet.id,
            onSelect: () => selectPet(pet.id)
          }))
        ),
        React.createElement(
          "div",
          { className: "dshpet-dock" },
          React.createElement("strong", null, "停靠边缘"),
          React.createElement(
            "div",
            { className: "dshpet-dock-options", role: "radiogroup", "aria-label": "选择停靠边缘" },
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
          { className: "dshpet-footnote" },
          "光标、点击和拖动会触发不同动作。可从非控件背景直接拖动；若宠物盖在按钮上，按住 ⌥ Option 可强制拖动。松手吸附最近边框并保存位置，普通点击仍会传给下方控件。"
        )
      );
    }

    const CSS = `
      .dshpet-overlay {
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
      .dshpet-overlay[data-edge="left"] { transform: translate(-58%, -50%); }
      .dshpet-overlay[data-edge="right"] { transform: translate(58%, -50%); }
      .dshpet-overlay[data-edge="bottom"] { transform: translate(-50%, 48%); }
      .dshpet-overlay[data-edge="left"] .dshpet-sprite { transform: scaleX(-1); }
      .dshpet-overlay[data-edge="left"][data-peeking="true"] { transform: translate(-18%, -50%); }
      .dshpet-overlay[data-edge="right"][data-peeking="true"] { transform: translate(18%, -50%); }
      .dshpet-overlay[data-edge="bottom"][data-peeking="true"] { transform: translate(-50%, 16%); }
      .dshpet-overlay[data-dragging="true"] {
        transform: translate(-50%, -50%);
        transition: none;
        filter: drop-shadow(0 9px 12px rgb(0 0 0 / .32));
      }
      .dshpet-sprite {
        display: block;
        flex: none;
        background-repeat: no-repeat;
        image-rendering: pixelated;
      }
      .dshpet-settings {
        box-sizing: border-box;
        width: 100%;
        max-width: 760px;
        color: var(--dsw-alias-label-primary, #f5f5f5);
        display: flex;
        flex-direction: column;
        gap: 18px;
      }
      .dshpet-heading {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 24px;
      }
      .dshpet-heading h3 { margin: 0 0 5px; font-size: 16px; }
      .dshpet-heading p, .dshpet-footnote {
        margin: 0;
        color: var(--dsw-alias-label-tertiary, #9ca3af);
        font-size: 13px;
        line-height: 20px;
      }
      .dshpet-toggle { display: inline-flex; align-items: center; gap: 8px; white-space: nowrap; font-size: 13px; }
      .dshpet-toggle input { accent-color: var(--dsw-alias-state-business-primary, #8b5cf6); }
      .dshpet-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
      .dshpet-choice {
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
      .dshpet-choice:hover { background: var(--dsw-alias-interactive-bg-hover, #3b3b40); }
      .dshpet-choice[data-selected="true"] {
        border-color: var(--dsw-alias-state-business-primary, #8b5cf6);
        box-shadow: 0 0 0 2px color-mix(in srgb, var(--dsw-alias-state-business-primary, #8b5cf6) 20%, transparent);
      }
      .dshpet-choice:focus-visible { outline: 2px solid var(--dsw-alias-state-business-primary, #8b5cf6); outline-offset: 2px; }
      .dshpet-choice-copy { min-width: 0; display: flex; flex: 1; flex-direction: column; gap: 4px; }
      .dshpet-choice-copy strong { font-size: 14px; }
      .dshpet-choice-copy small { color: var(--dsw-alias-label-tertiary, #9ca3af); font-size: 12px; }
      .dshpet-check {
        width: 22px;
        height: 22px;
        display: grid;
        place-items: center;
        color: white;
        border-radius: 999px;
        background: var(--dsw-alias-state-business-primary, #8b5cf6);
        opacity: 0;
      }
      .dshpet-choice[data-selected="true"] .dshpet-check { opacity: 1; }
      .dshpet-dock { display: flex; align-items: center; justify-content: space-between; gap: 18px; }
      .dshpet-dock > strong { font-size: 13px; }
      .dshpet-dock-options { display: inline-flex; gap: 8px; }
      .dshpet-dock-options button {
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
      .dshpet-dock-options button[data-selected="true"] {
        color: white;
        border-color: var(--dsw-alias-state-business-primary, #8b5cf6);
        background: var(--dsw-alias-state-business-primary, #8b5cf6);
      }
      .dshpet-dock-options button:focus-visible { outline: 2px solid var(--dsw-alias-state-business-primary, #8b5cf6); outline-offset: 2px; }
      @media (prefers-reduced-motion: reduce) {
        .dshpet-overlay { transition: none; }
      }
      @media (width <= 680px) {
        .dshpet-grid { grid-template-columns: minmax(0, 1fr); }
        .dshpet-heading { align-items: flex-start; flex-direction: column; gap: 10px; }
        .dshpet-dock { align-items: flex-start; flex-direction: column; }
      }
    `;

    const inject = ["slots"];

    function apply(ctx) {
      ctx.effect(() => {
        const style = document.createElement("style");
        style.dataset.plugin = "@dsharness/pet";
        style.dataset.pluginCss = "@dsharness/pet/client.css";
        style.textContent = CSS;
        document.head.appendChild(style);
        return () => style.remove();
      }, "dsharness-pet: styles");

      ctx.effect(() => {
        const onStorage = (event) => {
          if (event.key === STORAGE_KEY) emitPreferences(readPreferences(), false);
        };
        window.addEventListener("storage", onStorage);
        return () => window.removeEventListener("storage", onStorage);
      }, "dsharness-pet: preference synchronization");

      ctx.slots.inject("shell.overlay", () => ctx.slots.register({
        name: "shell.overlay",
        id: "dsharness-pet-overlay",
        order: 60
      }, PetOverlay));

      ctx.slots.inject("settings.plugins.tab", () => ctx.slots.register({
        name: "settings.plugins.tab",
        id: "desktop-pet",
        order: 30,
        label: "桌面宠物"
      }, PetSettingsTab));
    }

    exports.apply = apply;
    exports.inject = inject;
    exports.__test = { nearestDock, normalizePreferences };
    return module.exports;
  }
});
