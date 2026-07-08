/*
 * Discord Search Exporter (local)  --  content.js
 * ------------------------------------------------
 * Runs ONLY on discord.com (see manifest matches). It has NO permissions,
 * NO background page, and makes NO network requests. Audit it yourself:
 *   - search this file for `fetch`, `XMLHttpRequest`, `WebSocket`, `sendBeacon`,
 *     or any URL -> there are none.
 *   - the only thing it does is read text already rendered on your screen and
 *     hand you a file via a normal browser download.
 *
 * It injects two buttons (bottom-right) once you're on a Discord search:
 *   [Debug]  -> dumps the STRUCTURE of the search pane (tags + class names,
 *               text lengths only, no message text) so selectors can be tuned
 *               without you having to paste any private content.
 *   [Export] -> scrolls through the whole virtualized results list, collecting
 *               each hit, dedupes by message id, and downloads a JSON file.
 *
 * Output shape is DiscordChatExporter-compatible so it feeds ingest_dce.py:
 *   { "channel": {"name": "..."},
 *     "messages": [ { "id", "timestamp", "author": {"name"}, "content", "channelName", "link" } ] }
 */
(() => {
  "use strict";
  if (window.__dse_loaded) return;      // guard against double-injection
  window.__dse_loaded = true;

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  // ---- selectors (isolated up top so they're easy to tune) -----------------
  const SEL = {
    // the search results panel / its scroll container
    resultsWrap: '[class*="searchResults"]',
    scroller: '[class*="scroller"]',
    // a rendered message body carries a stable id: message-content-<messageId>
    content: '[id^="message-content-"]',
    // within a message's container:
    time: "time[datetime]",
    username: '[id^="message-username-"], [class*="username"]',
    channelName: '[class*="channelName"], [class*="channelSeparator"]',
    jumpLink: 'a[href*="/channels/"]',
    // the message container we climb to from the content node
    messageRoot: 'li, [class*="searchResult"], [class*="message-"], [class*="messageListItem"]',
  };

  // ---- DOM helpers ----------------------------------------------------------
  function findScroller() {
    // ONLY scrape inside the search-results panel. Do NOT fall back to any other
    // scrollable container — the main chat is also scrollable and full of
    // everyone's messages, and grabbing it would defeat the from:you filter.
    const wrap = document.querySelector(SEL.resultsWrap);
    if (!wrap) return null;
    // if the panel has an inner scroller holding the results, use it; else the wrap.
    const inner = [...wrap.querySelectorAll(SEL.scroller)]
      .find((s) => s.querySelectorAll(SEL.content).length);
    return inner || wrap;
  }

  function messageRootOf(contentEl) {
    return contentEl.closest(SEL.messageRoot) || contentEl.parentElement || contentEl;
  }

  function extract(contentEl) {
    const id = contentEl.id.replace("message-content-", "");
    const root = messageRootOf(contentEl);
    const timeEl = root.querySelector(SEL.time);
    const userEl = root.querySelector(SEL.username);
    const chanEl = root.querySelector(SEL.channelName);
    const linkEl = root.querySelector(SEL.jumpLink);
    return {
      id,
      timestamp: timeEl ? (timeEl.getAttribute("datetime") || timeEl.textContent.trim()) : "",
      author: { name: userEl ? userEl.textContent.trim() : "" },
      content: contentEl.textContent.trim(),
      channelName: chanEl ? chanEl.textContent.trim() : "",
      link: linkEl ? linkEl.href : "",
    };
  }

  function download(name, obj) {
    const blob = new Blob([JSON.stringify(obj, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = name;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 2000);
  }

  function searchQueryGuess() {
    const box = document.querySelector('input[aria-label*="Search" i], [class*="searchBar"] input');
    return (box && box.value) ? box.value.trim() : "search";
  }

  // ---- the scrape loop ------------------------------------------------------
  async function scrape(onProgress) {
    const scroller = findScroller();
    if (!scroller) throw new Error("Could not find the search results pane. Run a search first.");

    const seen = new Map();
    let stall = 0;
    let lastTop = -1;

    // collect whatever is currently rendered
    const harvest = () => {
      for (const el of scroller.querySelectorAll(SEL.content)) {
        const id = el.id.replace("message-content-", "");
        if (!seen.has(id)) seen.set(id, extract(el));
      }
    };

    scroller.scrollTop = 0;
    await sleep(300);

    // loop: harvest -> scroll a viewport -> wait for Discord to render more
    for (let i = 0; i < 5000; i++) {
      const before = seen.size;
      harvest();
      onProgress(seen.size);

      const top = scroller.scrollTop;
      const atBottom = top + scroller.clientHeight >= scroller.scrollHeight - 4;
      const grew = seen.size > before;
      const moved = top !== lastTop;
      lastTop = top;

      if (atBottom && !grew && !moved) {
        stall++;
        if (stall >= 3) break;      // 3 quiet rounds at the bottom -> done
      } else {
        stall = 0;
      }

      scroller.scrollTop = top + Math.floor(scroller.clientHeight * 0.85);
      await sleep(450);             // let the virtualized list render the next slice
    }

    harvest();
    return [...seen.values()];
  }

  // ---- Debug: structure only, NO message text -------------------------------
  function debugDump() {
    const scroller = findScroller();
    const sample = scroller ? scroller.querySelector(SEL.content) : null;
    const root = sample ? messageRootOf(sample) : null;

    // walk a small subtree recording tag + classes + text LENGTH (not text)
    const structure = (node, depth) => {
      if (!node || depth > 6) return null;
      const kids = [...node.children].slice(0, 8).map((c) => structure(c, depth + 1)).filter(Boolean);
      return {
        tag: node.tagName.toLowerCase(),
        id: node.id || undefined,
        class: (typeof node.className === "string" ? node.className : "") || undefined,
        textLen: node.childElementCount === 0 ? (node.textContent || "").length : undefined,
        children: kids.length ? kids : undefined,
      };
    };

    // scroller candidates: is anything actually scrollable, or is it paginated?
    const scCands = new Set([...document.querySelectorAll(SEL.scroller)]);
    const wrap = document.querySelector(SEL.resultsWrap);
    if (wrap) scCands.add(wrap);
    const scrollers = [...scCands]
      .map((s) => ({
        cls: (typeof s.className === "string" ? s.className : "").slice(0, 70),
        scrollHeight: s.scrollHeight, clientHeight: s.clientHeight,
        scrollable: s.scrollHeight > s.clientHeight + 8,
        contentNodes: s.querySelectorAll(SEL.content).length,
      }))
      .filter((x) => x.contentNodes > 0 || x.scrollable);

    // pager candidates: buttons/links near the results (labels + short text only,
    // never message content) — this is where a "next page" control would show up.
    const pagerScope = wrap || document.body;
    const pager = [...pagerScope.querySelectorAll('button, [role="button"], a')]
      .map((el) => ({
        tag: el.tagName.toLowerCase(),
        label: (el.getAttribute("aria-label") || "").slice(0, 40),
        text: (el.textContent || "").trim().slice(0, 20),
        disabled: el.getAttribute("aria-disabled") === "true" || el.disabled === true,
      }))
      .filter((x) => x.label || x.text)
      .slice(0, 50);

    const info = {
      url: location.pathname,
      foundScroller: !!scroller,
      scrollerClass: scroller ? (typeof scroller.className === "string" ? scroller.className : "") : null,
      contentNodeCount: scroller ? scroller.querySelectorAll(SEL.content).length : 0,
      hasTimeEls: root ? !!root.querySelector(SEL.time) : false,
      hasUsernameEls: root ? !!root.querySelector(SEL.username) : false,
      hasJumpLink: root ? !!root.querySelector(SEL.jumpLink) : false,
      scrollers,
      pager,
      sampleStructure: structure(root, 0),
    };
    console.log("[DSE debug]", info);
    download("discord-export-debug.json", info);
    return info;
  }

  // ---- persistent accumulator (browser localStorage on discord.com) ---------
  // Survives page reloads so a 47-page grind can't lose progress. Keyed by
  // message id, so re-adding a page is harmless (dedup is automatic).
  const STORE_KEY = "dse_accumulator_v1";
  function loadStore() {
    try { return JSON.parse(window.localStorage.getItem(STORE_KEY) || "{}"); }
    catch (_) { return {}; }
  }
  function saveStore(obj) {
    try { window.localStorage.setItem(STORE_KEY, JSON.stringify(obj)); return true; }
    catch (_) { return false; }
  }
  function storeCount() { return Object.keys(loadStore()).length; }

  // count of "Add page" presses = which page you're on. Persisted so a reload
  // doesn't lose your place.
  const ADDS_KEY = "dse_adds_v1";
  function getAdds() {
    try { return parseInt(window.localStorage.getItem(ADDS_KEY) || "0", 10) || 0; }
    catch (_) { return 0; }
  }
  function setAdds(n) {
    try { window.localStorage.setItem(ADDS_KEY, String(n)); } catch (_) {}
  }

  // Copy text to the clipboard. Downloads are blocked in this environment, so
  // this is the reliable way out: clipboard API, with an execCommand fallback.
  async function copyText(text) {
    try { await navigator.clipboard.writeText(text); return true; } catch (_) {}
    try {
      const ta = document.createElement("textarea");
      ta.value = text;
      ta.style.cssText = "position:fixed;left:-9999px;top:0;";
      document.body.appendChild(ta);
      ta.focus(); ta.select();
      const ok = document.execCommand("copy");
      ta.remove();
      return ok;
    } catch (_) { return false; }
  }

  // ---- UI -------------------------------------------------------------------
  function mkBtn(label, bg) {
    const b = document.createElement("button");
    b.textContent = label;
    b.style.cssText =
      "all:unset;box-sizing:border-box;width:100%;cursor:pointer;font:600 13px/1 system-ui,sans-serif;color:#fff;" +
      "padding:9px 14px;margin:4px 0 0;border-radius:8px;display:block;text-align:center;" +
      "box-shadow:0 2px 8px rgba(0,0,0,.35);background:" + bg + ";";
    return b;
  }

  function mountUI() {
    if (document.getElementById("dse-panel")) return;
    const panel = document.createElement("div");
    panel.id = "dse-panel";
    // default bottom-LEFT so it never sits on top of the results pager (which is
    // bottom-right). Drag it anywhere via the handle.
    panel.style.cssText =
      "position:fixed;left:16px;bottom:16px;z-index:2147483647;display:flex;flex-direction:column;" +
      "align-items:stretch;width:200px;box-sizing:border-box;";

    // drag handle -------------------------------------------------------------
    const handle = document.createElement("div");
    handle.textContent = "⠿ drag";
    handle.style.cssText =
      "font:600 10px system-ui,sans-serif;color:#fff;background:rgba(0,0,0,.5);" +
      "padding:3px 8px;border-radius:6px;text-align:center;cursor:move;user-select:none;margin-bottom:4px;";
    let dragging = false, ox = 0, oy = 0, sx = 0, sy = 0;
    handle.addEventListener("pointerdown", (e) => {
      dragging = true;
      const r = panel.getBoundingClientRect();
      ox = r.left; oy = r.top; sx = e.clientX; sy = e.clientY;
      panel.style.right = "auto"; panel.style.bottom = "auto";
      panel.style.left = ox + "px"; panel.style.top = oy + "px";
      try { handle.setPointerCapture(e.pointerId); } catch (_) {}
    });
    handle.addEventListener("pointermove", (e) => {
      if (!dragging) return;
      panel.style.left = (ox + e.clientX - sx) + "px";
      panel.style.top = (oy + e.clientY - sy) + "px";
    });
    handle.addEventListener("pointerup", (e) => {
      dragging = false;
      try { handle.releasePointerCapture(e.pointerId); } catch (_) {}
    });

    const addBtn = mkBtn("➕ Add page", "#43a25a");
    const saveBtn = mkBtn("⤓ Save all (0)", "#5865F2");
    const copyBtn = mkBtn("📋 Copy JSON", "#8b5cf6");
    const resetBtn = mkBtn("🗑 Reset", "#4f545c");
    const debugBtn = mkBtn("\u{1F50E} Debug", "#4f545c");
    // always-visible readout: which page (press count) and how many msgs so far.
    const counts = document.createElement("div");
    counts.style.cssText =
      "font:600 12px system-ui,sans-serif;color:#fff;background:rgba(0,0,0,.4);box-sizing:border-box;width:100%;" +
      "padding:5px 8px;border-radius:6px;margin-top:6px;text-align:center;";
    const status = document.createElement("div");
    status.style.cssText =
      "font:500 11px system-ui,sans-serif;color:#fff;background:rgba(0,0,0,.55);box-sizing:border-box;width:100%;" +
      "padding:4px 8px;border-radius:6px;margin-top:6px;text-align:center;display:none;word-break:break-word;";

    const setStatus = (t) => { status.style.display = "block"; status.textContent = t; };
    const refreshCounts = () => {
      counts.textContent = `page ${getAdds()} · ${storeCount()} msgs`;
      saveBtn.textContent = `⤓ Save all (${storeCount()})`;
    };

    // Add the page currently on screen to the running collection.
    addBtn.onclick = async () => {
      addBtn.disabled = true;
      try {
        setStatus("reading page…");
        const rows = await scrape((n) => setStatus(`reading… ${n}`));
        const store = loadStore();
        let added = 0;
        for (const r of rows) {
          if (r.id && !store[r.id]) { store[r.id] = r; added++; }
        }
        saveStore(store);
        setAdds(getAdds() + 1);          // one press = one page
        refreshCounts();
        const total = Object.keys(store).length;
        setStatus(added
          ? `page ${getAdds()}: +${added} new (of ${rows.length}) — total ${total}`
          : `page ${getAdds()}: +0 new — same page? (total ${total})`);
      } catch (e) {
        setStatus("error: " + e.message);
        console.error("[DSE]", e);
      } finally {
        addBtn.disabled = false;
      }
    };

    // Save everything collected so far as ONE deduped file.
    saveBtn.onclick = () => {
      const rows = Object.values(loadStore())
        .sort((a, b) => (a.timestamp || "").localeCompare(b.timestamp || ""));
      if (!rows.length) { setStatus("nothing collected yet — click Add page"); return; }
      const out = { channel: { name: "search: from:durracktu" }, messages: rows };
      download(`discord-search_all_${rows.length}.json`, out);
      setStatus(`saved ${rows.length} messages`);
    };

    // Copy the whole collection to the clipboard as ready-to-ingest JSON.
    copyBtn.onclick = async () => {
      const rows = Object.values(loadStore())
        .sort((a, b) => (a.timestamp || "").localeCompare(b.timestamp || ""));
      if (!rows.length) { setStatus("nothing collected yet"); return; }
      const json = JSON.stringify({ channel: { name: "search: from:durracktu" }, messages: rows });
      const ok = await copyText(json);
      setStatus(ok
        ? `copied ${rows.length} msgs (${json.length} chars) — paste into Notepad, save as .json`
        : "copy failed — tell Claude");
    };

    resetBtn.onclick = () => {
      if (!window.confirm("Clear the collected pages from this browser?\n(does not touch files you already saved)")) return;
      saveStore({});
      setAdds(0);
      refreshCounts();
      setStatus("collection cleared");
    };

    debugBtn.onclick = () => {
      try {
        const info = debugDump();
        setStatus(info.foundScroller ? `debug saved (${info.contentNodeCount} rows visible)` : "no results pane found");
      } catch (e) {
        setStatus("debug error: " + e.message);
      }
    };

    panel.appendChild(handle);
    panel.appendChild(counts);
    panel.appendChild(status);
    panel.appendChild(debugBtn);
    panel.appendChild(resetBtn);
    panel.appendChild(saveBtn);
    panel.appendChild(copyBtn);
    panel.appendChild(addBtn);
    document.body.appendChild(panel);
    refreshCounts();       // show current page + total on (re)mount
  }

  // Discord is a SPA; keep the buttons present across route changes.
  mountUI();
  new MutationObserver(() => { if (!document.getElementById("dse-panel")) mountUI(); })
    .observe(document.body, { childList: true, subtree: false });
})();
