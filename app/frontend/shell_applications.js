const REFRESH_MS = 15_000;
const REQUEST_TIMEOUT_MS = 10_000;

export function watchApplications(container) {
  const list = container.querySelector("ul");
  let controller;
  let refreshTimer;
  let expiryTimer;
  let stopped = false;
  let expiresAt = 0;

  function clear() {
    clearTimeout(expiryTimer);
    expiresAt = 0;
    if (container.contains(document.activeElement)) {
      const trigger = container.closest("details")?.querySelector("summary") ??
        container.closest(".nav-menu")?.querySelector("button");
      trigger?.focus();
    }
    container.hidden = true;
    list.replaceChildren();
  }

  async function refresh() {
    const started = performance.now();
    controller = new AbortController();
    const timeout = setTimeout(() => {
      controller.abort();
      clear();
    }, REQUEST_TIMEOUT_MS);
    try {
      const response = await fetch(container.dataset.shellApplications, {
        cache: "no-store", credentials: "same-origin", redirect: "error", signal: controller.signal
      });
      if (!response.ok) throw new Error("Shell eligibility unavailable");

      const { applications, expires_in_ms: expiresIn } = await response.json();
      if (stopped || controller.signal.aborted) return;
      const remaining = Math.min(expiresIn, 60_000) - (performance.now() - started);
      if (!Array.isArray(applications) || !applications.length || !(remaining > 0)) {
        clear();
        return;
      }

      const links = applications.map(({ name, url }) => {
        const destination = new URL(url);
        if (destination.protocol !== "https:" || typeof name !== "string") throw new Error("Invalid destination");
        const item = document.createElement("li");
        const anchor = document.createElement("a");
        anchor.className = "dropdown-item";
        anchor.href = destination.href;
        anchor.textContent = name;
        item.append(anchor);
        return item;
      });
      const existing = Array.from(list.querySelectorAll("a"));
      if (existing.length !== links.length || existing.some((link, index) => {
        const next = links[index].firstChild;
        return link.href !== next.href || link.textContent !== next.textContent;
      })) list.replaceChildren(...links);
      expiresAt = performance.now() + remaining;
      container.hidden = false;
      clearTimeout(expiryTimer);
      expiryTimer = setTimeout(clear, remaining);
    } catch {
      clear();
    } finally {
      clearTimeout(timeout);
      if (!stopped) refreshTimer = setTimeout(refresh, REFRESH_MS);
    }
  }

  function stop() {
    stopped = true;
    controller?.abort();
    clearTimeout(refreshTimer);
    window.removeEventListener("pagehide", stop);
    container.removeEventListener("click", preventExpiredNavigation);
    clear();
  }

  function preventExpiredNavigation(event) {
    if (performance.now() >= expiresAt) {
      event.preventDefault();
      clear();
    }
  }

  window.addEventListener("pagehide", stop);
  container.addEventListener("click", preventExpiredNavigation);
  void refresh();
  return { destroy: stop };
}
