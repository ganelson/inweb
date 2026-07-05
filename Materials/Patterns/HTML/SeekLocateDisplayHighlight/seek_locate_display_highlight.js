/**
 * seek_locate_display_highlight.js — v1.0
 * Companion script for SeekLocateDisplay.js destination pages.
 *
 * When a SeekLocateDisplay search result is clicked, the destination URL carries
 * the original query in a URL param (default: ?ls-hl=...). Include this
 * script on every page that can be a SeekLocateDisplay search target, and it will:
 *
 *   1. Read the query from the URL
 *   2. Walk the page's visible text nodes
 *   3. Wrap matches in <mark class="ls-page-highlight">
 *   4. Scroll to the first match WITHIN the #section the user navigated
 *      to (if present), not just the first match anywhere on the page.
 *      If the section has no match inside it, stay at the section itself
 *      rather than jumping elsewhere. With no #section anchor at all,
 *      falls back to the first match on the whole page.
 *   5. Optionally remove the param from the URL afterwards — only when
 *      { cleanUrl: true } is set. By default (cleanUrl: false) the param
 *      is left in place, so reloading the page or returning to it via
 *      the back button re-applies the highlights.
 *
 * Usage — just before </body>:
 *   <script src="seeklocatedisplay-highlight.js"></script>
 *
 * Or with options:
 *   <script>
 *     window.SeekLocateDisplayHighlightOptions = { param: 'ls-hl', scroll: true };
 *   </script>
 *   <script src="seek_locate_display_highlight.js"></script>
 *
 * Uses the same query grammar as SeekLocateDisplay.js's search box:
 *   word                  → matches anywhere, including inside longer words
 *   "exact word/phrase"    → whole-word match only (won't match inside
 *                             a longer word, e.g. "cat" won't match "category")
 *   a b                    → AND (both required)
 *   a OR b                 → OR
 *
 * MIT License — free to use, modify, and redistribute.
 */

(function () {
  'use strict';

  const DEFAULTS = {
    param: 'ls-hl',         // URL query param carrying the search query
    scroll: true,           // auto-scroll to the first match
    scrollBehavior: 'smooth',
    scrollOffset: 80,        // px gap above the highlighted match (sticky headers etc.)
    cleanUrl: false,          // leave the param in the URL so reload/back re-highlights; set true to strip it (tidier URLs, but highlights are lost on reload)
    markClassName: 'ls-page-highlight',
    activeClassName: 'ls-page-highlight-active', // applied to the first/scrolled-to match
    skipTags: ['script', 'style', 'noscript', 'textarea', 'input', 'select', 'option', 'svg', 'mark', 'mjx-container'],
    minTextLength: 1,
  };

  const opts = Object.assign({}, DEFAULTS, window.SeekLocateDisplayHighlightOptions || {});

  /* ─── Query grammar (mirrors SeekLocateDisplay.js core) ────────────────── */

  /**
   * Is `ch` a "word" character for boundary-checking purposes? Uses a
   * Unicode property escape rather than \w / \b, since \w only covers
   * ASCII and would treat e.g. "café" as having a word boundary mid-word.
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
   * @param {boolean} [wholeWord] - if true (set for quoted terms), a
   *   match only counts when the characters immediately before/after it
   *   are not word characters — "cat" matches "the cat sat" but not
   *   "category". For multi-word phrases this checks the boundary at
   *   each end of the whole phrase.
   */
  function exactMatches(text, phrase, wholeWord) {
    if (!phrase) return [];
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
          idx = found + 1; // skip embedded false-positive, keep scanning
          continue;
        }
      }

      spans.push({ start: found, end });
      idx = end;
    }
    return spans;
  }

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

  function parseQuery(query) {
    const tokens = tokenizeQuery((query || '').trim());
    if (!tokens.length) return { groups: [] };
    const groups = [];
    let current = [];
    tokens.forEach(tok => {
      if (tok.type === 'or') { if (current.length) groups.push(current); current = []; }
      else current.push({ text: tok.text, wholeWord: tok.type === 'phrase' });
    });
    if (current.length) groups.push(current);
    return { groups };
  }

  /**
   * For highlighting purposes we don't need AND-gating per text node
   * (a single node — usually a sentence fragment — rarely contains every
   * AND term). Instead we collect ALL term matches across the whole page
   * for every term mentioned anywhere in the query (any kind, any group),
   * since OR/AND only affects which *sections* a result lives in, not which
   * literal words deserve a highlight once you're already on the page.
   */
  function flattenTerms(groups) {
    const terms = [];
    groups.forEach(g => g.forEach(t => terms.push(t)));
    return terms;
  }

  /* ─── Exclusion zones: math regions are never highlighted ───────────
   *
   * Two marker styles delimit math content (rendered LaTeX source,
   * MathJax input, etc.) that must never be highlighted — a match
   * landing inside one is almost certainly a coincidental substring of
   * notation, not a real content match:
   *
   *   \INWEBMATH( ... \INWEBMATH)  — can span multiple text nodes
   *   $$ ... $$                    — always confined to a single node
   */
  const MATH_OPEN = '\\INWEBMATH(';
  const MATH_CLOSE = '\\INWEBMATH)';
  const DOLLAR_DELIM = '$$';

  /**
   * Walk all node texts in document order and compute, per node, the
   * list of [start,end) character ranges that fall inside a math region.
   * Returns a Map<node, Array<{start,end}>>.
   *
   * Two marker styles are recognized, scanned together left-to-right so
   * overlapping/adjacent uses don't interfere with each other:
   *
   *   \INWEBMATH( ... \INWEBMATH)  — can span multiple text nodes, so
   *                                   "currently inside" state is tracked
   *                                   across the whole node sequence.
   *   $$ ... $$                    — always confined to a single text
   *                                   node (per spec), so each node is
   *                                   scanned independently for pairs.
   */
  function computeExclusionRanges(textNodes) {
    const exclusions = new Map();
    let insideInwebmath = false; // only this marker style can span nodes

    textNodes.forEach(node => {
      const text = node.nodeValue;
      const ranges = [];
      let cursor = 0;

      // ── \INWEBMATH( ... \INWEBMATH) — may continue from a prior node ──
      if (insideInwebmath) {
        const closeIdx = text.indexOf(MATH_CLOSE, cursor);
        if (closeIdx === -1) {
          ranges.push({ start: 0, end: text.length });
          cursor = text.length;
        } else {
          ranges.push({ start: 0, end: closeIdx + MATH_CLOSE.length });
          insideInwebmath = false;
          cursor = closeIdx + MATH_CLOSE.length;
        }
      }

      // ── Scan the rest of this node for both marker styles, in the
      //    order they actually appear, so e.g. "$$...$$ \INWEBMATH(...)"
      //    is handled correctly regardless of which comes first. ──────
      while (cursor < text.length) {
        const inwebOpenIdx = text.indexOf(MATH_OPEN, cursor);
        const dollarOpenIdx = text.indexOf(DOLLAR_DELIM, cursor);

        const hasInweb = inwebOpenIdx !== -1;
        const hasDollar = dollarOpenIdx !== -1;
        if (!hasInweb && !hasDollar) break;

        const useDollar = hasDollar && (!hasInweb || dollarOpenIdx < inwebOpenIdx);

        if (useDollar) {
          // $$ ... $$ — must close within this same node.
          const closeIdx = text.indexOf(DOLLAR_DELIM, dollarOpenIdx + DOLLAR_DELIM.length);
          if (closeIdx === -1) {
            // Unterminated — per spec these are confined to one node, so
            // an unmatched opener is not treated as an exclusion region
            // (nothing to exclude up to); just stop scanning this node.
            break;
          }
          ranges.push({ start: dollarOpenIdx, end: closeIdx + DOLLAR_DELIM.length });
          cursor = closeIdx + DOLLAR_DELIM.length;
        } else {
          // \INWEBMATH( ... \INWEBMATH) — may continue into later nodes.
          const closeIdx = text.indexOf(MATH_CLOSE, inwebOpenIdx + MATH_OPEN.length);
          if (closeIdx === -1) {
            ranges.push({ start: inwebOpenIdx, end: text.length });
            insideInwebmath = true;
            cursor = text.length;
          } else {
            ranges.push({ start: inwebOpenIdx, end: closeIdx + MATH_CLOSE.length });
            cursor = closeIdx + MATH_CLOSE.length;
          }
        }
      }

      if (ranges.length) exclusions.set(node, ranges);
    });

    return exclusions;
  }

  /** True if [start,end) overlaps at all with any range in `ranges`. */
  function overlapsAnyRange(start, end, ranges) {
    if (!ranges) return false;
    return ranges.some(r => start < r.end && end > r.start);
  }

  /** Drop any spans that overlap an excluded range. */
  function filterExcludedSpans(spans, ranges) {
    if (!ranges || !ranges.length) return spans;
    return spans.filter(sp => !overlapsAnyRange(sp.start, sp.end, ranges));
  }

  function findMatchesInText(text, terms) {
    let spans = [];
    terms.forEach(term => {
      spans = spans.concat(exactMatches(text, term.text, term.wholeWord));
    });
    if (!spans.length) return [];
    // Merge overlapping/adjacent spans
    spans.sort((a, b) => a.start - b.start);
    const merged = [{ ...spans[0] }];
    for (let i = 1; i < spans.length; i++) {
      const last = merged[merged.length - 1];
      if (spans[i].start <= last.end) last.end = Math.max(last.end, spans[i].end);
      else merged.push({ ...spans[i] });
    }
    return merged;
  }

  /* ─── DOM walking + highlighting ─────────────────────────────────── */

  function shouldSkip(node) {
    let el = node.parentElement;
    while (el) {
      if (opts.skipTags.includes(el.tagName.toLowerCase())) return true;
      if (el.isContentEditable) return true;
      el = el.parentElement;
    }
    return false;
  }

  function collectTextNodes(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode(node) {
        if (!node.nodeValue || node.nodeValue.trim().length < opts.minTextLength) return NodeFilter.FILTER_REJECT;
        if (shouldSkip(node)) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      },
    });
    const nodes = [];
    let n;
    while ((n = walker.nextNode())) nodes.push(n);
    return nodes;
  }

  function highlightTextNode(node, spans) {
    const text = node.nodeValue;
    const frag = document.createDocumentFragment();
    let cursor = 0;
    const marks = [];

    spans.forEach(sp => {
      if (sp.start > cursor) frag.appendChild(document.createTextNode(text.slice(cursor, sp.start)));
      const mark = document.createElement('mark');
      mark.className = opts.markClassName;
      mark.textContent = text.slice(sp.start, sp.end);
      frag.appendChild(mark);
      marks.push(mark);
      cursor = sp.end;
    });
    if (cursor < text.length) frag.appendChild(document.createTextNode(text.slice(cursor)));

    node.parentNode.replaceChild(frag, node);
    return marks;
  }

  function highlightPage(query) {
    const parsed = parseQuery(query);
    const terms = flattenTerms(parsed.groups);
    if (!terms.length) return [];

    const textNodes = collectTextNodes(document.body);
    const exclusions = computeExclusionRanges(textNodes);
    const allMarks = [];

    // Snapshot nodeValue + spans before mutating, since highlighting one
    // node can invalidate the TreeWalker's view of subsequent nodes if
    // we mutate while walking. We already fully collected nodes above,
    // so it's safe to mutate now.
    textNodes.forEach(node => {
      const text = node.nodeValue;
      let spans = findMatchesInText(text, terms);
      spans = filterExcludedSpans(spans, exclusions.get(node));
      if (spans.length) {
        const marks = highlightTextNode(node, spans);
        allMarks.push(...marks);
      }
    });

    return allMarks;
  }

  function getSectionElement() {
    const raw = window.location.hash.slice(1);
    if (!raw) return null;
    // SeekLocateDisplay percent-encodes section ids when building result
    // URLs (ids can contain spaces, '%', '&', …), and browsers themselves
    // try both the raw and percent-decoded forms when jumping to a
    // fragment — so we must do the same here or encoded ids never match.
    const candidates = [raw];
    try {
      const decoded = decodeURIComponent(raw);
      if (decoded !== raw) candidates.push(decoded);
    } catch (e) { /* malformed escape sequence — just use the raw form */ }

    for (const hash of candidates) {
      let el = document.getElementById(hash);
      if (!el) {
        try {
          el = document.querySelector(`[name="${CSS.escape(hash)}"]`);
        } catch (e) { /* CSS.escape unavailable — getElementById already tried */ }
      }
      if (el) return el;
    }
    return null;
  }

  /**
   * Pick which mark to scroll to.
   *
   * If the URL has a #section anchor (the normal case — SeekLocateDisplay always
   * appends one), only matches physically inside that section element are
   * eligible. This avoids the bug where the page scrolls to some unrelated
   * earlier match elsewhere on the page instead of the section the user
   * actually navigated to.
   *
   *   - If the section contains at least one match, scroll to the first
   *     match within it.
   *   - If the section exists but contains no match (e.g. the match was
   *     only in the heading text, or section boundaries are approximate),
   *     stay at the section itself — don't jump elsewhere on the page.
   *   - If there's no #section anchor at all, fall back to the first
   *     match anywhere on the page (previous behavior).
   */
  function pickScrollTarget(marks) {
    const section = getSectionElement();
    if (!section) {
      return { type: 'mark', el: marks[0] || null };
    }
    const withinSection = marks.find(m => section.contains(m));
    if (withinSection) {
      return { type: 'mark', el: withinSection };
    }
    return { type: 'section', el: section };
  }

  /**
   * Scroll to the chosen target once layout has settled.
   *
   * The previous version measured getBoundingClientRect() one frame
   * after DOMContentLoaded and scrolled to that Y. Anything that shifts
   * layout after that point — images without explicit dimensions, web
   * fonts swapping in, MathJax typesetting — moves the content and the
   * scroll lands in the wrong place. (This is the same early-measurement
   * bug the search library's _restoreScroll was rewritten to avoid.)
   *
   * Instead: the active-mark class is applied immediately (it should be
   * visible regardless of scrolling), then we poll each frame until the
   * target's document position AND the document height have been stable
   * for a few consecutive frames — or a max wait elapses — and only then
   * measure and scroll, once. If the user starts scrolling before we do,
   * we abort entirely rather than yank the page away from them.
   */
  function scrollToTargetWhenSettled(target) {
    if (!target || !target.el) return;

    if (target.type === 'mark') {
      target.el.classList.add(opts.activeClassName);
    }

    const maxWaitMs = 1500;
    const stableFramesNeeded = 3;
    const startedAt = Date.now();

    let cancelled = false;
    const onUserScroll = () => {
      cancelled = true;
      removeAbortListeners();
    };
    function removeAbortListeners() {
      window.removeEventListener('wheel', onUserScroll);
      window.removeEventListener('touchmove', onUserScroll);
    }
    window.addEventListener('wheel', onUserScroll, { passive: true });
    window.addEventListener('touchmove', onUserScroll, { passive: true });

    let lastTop = null;
    let lastHeight = null;
    let stableFrames = 0;

    const doScroll = () => {
      removeAbortListeners();
      const rect = target.el.getBoundingClientRect();
      const targetY = window.scrollY + rect.top - opts.scrollOffset;
      window.scrollTo({ top: Math.max(0, targetY), behavior: opts.scrollBehavior });
    };

    const check = () => {
      if (cancelled) return;
      const rect = target.el.getBoundingClientRect();
      const top = rect.top + window.scrollY; // document-space position
      const height = document.documentElement.scrollHeight;

      if (top === lastTop && height === lastHeight) {
        stableFrames++;
      } else {
        stableFrames = 0;
      }
      lastTop = top;
      lastHeight = height;

      if (stableFrames >= stableFramesNeeded || Date.now() - startedAt >= maxWaitMs) {
        doScroll();
        return;
      }
      requestAnimationFrame(check);
    };

    // Starting on the next frame also lets the browser's own native
    // #anchor jump (if any) happen first; we then refine on top of it.
    requestAnimationFrame(check);
  }

  function cleanUrlParam(paramName) {
    try {
      const url = new URL(window.location.href);
      url.searchParams.delete(paramName);
      window.history.replaceState(window.history.state, '', url.toString());
    } catch (e) { /* no-op */ }
  }

  function injectDefaultStyles() {
    if (document.getElementById('ls-highlight-styles')) return;
    const style = document.createElement('style');
    style.id = 'ls-highlight-styles';
    style.textContent = `
      mark.${opts.markClassName} {
        background: #fff3a3;
        color: inherit;
        border-radius: 2px;
        padding: 0 1px;
      }
      mark.${opts.activeClassName} {
        background: #ffd24a;
        box-shadow: 0 0 0 2px #ffd24a;
      }
      @media (prefers-color-scheme: dark) {
        mark.${opts.markClassName} { background: #5a4a00; color: #fff; }
        mark.${opts.activeClassName} { background: #8a6d00; box-shadow: 0 0 0 2px #8a6d00; }
      }
    `;
    document.head.appendChild(style);
  }

  /* ─── Entry point ───────────────────────────────────────────────── */

  function run() {
    let query;
    try {
      query = new URLSearchParams(window.location.search).get(opts.param);
    } catch (e) {
      return;
    }
    if (!query) return;

    injectDefaultStyles();
    const marks = highlightPage(query);

    if (opts.scroll) {
      const target = pickScrollTarget(marks);
      scrollToTargetWhenSettled(target);
    }

    if (opts.cleanUrl) cleanUrlParam(opts.param);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
})();
