public enum DeepSeekChatCommandBehavior {
    public static let messageHandlerName = "dshPetCommand"

    /// Observes only semantic control attributes and error roles. The bridge payload
    /// is restricted to ``PetCommandActivity`` raw values and never includes page text.
    public static let userScript = #"""
    (() => {
      if (window.__harnessDockPetCommandHook) return;
      window.__harnessDockPetCommandHook = true;

      const handler = window.webkit?.messageHandlers?.dshPetCommand;
      if (!handler || typeof handler.postMessage !== 'function') return;

      const allowedStates = new Set(['idle', 'running', 'succeeded', 'failed']);
      const stopPattern = /^(停止|stop)$|停止(?:生成|回答|响应)|stop[\s_-]?(?:generating|generation|response|button)/i;
      const controlSelector = [
        'button[aria-label]',
        'button[title]',
        '[role="button"][aria-label]',
        '[role="button"][title]',
        '[data-testid]'
      ].join(',');
      const errorSelector = [
        '[role="alert"]',
        '[aria-live="assertive"]',
        '[data-testid*="error" i]',
        '[data-status="error"]'
      ].join(',');

      let lastPosted = null;
      let wasRunning = false;
      let failedDuringRun = false;
      const seenErrorNodes = new WeakSet();

      const isVisible = element => {
        if (!(element instanceof Element) || !element.isConnected) return false;
        if (element.hidden || element.getAttribute('aria-hidden') === 'true') return false;
        const style = window.getComputedStyle(element);
        if (style.display === 'none' || style.visibility === 'hidden') return false;
        const rect = element.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      };

      const semanticLabel = element => [
        element.getAttribute('aria-label'),
        element.getAttribute('title'),
        element.getAttribute('data-testid')
      ].filter(value => typeof value === 'string' && value.length > 0).join(' ').trim();

      const hasRunningControl = () => Array.from(
        document.querySelectorAll(controlSelector)
      ).some(element => isVisible(element) && stopPattern.test(semanticLabel(element)));

      const visibleErrorNodes = () => Array.from(
        document.querySelectorAll(errorSelector)
      ).filter(isVisible);

      const post = state => {
        if (!allowedStates.has(state) || state === lastPosted) return;
        lastPosted = state;
        handler.postMessage(state);
      };

      for (const node of visibleErrorNodes()) seenErrorNodes.add(node);

      const evaluate = () => {
        for (const node of visibleErrorNodes()) {
          if (seenErrorNodes.has(node)) continue;
          seenErrorNodes.add(node);
          if (wasRunning) failedDuringRun = true;
        }

        const running = hasRunningControl();
        if (running) {
          if (!wasRunning) {
            failedDuringRun = false;
            post('running');
          }
          wasRunning = true;
          return;
        }

        if (wasRunning) {
          wasRunning = false;
          post(failedDuringRun ? 'failed' : 'succeeded');
          failedDuringRun = false;
          return;
        }

        if (lastPosted === null) post('idle');
      };

      const observer = new MutationObserver(evaluate);
      observer.observe(document.documentElement, {
        subtree: true,
        childList: true,
        attributes: true,
        attributeFilter: [
          'aria-label', 'aria-hidden', 'aria-live', 'title',
          'data-testid', 'data-status', 'hidden', 'style'
        ]
      });
      window.addEventListener('pagehide', () => observer.disconnect(), { once: true });
      evaluate();
    })();
    """#
}
