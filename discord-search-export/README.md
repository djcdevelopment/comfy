# Discord Search Exporter (local)

A small, auditable Chrome/Edge extension for exporting Discord search results
that you own or are authorized to use. It reads only the search-result messages
already rendered in the browser and produces JSON locally.

This is a private collaborator handoff, not a public release. Start with
`START-HERE.html`; it contains the complete install, use, privacy, debugging,
and local-agent guide.

## Responsible use

- Export only content you own or have explicit authorization to use.
- Prefer a narrow search such as `from:yourname`.
- Treat exported JSON as sensitive: it can contain message text, usernames,
  timestamps, channel names, and Discord links.
- Redact or anonymize output before sharing it.
- Never share Discord tokens, cookies, credentials, invite links, private
  diagnostic URLs, or raw exports with a support agent.
- Do not publish or redistribute this package without the owner's permission.

The extension shows a confirmation before the first collection action in each
page session. That is a reminder, not a technical ownership check.

## Trust model

Open `manifest.json` and `content.js` before installing:

- The manifest declares no `permissions`, `host_permissions`, background page,
  or service worker.
- The content script is matched only to `discord.com`.
- The source contains no `fetch`, `XMLHttpRequest`, `WebSocket`, or
  `sendBeacon` calls.
- The extension does have access to Discord's rendered page while it is loaded.
- Accumulated results are stored in Discord-origin `localStorage` under
  `dse_accumulator_v1` and `dse_adds_v1` until Reset is used.
- Save creates a browser download. Copy writes the export JSON to the clipboard.

No design can make raw message exports harmless. The safety boundary is local,
auditable operation plus responsible handling of the resulting data.

## Install

1. Extract the private ZIP.
2. Open `chrome://extensions` or `edge://extensions`.
3. Enable **Developer mode**.
4. Choose **Load unpacked**.
5. Select the extracted `extension` folder containing `manifest.json`.
6. Open or reload Discord in the browser.

## Quick start

1. Run a narrow Discord search, preferably `from:yourname`.
2. Optionally click **Debug** to confirm the results pane is detectable.
3. Click **Add page**, read the responsible-use reminder, and confirm.
4. Use Discord's next-page control and click **Add page** again.
5. Repeat until the last page. Re-adding a page is harmless; results dedupe by
   message ID.
6. Click **Save all** for a JSON download or **Copy JSON** for clipboard output.
7. Click **Reset** after finishing, especially on a shared computer.

The collection survives reloads. Reset clears the browser collection but does
not delete downloaded files or clipboard history.

## Controls

- **Debug** downloads `discord-export-debug.json` and logs `[DSE debug]` in the
  browser console. Version 2 omits message text, raw DOM IDs, raw control labels,
  and raw Discord snowflakes. Review every diagnostic before sharing it.
- **Reset** clears the accumulated results and page counter after confirmation.
- **Save all (N)** downloads one timestamp-sorted, deduplicated JSON file.
- **Copy JSON** copies the same collection as compact JSON.
- **Add page** reads the currently rendered results page and accumulates it.

## Output

The output is compatible with the common DiscordChatExporter message shape:

```json
{
  "channel": { "name": "search: from:yourname" },
  "messages": [
    {
      "id": "1234567890",
      "timestamp": "2026-01-01T12:00:00.000Z",
      "author": { "name": "yourname" },
      "content": "Example message",
      "channelName": "example-channel",
      "link": "https://discord.com/channels/..."
    }
  ]
}
```

## Debugging

Open browser developer tools on the Discord tab and select **Console**:

- `[DSE debug]` is the structural diagnostic also saved to disk.
- `[DSE]` reports collection errors.
- Panel status text reports progress, missing results, duplicate pages, and
  clipboard/download outcomes.

If **Add page** finds zero messages, confirm the search results are visible and
that Discord actually advanced to the next page. If the debug report says
`foundScroller: false` or `contentNodeCount: 0`, Discord may have changed its
DOM. The selectors are isolated in `SEL` near the top of `content.js`.

Share only the smallest necessary, reviewed diagnostic. Do not send raw export
JSON merely to diagnose selectors.

## Limitations

- The extension does not verify message ownership or authorization.
- It can export any search result visible to the signed-in browser if the user
  deliberately confirms the reminder.
- Discord's obfuscated DOM classes can change and require selector maintenance.
- Discord pagination remains manual.
- It handles one accumulated search at a time.
- Reset does not remove already downloaded files.

## Remove

Use **Reset**, remove the unpacked extension from the browser's extensions page,
delete downloaded JSON/debug files you no longer need, and delete the extracted
package if appropriate.

See `START-HERE.html` for the full troubleshooting guide, extension map, audit
checklist, and privacy-preserving prompts for a local coding agent.
