public enum DeepSeekChatEnterBehavior {
    public static let userScript = #"""
    (() => {
      if (window.__dshEnterIMEConfirmThenSend) return;
      window.__dshEnterIMEConfirmThenSend = true;

      const activeCompositionTargets = new WeakSet();
      const recentlyEndedCompositionTargets = new WeakSet();
      const compositionEnterTargets = new WeakSet();

      const editableForEvent = event => {
        const path = typeof event.composedPath === 'function'
          ? event.composedPath()
          : [event.target];

        for (const node of path) {
          if (!(node instanceof Element)) continue;
          if (node instanceof HTMLInputElement) {
            const textTypes = new Set([
              'text', 'search', 'email', 'url', 'tel', 'password', 'number'
            ]);
            if (!node.disabled && !node.readOnly && textTypes.has(node.type)) {
              return { element: node, multiline: false };
            }
            return null;
          }
          if (node instanceof HTMLTextAreaElement) {
            return node.disabled || node.readOnly
              ? null
              : { element: node, multiline: true };
          }
          if (node.isContentEditable) {
            const root = node.closest('[contenteditable]') || node;
            return root.getAttribute('aria-disabled') === 'true'
              ? null
              : { element: root, multiline: true };
          }
          if (node.getAttribute('role') === 'textbox') {
            return node.getAttribute('aria-disabled') === 'true'
              ? null
              : {
                  element: node,
                  multiline: node.getAttribute('aria-multiline') === 'true'
                };
          }
        }
        return null;
      };

      const insertTextareaLineBreak = textarea => {
        const start = textarea.selectionStart ?? textarea.value.length;
        const end = textarea.selectionEnd ?? start;
        textarea.setRangeText('\n', start, end, 'end');
        textarea.dispatchEvent(new InputEvent('input', {
          bubbles: true,
          inputType: 'insertLineBreak',
          data: '\n'
        }));
      };

      const insertEditableLineBreak = editor => {
        if (document.execCommand('insertLineBreak', false, null)) return;

        const selection = window.getSelection();
        if (!selection || selection.rangeCount === 0) {
          editor.append(document.createElement('br'));
        } else {
          const range = selection.getRangeAt(0);
          range.deleteContents();
          const lineBreak = document.createElement('br');
          range.insertNode(lineBreak);
          range.setStartAfter(lineBreak);
          range.collapse(true);
          selection.removeAllRanges();
          selection.addRange(range);
        }
        editor.dispatchEvent(new InputEvent('input', {
          bubbles: true,
          inputType: 'insertLineBreak',
          data: null
        }));
      };

      const editableEnter = event => {
        if (event.key !== 'Enter') return null;
        return editableForEvent(event);
      };

      const isComposing = (event, editable) =>
        event.isComposing
        || event.keyCode === 229
        || activeCompositionTargets.has(editable.element)
        || recentlyEndedCompositionTargets.has(editable.element);

      const isPlainEnter = event =>
        !event.shiftKey && !event.metaKey && !event.altKey && !event.ctrlKey;

      const shouldPageHandle = (event, editable) =>
        !isComposing(event, editable)
        && editable.multiline
        && isPlainEnter(event);

      const stopPageEnter = (event, preventDefault = true) => {
        if (preventDefault) event.preventDefault();
        event.stopPropagation();
        event.stopImmediatePropagation();
      };

      window.addEventListener('compositionstart', event => {
        const editable = editableForEvent(event);
        if (editable) activeCompositionTargets.add(editable.element);
      }, true);

      const trackCompositionInput = event => {
        const editable = editableForEvent(event);
        if (!editable) return;

        if (event.isComposing || event.inputType === 'insertCompositionText') {
          activeCompositionTargets.add(editable.element);
        } else if (event.inputType === 'insertFromComposition') {
          activeCompositionTargets.delete(editable.element);
          recentlyEndedCompositionTargets.add(editable.element);
        }
      };

      window.addEventListener('beforeinput', trackCompositionInput, true);
      window.addEventListener('input', trackCompositionInput, true);

      window.addEventListener('compositionend', event => {
        const editable = editableForEvent(event);
        if (!editable) return;
        activeCompositionTargets.delete(editable.element);
        recentlyEndedCompositionTargets.add(editable.element);
        window.setTimeout(() => {
          recentlyEndedCompositionTargets.delete(editable.element);
        }, 500);
      }, true);

      window.addEventListener('keydown', event => {
        const editable = editableEnter(event);
        if (!editable) return;

        if (isComposing(event, editable)) {
          const stillComposing = event.isComposing
            || event.keyCode === 229
            || activeCompositionTargets.has(editable.element);
          compositionEnterTargets.add(editable.element);
          activeCompositionTargets.delete(editable.element);
          recentlyEndedCompositionTargets.delete(editable.element);
          stopPageEnter(event, !stillComposing);
          return;
        }

        compositionEnterTargets.delete(editable.element);
        if (shouldPageHandle(event, editable)) return;

        stopPageEnter(event);
        if (editable.multiline && !isPlainEnter(event)) {
          if (editable.element instanceof HTMLTextAreaElement) {
            insertTextareaLineBreak(editable.element);
          } else {
            insertEditableLineBreak(editable.element);
          }
        }
      }, true);

      const finishEnter = event => {
        const editable = editableEnter(event);
        if (!editable) return;

        if (isComposing(event, editable) || compositionEnterTargets.has(editable.element)) {
          stopPageEnter(event, isComposing(event, editable) === false);
          if (event.type === 'keyup') {
            activeCompositionTargets.delete(editable.element);
            recentlyEndedCompositionTargets.delete(editable.element);
            compositionEnterTargets.delete(editable.element);
          }
          return;
        }

        if (shouldPageHandle(event, editable)) return;
        stopPageEnter(event);
      };

      window.addEventListener('keypress', finishEnter, true);
      window.addEventListener('keyup', finishEnter, true);
    })();
    """#
}
