# Discord Search Exporter (local)

A tiny, auditable Chrome/Edge extension that exports **your own** Discord search
results to a JSON file **on your machine** — by reading what's already rendered
on your screen. No account token, no API calls, no server, nothing leaves your
computer.

It exists because the usual ways to bulk-export Discord (self-token tools,
giving an AI full browser control) ask you to trust something you can't see.
This asks you to trust ~150 lines you can read in two minutes.

## Why it's safe (and how to verify)

- **No permissions.** Open `manifest.json` — there is no `permissions` or
  `host_permissions` block. The only capability it has is a content script that
  runs on `discord.com`. It can't touch other sites, tabs, cookies, or storage.
- **No network.** Open `content.js` and search for `fetch`, `XMLHttpRequest`,
  `WebSocket`, `sendBeacon`, or any `http` URL. There are none. The only output
  is a normal browser file download.
- **No background page.** Nothing runs when you're not on Discord.

The extension literally can only: read text on a discord.com page, and save it
as a file you choose to download.

## Install (load unpacked)

1. Go to `chrome://extensions` (or `edge://extensions`).
2. Turn on **Developer mode** (top-right).
3. Click **Load unpacked** and select this folder.
4. Open Discord in the browser and run a search (e.g. `from:yourname`).

A draggable panel appears bottom-left (drag it via the `⠿` handle so it never
covers Discord's page controls).

## Use

Discord search is **paginated** (25 results per page), so the tool works
page-by-page and accumulates into one collection that survives reloads.

1. Run your search in Discord so the results pane is showing (e.g. `from:durracktu`).
2. Click **🔎 Debug** first (optional). It saves `discord-export-debug.json` —
   page *structure* only (tag + class names, text *lengths*, no message text), so
   it's safe to share if selectors need tuning for your Discord version.
3. On each results page, click **➕ Add page**. The status chip shows
   `+N new — total M`. Then click Discord's next page and Add again. Repeat to
   the last page.
   - `+0 new` means that page was already collected (a duplicate) — normal if you
     click Add twice; a red flag if it happens on a fresh page (pagination didn't
     advance).
   - The **⤓ Save all (M)** button shows the running total at all times.
   - Progress is stored in the browser, so a reload won't lose it.
4. When the total stops growing, click **⤓ Save all (M)** once. It downloads a
   single deduped `discord-search_all_<M>.json`.
5. **🗑 Reset** clears the in-browser collection (it does not touch saved files) —
   use it before starting a brand-new search.

### If Add page finds 0 messages

Discord ships obfuscated CSS class names and occasionally changes its DOM. Click
**Debug**, share the resulting `discord-export-debug.json` (structure only, no
content), and the selectors at the top of `content.js` (`SEL = {...}`) can be
retuned. The ones keyed on stable hooks — `message-content-<id>` and
`<time datetime>` — rarely change.

## Output format

DiscordChatExporter-compatible, so it plugs straight into the anonymizing
pipeline in `../comfy-tugcow-analysis/ingest_dce.py`:

```json
{
  "channel": { "name": "search: from:durracktu" },
  "messages": [
    { "id": "...", "timestamp": "2023-04-01T14:22:00.000Z",
      "author": { "name": "durracktu" }, "content": "...",
      "channelName": "self-promotion", "link": "https://discord.com/channels/..." }
  ]
}
```

Then locally:

```
py ingest_dce.py --input discord-search-export.json --author durracktu
```

which scrubs @mentions / emails / invite links / any names you list, and emits
the anonymized `source-tugcow-messages.csv` for analysis.

## Limitations

- Exports **only your own messages** if your search is `from:you` — which is the
  point (you can't export other people's DMs, and shouldn't).
- Relies on Discord's rendered DOM; a major Discord redesign may need a selector
  refresh (see the Debug step).
- One search at a time. Re-run per search query.

## License / sharing

No personal data lives in this folder — it's a generic tool. Free to share.
