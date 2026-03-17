(function() {
  if (typeof PerformanceObserver === "undefined" ||
      typeof PerformanceEventTiming === "undefined" ||
      !("interactionId" in PerformanceEventTiming.prototype)) {
    return;
  }

  const interactions = {};
  let worst = 0;

  function updateInp(entry) {
    const id = entry.interactionId;
    if (!id) return;
    const duration = entry.duration;
    const prev = interactions[id] || 0;
    const max = Math.max(prev, duration);
    interactions[id] = max;
    if (max > worst) {
      worst = max;
      if (!window.upright) window.upright = {};
      window.upright.inp = Math.round(worst);
    }
  }

  try {
    const observer = new PerformanceObserver((list) => {
      list.getEntries().forEach(updateInp);
    });
    observer.observe({ type: "event", buffered: true, durationThreshold: 0 });
    observer.observe({ type: "first-input", buffered: true });
  } catch (e) {}
})();
