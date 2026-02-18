(() => {
  const metrics = {};

  const [navigation] = performance.getEntriesByType("navigation");
  if (navigation) {
    metrics.ttfb = Math.round(navigation.responseStart);
    metrics.dns = Math.round(navigation.domainLookupEnd - navigation.domainLookupStart);
    metrics.tcp = Math.round(navigation.connectEnd - navigation.connectStart);
    metrics.request = Math.round(navigation.responseStart - navigation.requestStart);
    metrics.response = Math.round(navigation.responseEnd - navigation.responseStart);
    metrics.domInteractive = Math.round(navigation.domInteractive);
    metrics.domContentLoaded = Math.round(navigation.domContentLoadedEventEnd);
    metrics.domComplete = Math.round(navigation.domComplete);
    metrics.loadComplete = Math.round(navigation.loadEventEnd);
    metrics.transferSize = navigation.transferSize;
    metrics.encodedBodySize = navigation.encodedBodySize;
    metrics.decodedBodySize = navigation.decodedBodySize;
  }

  const [fcp] = performance.getEntriesByType("paint").filter(e => e.name === "first-contentful-paint");
  if (fcp) {
    metrics.fcp = Math.round(fcp.startTime);
  }

  const lcpEntries = performance.getEntriesByType("largest-contentful-paint");
  if (lcpEntries.length > 0) {
    metrics.lcp = Math.round(lcpEntries[lcpEntries.length - 1].startTime);
  }

  const inp = window.upright?.inp;
  if (inp != null) {
    metrics.inp = Math.round(inp);
  }

  /** @deprecated Use INP for responsiveness. */
  const [fid] = performance.getEntriesByType("first-input");
  if (fid) {
    metrics.fid = Math.round(fid.processingStart - fid.startTime);
  }

  return metrics;
})();
