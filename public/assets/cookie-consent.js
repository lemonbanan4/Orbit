/**
 * Orbit cookie consent gate.
 *
 * Non-essential scripts (analytics, ads, etc.) must be registered via
 * OrbitConsent.onConsent() instead of being dropped directly into the page.
 * They will only actually run once the visitor has opted in, and the
 * decision is re-checked on every page load — nothing fires before consent.
 *
 * Usage from another script/page:
 *   OrbitConsent.onConsent('analytics', function () {
 *     // inject your analytics <script> tag / call ga(), gtag(), etc. here
 *   });
 */
(function () {
  "use strict";

  var STORAGE_KEY = "orbit_cookie_consent";
  var CONSENT_VERSION = 1; // bump this if the categories/policy change materially

  // ---- Fill this in once you have a GA4 property. Left blank, this is a
  // safe no-op: the consent gate still works, it just has nothing to load. ----
  var GA_MEASUREMENT_ID = ""; // e.g. "G-XXXXXXXXXX"

  function readConsent() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      var parsed = JSON.parse(raw);
      if (parsed.version !== CONSENT_VERSION) return null;
      return parsed;
    } catch (e) {
      return null;
    }
  }

  function writeConsent(analytics) {
    var record = {
      version: CONSENT_VERSION,
      analytics: analytics,
      timestamp: new Date().toISOString(),
    };
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(record));
    } catch (e) {
      /* localStorage unavailable (private mode, etc.) — consent just won't persist */
    }
    return record;
  }

  var pendingCallbacks = [];

  function runIfConsented(record) {
    if (record && record.analytics) {
      pendingCallbacks.forEach(function (fn) {
        try {
          fn();
        } catch (e) {
          console.error("OrbitConsent callback failed:", e);
        }
      });
      pendingCallbacks = [];
    }
  }

  // Public API
  window.OrbitConsent = {
    // category is currently always 'analytics' — kept as a param so a future
    // ad-tracking category can reuse this without an API change.
    onConsent: function (category, fn) {
      if (category !== "analytics") return;
      var existing = readConsent();
      if (existing && existing.analytics) {
        fn();
      } else {
        pendingCallbacks.push(fn);
      }
    },
    getConsent: readConsent,
    openPreferences: function () {
      showBanner(true);
    },
  };

  function loadDefaultAnalytics() {
    if (!GA_MEASUREMENT_ID) return; // not configured yet — nothing to do
    var s1 = document.createElement("script");
    s1.async = true;
    s1.src = "https://www.googletagmanager.com/gtag/js?id=" + GA_MEASUREMENT_ID;
    document.head.appendChild(s1);

    window.dataLayer = window.dataLayer || [];
    function gtag() {
      window.dataLayer.push(arguments);
    }
    window.gtag = gtag;
    gtag("js", new Date());
    gtag("config", GA_MEASUREMENT_ID, { anonymize_ip: true });
  }

  window.OrbitConsent.onConsent("analytics", loadDefaultAnalytics);

  // ---- Banner UI ----
  var bannerEl = null;

  function injectStyles() {
    if (document.getElementById("orbit-consent-styles")) return;
    var style = document.createElement("style");
    style.id = "orbit-consent-styles";
    style.textContent =
      "#orbit-consent-banner{position:fixed;left:0;right:0;bottom:0;z-index:9999;" +
      "display:flex;justify-content:center;padding:16px;" +
      "font-family:'Plus Jakarta Sans',sans-serif;" +
      "animation:orbitConsentIn .4s ease-out;}" +
      "@keyframes orbitConsentIn{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:translateY(0)}}" +
      "#orbit-consent-card{width:100%;max-width:720px;background:rgba(10,10,16,0.85);" +
      "backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);" +
      "border:1px solid rgba(255,255,255,0.1);border-radius:20px;padding:20px 24px;" +
      "box-shadow:0 20px 50px rgba(0,0,0,0.5);color:#fff;}" +
      "#orbit-consent-card p{margin:0 0 14px 0;font-size:0.85rem;line-height:1.5;color:rgba(255,255,255,0.75);}" +
      "#orbit-consent-card a{color:#00E5FF;text-decoration:underline;}" +
      "#orbit-consent-actions{display:flex;gap:10px;flex-wrap:wrap;}" +
      "#orbit-consent-actions button{flex:1;min-width:120px;padding:10px 16px;border-radius:12px;" +
      "font-size:0.85rem;font-weight:600;cursor:pointer;border:1px solid transparent;" +
      "font-family:inherit;}" +
      "#orbit-consent-accept{background:#00E5FF;color:#020205;}" +
      "#orbit-consent-reject{background:transparent;color:#fff;border-color:rgba(255,255,255,0.25);}" +
      "@media (min-width:480px){#orbit-consent-actions button{flex:none;}}";
    document.head.appendChild(style);
  }

  function showBanner() {
    if (bannerEl) return;
    injectStyles();
    bannerEl = document.createElement("div");
    bannerEl.id = "orbit-consent-banner";
    bannerEl.innerHTML =
      '<div id="orbit-consent-card" role="dialog" aria-label="Cookie preferences">' +
      "<p>We use strictly necessary cookies to run this site, and — only if you " +
      "opt in — analytics cookies to understand how visitors use it. See our " +
      '<a href="/privacy.html#cookies">Cookie Policy</a> for details.</p>' +
      '<div id="orbit-consent-actions">' +
      '<button id="orbit-consent-reject" type="button">Reject non-essential</button>' +
      '<button id="orbit-consent-accept" type="button">Accept all</button>' +
      "</div></div>";
    document.body.appendChild(bannerEl);

    document.getElementById("orbit-consent-accept").addEventListener("click", function () {
      var record = writeConsent(true);
      runIfConsented(record);
      hideBanner();
    });
    document.getElementById("orbit-consent-reject").addEventListener("click", function () {
      writeConsent(false);
      hideBanner();
    });
  }

  function hideBanner() {
    if (bannerEl && bannerEl.parentNode) {
      bannerEl.parentNode.removeChild(bannerEl);
    }
    bannerEl = null;
  }

  function init() {
    var existing = readConsent();
    if (existing) {
      runIfConsented(existing);
      return;
    }
    showBanner();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
