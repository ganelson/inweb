/**
 * seek_locate_display.js — v2.0
 * Zero-dependency full-text search for local HTML pages.
 * Indexes sections by heading + body text; renders a search UI
 * with results grouped by page and click-to-navigate to anchors.
 *
 * Styles live in the companion stylesheet sld.css (they used
 * to be injected from here). Link it in the page <head>, after Colours.css:
 *   <link rel="stylesheet" href="Colours.css">
 *   <link rel="stylesheet" href="sld.css">
 *
 * Usage:
 *   const sld = new SeekLocateDisplay({
 *     container: '#my-search-box',
 *     pages: [...],        // your page definitions (see README below)
 *     onNavigate: (url) => { window.location.href = url; }  // optional
 *   });
 *
 * Page definition:
 *   {
 *     url: 'guide/intro.html',
 *     title: 'Introduction',
 *     sections: [
 *       // Use \n to separate distinct paragraphs/blocks within a section's
 *       // text. Matched paragraphs are shown individually in results,
 *       // joined with " | ".
 *       { id: 'overview', heading: 'Overview', text: 'First paragraph…\nSecond paragraph…' },
 *       { id: 'setup',    heading: 'Setup',    text: 'Installation steps…' }
 *     ]
 *   }
 *
 * Query syntax:
 *   chocolate                    → matches "chocolate" anywhere, including
 *                                   inside longer words (e.g. "chocolatey")
 *   "chocolate"                   → whole-word match only — won't match
 *                                   inside "chocolatey" or "hotchocolate"
 *   "dark chocolate"              → exact phrase, whole-word at both ends
 *   milk chocolate                → AND — both terms required
 *   "milk chocolate" OR "dark"    → OR — either side may match
 *   cake OR cookie "with nuts"    → OR of two AND-groups
 *   The word OR (uppercase) is the only operator; lowercase "or" is
 *   treated as an ordinary search word so prose queries still work.
 *
 * MIT License — free to use, modify, and redistribute.
 */

;(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();          // CommonJS / Node
  } else if (typeof define === 'function' && define.amd) {
    define(factory);                     // AMD / RequireJS
  } else {
    root.SeekLocateDisplay = factory();         // Browser global
  }
}(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* ─── Defaults ─────────────────────────────────────────────── */

  const DEFAULTS = {
    container: '#seeklocatedisplay',
    pages: [],
    placeholder: 'Search…',
    minChars: 2,
    maxResults: 50,
    excerptLength: 140,
    headingWeight: 4,      // multiplier vs body text
    onNavigate: null,      // fn(url) — default: window.location.href
    noResultsText: 'No results found.',
    debounceMs: 120,
    persist: true,         // remember query (URL) + scroll position (sessionStorage) across navigation
    persistParam: 'q',     // URL query-string param name used to store the search text
    highlightOnNavigate: true, // append the search query to result links so destination pages can highlight matches
    highlightParam: 'sld-hl',   // URL query-string param name carrying the query for highlighting on the destination page
  };

  /* ─── SVG icons (inline, no font dependency) ────────────────── */

  const ICON_SEARCH = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" class="sld-icon" aria-hidden="true"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>`;
  const ICON_CLOSE  = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" class="sld-icon" style="width:14px;height:14px" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`;
  const ICON_FILE   = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" class="sld-icon" style="stroke:#aaa" aria-hidden="true"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>`;
  const ICON_HASH   = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" class="sld-hit-icon" aria-hidden="true"><line x1="4" y1="9" x2="20" y2="9"/><line x1="4" y1="15" x2="20" y2="15"/><line x1="10" y1="3" x2="8" y2="21"/><line x1="16" y1="3" x2="14" y2="21"/></svg>`;

  /* ─── Helpers ───────────────────────────────────────────────── */

  /**
   * Escape for BOTH element-content and attribute-value contexts.
   * Quote escaping matters: renderResults interpolates escaped strings
   * into data-dest="..." and aria-label="..." attributes, and a heading
   * or URL containing `"` would otherwise break out of the attribute —
   * a robustness bug with author data, an XSS vector the moment page /
   * section content is ever derived from user-generated input.
   */
  function escapeHtml(s) {
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
            .replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  }

  /** Apply <mark> tags around a sorted list of {start,end} spans in escaped HTML */
  function applySpans(text, spans) {
    const escaped = escapeHtml(text);
    if (!spans || !spans.length) return escaped;
    const sorted = [...spans].sort((a, b) => a.start - b.start);
    const merged = [{ ...sorted[0] }];
    for (let i = 1; i < sorted.length; i++) {
      const last = merged[merged.length - 1];
      if (sorted[i].start <= last.end) {
        last.end = Math.max(last.end, sorted[i].end);
      } else {
        merged.push({ ...sorted[i] });
      }
    }
    let out = '';
    let cursor = 0;
    for (const sp of merged) {
      out += escapeHtml(text.slice(cursor, sp.start));
      out += '<mark>' + escapeHtml(text.slice(sp.start, sp.end)) + '</mark>';
      cursor = sp.end;
    }
    out += escapeHtml(text.slice(cursor));
    return out;
  }

  function debounce(fn, ms) {
    let timer;
    const debounced = function (...args) {
      clearTimeout(timer);
      timer = setTimeout(() => fn.apply(this, args), ms);
    };
    // Allow callers to drop a pending invocation — used to stop a
    // debounced URL write from firing after the query was cleared or
    // after navigation already wrote the final value synchronously.
    debounced.cancel = () => clearTimeout(timer);
    return debounced;
  }

  /* ─── Persistence: query in URL, scroll position in sessionStorage ───
   *
   * Storage key is scoped per-container so multiple SeekLocateDisplay instances
   * on one page (or one site) don't clobber each other's state.
   */

  function storageKey(containerSelector) {
    return 'seeklocatedisplay:scroll:' + containerSelector;
  }

  /* ── Per-instance isolation ──────────────────────────────────────
   *
   * Two things must be unique per instance or instances clobber each
   * other's state:
   *
   *   1. The sessionStorage scroll key. Selector-string containers are
   *      naturally distinct; element containers previously all fell
   *      back to one shared '#seeklocatedisplay' key. Element containers
   *      now use their id when they have one, else a construction-order
   *      index (stable across loads as long as instances are created in
   *      a deterministic order — give the element an id if it isn't).
   *
   *   2. The URL query param (persistParam). Two instances configured
   *      with the same param (e.g. both on the default 'q') would write
   *      over each other and both restore the same text on Back. The
   *      first instance to claim a param keeps it; later collisions get
   *      a numeric suffix ('q' → 'q2', 'q3', …) and a console warning
   *      suggesting an explicit persistParam. Suffixes are assigned in
   *      construction order, so like the scroll key this is stable for
   *      deterministic init code — set distinct persistParams explicitly
   *      if your instances are created in varying order.
   */
  let elementInstanceCounter = 0;
  const claimedPersistParams = new Set();

  function containerKeyFor(container) {
    if (typeof container === 'string') return container;
    if (container && container.id) return '#' + container.id;
    return ':element-' + (++elementInstanceCounter);
  }

  function claimPersistParam(wanted) {
    let param = wanted;
    if (claimedPersistParams.has(param)) {
      let n = 2;
      while (claimedPersistParams.has(wanted + n)) n++;
      param = wanted + n;
      if (typeof console !== 'undefined' && console.warn) {
        console.warn(
          'SeekLocateDisplay: persistParam "' + wanted + '" is already used by ' +
          'another instance on this page; using "' + param + '" instead. ' +
          'Set a distinct persistParam per instance to avoid this.'
        );
      }
    }
    claimedPersistParams.add(param);
    return param;
  }

  function readQueryParam(paramName) {
    try {
      return new URLSearchParams(window.location.search).get(paramName) || '';
    } catch (e) {
      return '';
    }
  }

  function writeQueryParam(paramName, value) {
    try {
      const url = new URL(window.location.href);
      if (value) {
        url.searchParams.set(paramName, value);
      } else {
        url.searchParams.delete(paramName);
      }
      window.history.replaceState(window.history.state, '', url.toString());
    } catch (e) { /* no-op in non-browser / unsupported environments */ }
  }

  function saveScroll(key) {
    try {
      sessionStorage.setItem(key, JSON.stringify({
        scrollY: window.scrollY,
        t: Date.now(),
      }));
    } catch (e) { /* sessionStorage unavailable (e.g. private mode) — degrade silently */ }
  }

  function readScroll(key) {
    try {
      const raw = sessionStorage.getItem(key);
      return raw ? JSON.parse(raw) : null;
    } catch (e) {
      return null;
    }
  }

  /* ─── Index builder ─────────────────────────────────────────── */

  function buildIndex(pages) {
    const entries = [];
    pages.forEach(page => {
      (page.sections || []).forEach(sec => {
        entries.push({
          url: page.url,
          pageTitle: page.title,
          sectionId: sec.id,
          heading: sec.heading,
          text: sec.text || '',
        });
      });
    });
    return entries;
  }

  /** Case-insensitive substring search — used for both bare words and quoted phrases. */
  /**
   * Is `ch` a "word" character for boundary-checking purposes? Uses a
   * Unicode property escape rather than \w / \b, since \w only covers
   * ASCII and would treat e.g. "café" or "naïve" as having a boundary
   * mid-word. Falls back to a simple ASCII check if the regex engine
   * doesn't support \p{L} (very old environments).
   */
  let isWordChar;
  try {
    const wordCharRe = /[\p{L}\p{N}_]/u;
    isWordChar = (ch) => !!ch && wordCharRe.test(ch);
  } catch (e) {
    const asciiWordRe = /[A-Za-z0-9_]/;
    isWordChar = (ch) => !!ch && asciiWordRe.test(ch);
  }

  /**
   * Case-insensitive substring search.
   *
   * @param {boolean} [wholeWord] - if true, a match only counts when the
   *   characters immediately before and after it (if any) are not word
   *   characters — i.e. "cat" matches "the cat sat" but not "category".
   *   For multi-word phrases this checks the boundary at each end of the
   *   whole phrase, not between the words inside it (those still just
   *   need to be adjacent, exactly as before).
   */
  function exactScore(text, phrase, wholeWord) {
    if (!phrase) return { score: 0, spans: [] };
    const lower = text.toLowerCase();
    const needle = phrase.toLowerCase();
    const spans = [];
    let idx = 0;
    while (true) {
      const found = lower.indexOf(needle, idx);
      if (found === -1) break;
      const end = found + needle.length;

      if (wholeWord) {
        const before = found > 0 ? text[found - 1] : '';
        const after  = end < text.length ? text[end] : '';
        if (isWordChar(before) || isWordChar(after)) {
          // Not a whole-word match — slide forward by one and keep scanning,
          // since a real whole-word occurrence could still start later
          // (e.g. needle "cat" against "concatcat" — skip the embedded
          // first hit but still find the standalone second one).
          idx = found + 1;
          continue;
        }
      }

      spans.push({ start: found, end });
      idx = end;
    }
    // Multiple occurrences of the same term score higher
    return { score: spans.length * 3, spans };
  }

  /* ─── Query parser ──────────────────────────────────────────────
   *
   * Grammar:
   *   - Bare word           → exact (case-insensitive) word match: chocolate
   *   - "quoted text"        → exact phrase match:  "dark chocolate"
   *   - word1 word2          → AND (both required, each independently)
   *   - word1 OR word2       → OR  (either group may match)
   *   - Quotes + OR may combine: "milk chocolate" OR "dark chocolate"
   *
   * Multiple OR-separated clauses are evaluated as OR-groups; within
   * a group all terms are AND'd together. The literal uppercase word
   * OR is the only operator — "or" lowercase is treated as a normal
   * search word so prose still works naturally.
   * ──────────────────────────────────────────────────────────────── */

  /** Tokenize a query into phrase/word/OR tokens, respecting "quotes". */
  function tokenizeQuery(query) {
    const tokens = [];
    const re = /"([^"]*)"|(\S+)/g;
    let m;
    while ((m = re.exec(query)) !== null) {
      if (m[1] !== undefined) {
        const text = m[1].trim();
        if (text) tokens.push({ type: 'phrase', text });
      } else if (m[2] === 'OR') {
        tokens.push({ type: 'or' });
      } else if (m[2]) {
        tokens.push({ type: 'word', text: m[2] });
      }
    }
    return tokens;
  }

  /**
   * parseQuery(query) → { groups, raw, error }
   *
   * groups: Array<Array<Term>>  — outer = OR, inner = AND
   * Term: { text: string, wholeWord: boolean }
   *   - wholeWord: true  for "quoted text" — must match on word boundaries
   *   - wholeWord: false for bare words    — matches anywhere as a substring
   */
  function parseQuery(query) {
    const tokens = tokenizeQuery(query.trim());
    if (!tokens.length) return { groups: [], raw: query, error: null };

    const groups = [];
    let current = [];

    tokens.forEach(tok => {
      if (tok.type === 'or') {
        if (current.length) groups.push(current);
        current = [];
      } else {
        current.push({ text: tok.text, wholeWord: tok.type === 'phrase' });
      }
    });
    if (current.length) groups.push(current);

    return { groups, raw: query, error: null };
  }

  /* ─── Search ────────────────────────────────────────────────── */

  /**
   * Evaluate one OR-group (AND of terms) against a whole SECTION —
   * heading and body together. Each term is satisfied by a match in
   * EITHER field: "milk" in the heading and "chocolate" only in the
   * body still satisfies the query `milk chocolate`. (An earlier
   * version AND-ed terms per field, so a section holding both terms
   * split across heading and body scored zero — surprising, and not
   * what "both terms must be present in the section" suggests.)
   *
   * Returns null if any term matches nowhere in the section (AND
   * semantics). Otherwise returns a combined score — heading matches
   * multiplied by headingWeight, exactly as before — plus per-field
   * span lists for rendering the <mark> highlights.
   */
  function evalGroupOnSection(entry, group, headingWeight) {
    let score = 0;
    let hSpans = [];
    let bSpans = [];
    for (const term of group) {
      const h = exactScore(entry.heading, term.text, term.wholeWord);
      const b = exactScore(entry.text,    term.text, term.wholeWord);
      if (h.spans.length === 0 && b.spans.length === 0) {
        return null; // AND: this term must match somewhere in the section
      }
      score += h.score * headingWeight + b.score;
      hSpans = hSpans.concat(h.spans);
      bSpans = bSpans.concat(b.spans);
    }
    return { score, hSpans, bSpans };
  }

  /** Evaluate all OR-groups against one section; best (highest-score) group wins. */
  function evalQueryOnSection(entry, groups, headingWeight) {
    let best = null;
    for (const group of groups) {
      const result = evalGroupOnSection(entry, group, headingWeight);
      if (result && (!best || result.score > best.score)) best = result;
    }
    return best;
  }

  function searchIndex(entries, parsed, opts) {
    if (parsed.error || !parsed.groups.length) return [];

    const scored = [];
    entries.forEach(e => {
      const r = evalQueryOnSection(e, parsed.groups, opts.headingWeight);
      if (r) scored.push({ ...e, score: r.score, _hSpans: r.hSpans, _bSpans: r.bSpans });
    });

    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, opts.maxResults);
  }

  function groupByPage(results) {
    const map = new Map();
    results.forEach(r => {
      if (!map.has(r.url)) map.set(r.url, { pageTitle: r.pageTitle, url: r.url, hits: [] });
      map.get(r.url).hits.push(r);
    });
    return [...map.values()];
  }

  /* ─── Render ────────────────────────────────────────────────── */

  /**
   * Build the destination URL for a result hit: base page URL + the
   * highlight query param (so the destination page can highlight
   * matches on load) + the #section-id anchor.
   *
   * Param ordering matters: the anchor (#...) must come last, since
   * everything after # is not part of the query string.
   */
  function buildDestUrl(pageUrl, sectionId, rawQuery, opts) {
    // Split off any fragment already present in the configured page URL.
    // Query params must be inserted BEFORE the '#' — checking only for
    // '?' meant a config like url:'guide.html#top' produced
    // 'guide.html#top?sld-hl=...#id', burying the param inside the
    // fragment where the destination page's highlighter never sees it.
    const hashIdx = pageUrl.indexOf('#');
    let base = hashIdx === -1 ? pageUrl : pageUrl.slice(0, hashIdx);
    const existingHash = hashIdx === -1 ? '' : pageUrl.slice(hashIdx + 1);

    if (opts.highlightOnNavigate && rawQuery) {
      const sep = base.includes('?') ? '&' : '?';
      base += sep + opts.highlightParam + '=' + encodeURIComponent(rawQuery);
    }

    // The section id is encoded (ids containing spaces, '%', '&' etc.
    // would otherwise produce a malformed fragment). A hash embedded in
    // the configured URL is passed through untouched — it may already be
    // encoded, and re-encoding would corrupt it. When both exist the
    // sectionId wins, being the more specific target.
    if (sectionId) {
      base += '#' + encodeURIComponent(sectionId);
    } else if (existingHash) {
      base += '#' + existingHash;
    }
    return base;
  }

  function renderHeading(heading, spans) {
    return applySpans(heading, spans || []);
  }

  /**
   * Build a trimmed excerpt around the best-scoring paragraph, rather
   * than the whole section text, so results stay scannable. If multiple
   * paragraphs (split by \n) have matches, each matched paragraph gets
   * its own short excerpt and they're joined with " | ".
   */
  function renderSnippet(text, spans, excerptLen) {
    const paragraphs = text.split('\n');
    if (paragraphs.length === 1) {
      return excerptFromSpans(text, spans, excerptLen);
    }

    // Figure out which paragraphs contain at least one span
    let offset = 0;
    const pieces = [];
    paragraphs.forEach(p => {
      const start = offset;
      const end   = offset + p.length;
      const localSpans = (spans || [])
        .filter(s => s.end > start && s.start < end)
        .map(s => ({ start: s.start - start, end: s.end - start }))
        .map(s => ({ start: Math.max(0, s.start), end: Math.min(p.length, s.end) }));
      if (localSpans.length) {
        pieces.push(excerptFromSpans(p, localSpans, excerptLen));
      }
      offset = end + 1;
    });

    if (!pieces.length) {
      // No spans landed in body (match was heading-only) — show first paragraph
      return escapeHtml(paragraphs[0].slice(0, excerptLen)) + (paragraphs[0].length > excerptLen ? '…' : '');
    }
    return pieces.join(' <span class="sld-sep">|</span> ');
  }

  function excerptFromSpans(text, spans, len) {
    let best = 0;
    if (spans && spans.length) best = Math.max(0, spans[0].start - 40);
    const raw    = text.slice(best, best + len);
    const suffix = text.length > best + len ? '…' : '';
    const shifted = (spans || [])
      .map(s => ({ start: s.start - best, end: s.end - best }))
      .filter(s => s.end > 0 && s.start < len)
      .map(s => ({ start: Math.max(0, s.start), end: Math.min(len, s.end) }));
    return applySpans(raw, shifted) + escapeHtml(suffix);
  }

  function renderResults(results, parsed, opts) {
    const groups = groupByPage(results);
    const total  = results.length;

    if (parsed.error) {
      return `<div class="sld-empty" style="color:#c0392b">${escapeHtml(parsed.error)}</div>`;
    }
    if (!total) {
      return `<div class="sld-empty">${escapeHtml(opts.noResultsText)}</div>`;
    }

    let html = `<div class="sld-stats">${total} result${total !== 1 ? 's' : ''} across ${groups.length} page${groups.length !== 1 ? 's' : ''}</div>`;

    groups.forEach(g => {
      html += `<div class="sld-page">`;
      html += `<div class="sld-page-header">${ICON_FILE}${escapeHtml(g.pageTitle)}<span class="sld-page-url">${escapeHtml(g.url)}</span></div>`;
      g.hits.forEach(hit => {
        const dest = buildDestUrl(hit.url, hit.sectionId, parsed.raw, opts);
        html += `<div class="sld-hit" role="link" tabindex="0" data-dest="${escapeHtml(dest)}" aria-label="${escapeHtml(hit.heading)} — ${escapeHtml(g.pageTitle)}">
          ${ICON_HASH}
          <div class="sld-hit-body">
            <div class="sld-hit-title">${renderHeading(hit.heading, hit._hSpans)}</div>
            <div class="sld-hit-snippet">${renderSnippet(hit.text, hit._bSpans, opts.excerptLength)}</div>
            <span class="sld-hit-anchor">${escapeHtml(dest)}</span>
          </div>
        </div>`;
      });
      html += `</div>`;
    });

    return html;
  }

  /* ─── SeekLocateDisplay class ──────────────────────────────────────── */

  function SeekLocateDisplay(userOpts) {
    const opts = Object.assign({}, DEFAULTS, userOpts);
    this._opts = opts;
    this._index = buildIndex(opts.pages);

    const root = typeof opts.container === 'string'
      ? document.querySelector(opts.container)
      : opts.container;

    if (!root) throw new Error('SeekLocateDisplay: container not found: ' + opts.container);

    root.classList.add('sld-wrap');
    root.innerHTML = `
      <div class="sld-bar" role="search">
        ${ICON_SEARCH}
        <input class="sld-input" type="search" placeholder="${escapeHtml(opts.placeholder)}"
               autocorrect="off" autocomplete="off" aria-label="${escapeHtml(opts.placeholder)}" />
        <button class="sld-clear" type="button" aria-label="Clear search" style="display:none">${ICON_CLOSE}</button>
      </div>
      <div class="sld-results" aria-live="polite" aria-atomic="true"></div>
    `;

    this._input    = root.querySelector('.sld-input');
    this._clearBtn = root.querySelector('.sld-clear');
    this._results  = root.querySelector('.sld-results');

    this._scrollKey = storageKey(containerKeyFor(opts.container));

    // Claim a page-unique URL param for query persistence — collisions
    // between instances get a numeric suffix (see claimPersistParam).
    // All reads/writes below go through this._persistParam, never the
    // raw opts value.
    this._persistParam = opts.persist
      ? claimPersistParam(opts.persistParam)
      : opts.persistParam;

    const doSearch = debounce((q) => this._runSearch(q), opts.debounceMs);

    // URL writes get their own (shorter) debounce, separate from the
    // search debounce. Writing on EVERY keystroke looks cheap but runs
    // into Safari's rate limit on history.replaceState (~100 calls per
    // 30 seconds): past the limit Safari throws, writeQueryParam's
    // try/catch swallows it, and the URL silently stops tracking the
    // query. The race the per-keystroke write originally guarded
    // against — clicking a result before the write fires, leaving the
    // URL without ?q= — is covered by _navigate(), which cancels any
    // pending write and writes the final value synchronously before
    // leaving the page.
    this._writeQuery = debounce((q) => {
      if (opts.persist) writeQueryParam(this._persistParam, q);
    }, 300);

    this._input.addEventListener('input', () => {
      const q = this._input.value;
      this._clearBtn.style.display = q ? 'block' : 'none';

      if (opts.persist) this._writeQuery(q);

      if (q.length < opts.minChars && q.length > 0) {
        this._results.innerHTML = '';
      } else {
        doSearch(q);
      }
    });

    this._clearBtn.addEventListener('click', () => {
      this._input.value = '';
      this._clearBtn.style.display = 'none';
      this._results.innerHTML = '';
      this._input.focus();
      if (opts.persist) {
        // Cancel any write still pending from typing — without this, a
        // debounced write of the just-cleared text could fire ~300ms
        // AFTER we remove the param, resurrecting a stale ?q= value.
        this._writeQuery.cancel();
        writeQueryParam(this._persistParam, '');
      }
    });

    this._results.addEventListener('click', e => {
      const hit = e.target.closest('.sld-hit');
      if (hit) this._navigate(hit.dataset.dest);
    });

    this._results.addEventListener('keydown', e => {
      if (e.key !== 'Enter' && e.key !== ' ') return;
      const hit = e.target.closest('.sld-hit');
      if (hit) { e.preventDefault(); this._navigate(hit.dataset.dest); }
    });

    // ── Restore persisted query + scroll position ──────────────────────
    if (opts.persist) {
      // Take control of scroll restoration away from the browser — its
      // own heuristic can run *after* ours and silently overwrite it,
      // which is the usual cause of "scroll position changes on back".
      //
      // IMPORTANT: only do this when we actually have state of our own to
      // restore (a persisted ?q= query AND a scroll position saved when a
      // search result was clicked). Setting 'manual' unconditionally
      // suppresses the browser's native back/forward restore INCLUDING its
      // jump to the URL's #fragment on history traversal — which broke the
      // ordinary case of: click an anchor link → follow a normal link to
      // another page → press Back. With no ?q= and no saved scroll we have
      // nothing to restore ourselves, so the browser must stay in charge.
      const hasPersistedQuery  = !!readQueryParam(this._persistParam);
      const hasPersistedScroll = !!readScroll(this._scrollKey);
      if ('scrollRestoration' in window.history) {
        if (hasPersistedQuery && hasPersistedScroll) {
          window.history.scrollRestoration = 'manual';
        } else {
          // Scroll-restoration mode is a property of the session history
          // ENTRY, not the document — if a previous load of this entry set
          // it to 'manual', that sticks across traversals. Explicitly hand
          // control back to the browser when we have nothing to restore,
          // otherwise the original "back lands at top" bug can resurface
          // on any entry that ever entered manual mode.
          window.history.scrollRestoration = 'auto';
        }
      }

      this._restoreQueryAndScroll();

      // Chrome (and other Chromium browsers) can replay its own scroll
      // snapshot when a page is restored from the back/forward cache —
      // this fires via `pageshow` with event.persisted === true, and can
      // happen *after* scrollRestoration was set to 'manual' and after our
      // initial restore ran. Safari's bfcache doesn't replay scroll the
      // same way, which is why this mainly shows up as a Chrome-only bug.
      // Re-running our restore here wins the race regardless of browser.
      window.addEventListener('pageshow', (e) => {
        if (e.persisted) this._restoreQueryAndScroll(true);
      });
    }

    // NOTE: scroll position is saved ONLY at the moment a result is
    // clicked (see _navigate below) — deliberately not on pagehide /
    // beforeunload as well. Those fire during page teardown, when layout
    // can already be shifting or the browser can be mid-navigation, and
    // saving again at that point was found to overwrite the correct,
    // click-time value with a worse one (e.g. 0, or some other position
    // captured mid-teardown). One clean save at the moment of intent
    // beats "defensive" saves at multiple uncertain later moments.
  }

  /**
   * Re-applies the persisted query (if any) and re-runs the scroll
   * restoration. Safe to call multiple times — used both on initial
   * load and again on bfcache `pageshow` restores.
   *
   * @param {boolean} [forceRepaint] - set true when called from a bfcache
   *   `pageshow` restore (see listener above). On Safari specifically,
   *   bfcache can restore a frozen page where input.value is already
   *   correct in the DOM (confirmed: reading it back returns the right
   *   string) but the browser hasn't repainted the visible text — so the
   *   box looks empty even though it isn't. Setting .value again is a
   *   no-op in that case (the value didn't change), so nothing forces a
   *   repaint. We work around it by toggling the value off and back on,
   *   which reliably forces Safari to repaint the field's text.
   */
  SeekLocateDisplay.prototype._restoreQueryAndScroll = function (forceRepaint) {
    const restoredQuery = readQueryParam(this._persistParam);
    if (!restoredQuery) return;

    const valueChanged = this._input.value !== restoredQuery;

    if (valueChanged) {
      this._input.value = restoredQuery;
      this._clearBtn.style.display = 'block';
      this._runSearch(restoredQuery);
    } else if (forceRepaint) {
      // Value is already correct but may be stale-painted (Safari bfcache).
      // Toggling it forces the browser to actually redraw the text.
      this._input.value = '';
      // Reading offsetHeight forces a synchronous layout flush between
      // the clear and the restore, which is what makes the toggle work
      // as a repaint trigger rather than being batched away.
      void this._input.offsetHeight;
      this._input.value = restoredQuery;
      this._clearBtn.style.display = 'block';
      // Results list can suffer the same stale-paint issue, so re-render
      // it too rather than assuming it's still correctly displayed.
      this._runSearch(restoredQuery);
    }

    const scroll = readScroll(this._scrollKey);
    if (scroll) this._restoreScroll(scroll);
  };

  SeekLocateDisplay.prototype._runSearch = function (query) {
    const trimmed = query.trim();
    // minChars is enforced HERE, not only in the input handler, so that
    // every path into a search — typing, _restoreQueryAndScroll on
    // back-navigation, refresh() — applies the same rule. Previously a
    // persisted 1-character query rendered results after Back that
    // typing the same character never would have.
    if (!trimmed || trimmed.length < this._opts.minChars) {
      this._results.innerHTML = '';
      return;
    }
    const parsed = parseQuery(query);
    const results = searchIndex(this._index, parsed, this._opts);
    this._results.innerHTML = renderResults(results, parsed, this._opts);
  };

  /**
   * Restore scroll position robustly.
   *
   * The previous approach re-applied scrollTo() across a fixed number of
   * animation frames, which assumes layout settles within ~8 frames. On a
   * results list whose height depends on render content (and possibly
   * icon fonts or other late-loading assets), that assumption can be
   * wrong: applying scrollTo(y) before the page is tall enough to reach y
   * just clamps to the current (shorter) max scroll, landing somewhere
   * else entirely — which is what "jumps to a wrong position" looks like.
   *
   * Fix: poll until document height can actually accommodate the target
   * Y position (or a max wait elapses), then scroll once layout is known
   * to support it. Keep nudging for a short window after that in case of
   * late shifts, but the height check is what prevents the early-clamp bug.
   */
  SeekLocateDisplay.prototype._restoreScroll = function (scroll) {
    const targetY = scroll.scrollY || 0;
    const maxWaitMs = 1500;
    const pollIntervalMs = 16;
    const settleWindowMs = 400; // keep nudging briefly after the first successful apply
    const startedAt = Date.now();

    // ── Abort the moment the user scrolls on their own. Without this,
    // the poll + settle loop below keeps re-issuing scrollTo() for up
    // to ~1.9s total, repeatedly yanking the page away from a user who
    // has already started scrolling somewhere else. Programmatic
    // scrollTo() doesn't fire wheel/touchmove, so these listeners only
    // catch genuine user intent. Keydown is filtered to scrolling keys
    // and ignored while focus is in a form field (typing a space into
    // the search box must not cancel the restore).
    let cancelled = false;
    const SCROLL_KEYS = ['ArrowUp', 'ArrowDown', 'PageUp', 'PageDown', 'Home', 'End', ' '];
    const inFormField = (el) => {
      if (!el || !el.tagName) return false;
      const tag = el.tagName.toLowerCase();
      return tag === 'input' || tag === 'textarea' || tag === 'select' || el.isContentEditable;
    };
    const cancel = () => {
      if (cancelled) return;
      cancelled = true;
      window.removeEventListener('wheel', onUserScrollIntent);
      window.removeEventListener('touchmove', onUserScrollIntent);
      window.removeEventListener('keydown', onUserScrollIntent);
    };
    const onUserScrollIntent = (e) => {
      if (e.type === 'keydown' && (!SCROLL_KEYS.includes(e.key) || inFormField(e.target))) return;
      cancel();
    };
    window.addEventListener('wheel', onUserScrollIntent, { passive: true });
    window.addEventListener('touchmove', onUserScrollIntent, { passive: true });
    window.addEventListener('keydown', onUserScrollIntent);

    const maxScrollY = () =>
      Math.max(
        document.documentElement.scrollHeight,
        document.body ? document.body.scrollHeight : 0
      ) - window.innerHeight;

    const apply = () => window.scrollTo(0, targetY);

    const poll = () => {
      if (cancelled) return;
      const elapsed = Date.now() - startedAt;
      const canReachTarget = maxScrollY() >= targetY - 1; // -1 for rounding

      if (canReachTarget || elapsed >= maxWaitMs) {
        apply();
        // Layout can still shift slightly right after first reaching
        // full height (fonts swapping in, etc.) — nudge a few more times.
        const settleStart = Date.now();
        const nudge = () => {
          if (cancelled) return;
          apply();
          if (Date.now() - settleStart < settleWindowMs) {
            requestAnimationFrame(nudge);
          } else {
            cancel(); // done — remove the abort listeners
          }
        };
        requestAnimationFrame(nudge);
        return;
      }

      setTimeout(poll, pollIntervalMs);
    };

    poll();
  };

  SeekLocateDisplay.prototype._navigate = function (url) {
    if (this._opts.persist) {
      saveScroll(this._scrollKey);
      // Write the search page's URL param synchronously before leaving —
      // this is what makes the debounced per-keystroke write safe: even
      // if the user clicks a result inside the debounce window, the URL
      // gets the final value here. Cancel the pending write first so it
      // can't fire again afterwards (harmless in most cases, but it
      // would burn another replaceState call for nothing).
      this._writeQuery.cancel();
      writeQueryParam(this._persistParam, this._input.value);
    }
    if (typeof this._opts.onNavigate === 'function') {
      this._opts.onNavigate(url);
    } else {
      window.location.href = url;
    }
  };

  /** Add pages dynamically after init */
  SeekLocateDisplay.prototype.addPage = function (page) {
    const newEntries = buildIndex([page]);
    this._index = this._index.concat(newEntries);
  };

  /** Replace all pages */
  SeekLocateDisplay.prototype.setPages = function (pages) {
    this._index = buildIndex(pages);
  };

  /** Re-run last search (useful after addPage) */
  SeekLocateDisplay.prototype.refresh = function () {
    this._runSearch(this._input.value);
  };

  return SeekLocateDisplay;
}));
