# M2 guest package evidence

This evidence records the machine-checkable M2 proxy. It does not close the human enrollment criterion.

- Sealed artifact: M1 clean-build DLL SHA-256 `94a3843ef8042adceaca6bc4d5c0c38c7c8dc5a1aa05b5f2a3019879840ba3a8`.
- Generator: two independent output roots produced identical `guest-index.json` and zip hashes.
- Bundle regression: both promoted M0 and M1 release bundles validated successfully.
- Install invariant: the synthetic Valheim tree restored the original cfg bytes and unrelated plugin after receipt-driven uninstall.
- Fault matrix: wrong DLL hash, missing BepInEx, running game, empty enrollment id, unreachable Gateway, failing TLS validation, unwritable config path, and consumed bootstrap token each produced a distinct failed check with a remedy.
- Guide: `render_guest_guide.py --check` passed; a scratch manifest version mutation returned non-zero.
- Diagnostics: redacted output was re-scanned and contained no prohibited identity or credential-shaped values.

The real “non-developer completes enrollment through READY TO JOIN” exit criterion remains open because it requires a second human and a second Steam license.
