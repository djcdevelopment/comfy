# Repository working notes

## Lumberjacks / Valheim roadmap journal

Any non-merge commit that changes the Lumberjacks cutover program under `fieldlab/`,
`network/`, or `infra/gcp/p7/` must be represented on the living roadmap at
`C:\work\lumberjacks\src\Game.Gateway\Community\roadmap.html`.

After the Comfy commit, append a note from `C:\work\lumberjacks` with
`npm run roadmap:note -- ... --repository "Comfy"`, then commit the journal and
regenerated HTML together in Lumberjacks. Record the outcome, affected milestones,
user/runtime impact, verification, and evidence. The paired Lumberjacks journal
commit is the cross-repository audit record.

The roadmap is public. Never include SteamIDs, invite links, credentials, access
keys, passwords, or private diagnostic URLs.
