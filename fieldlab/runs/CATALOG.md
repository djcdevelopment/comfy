# FieldLab Run Catalog

Generated for release `m0-clean-20260716-r2` (M0/A3). Machine-readable source of truth: [index.json](index.json).

Every run folder is classified with the fixed roadmap vocabulary. Runs are immutable evidence; classification never edits or deletes a run.

| Class | Count | Meaning |
|---|---|---|
| gold | 1 | Directly backs the validated hash-recorded P7 baseline. |
| negative | 17 | Recorded failure/blocked result kept as negative evidence. |
| superseded | 37 | Re-proven by a newer run of the same or stronger scenario. |
| historical | 70 | Era-bound (July 4-10 Era16 / early bootstrap / i-era) evidence, not load-bearing. |

## Gold

- `20260716-011112-valheim-lumberjacks-authoritative-priority-cutover` - validated hash-recorded P7 baseline (83,220/83,220 authoritative priority ZDO cutover)

## Negative evidence

- `20260704-061853-lumberjacks-native-runtime-smoke` - command_plan_failed
- `20260704-061921-lumberjacks-native-runtime-smoke` - blocked_missing_database
- `20260704-062038-lumberjacks-native-runtime-smoke` - blocked_missing_database
- `20260704-063121-lumberjacks-native-runtime-smoke` - blocked_missing_database
- `20260704-063525-lumberjacks-native-runtime-smoke` - command_plan_failed
- `20260704-063626-lumberjacks-native-runtime-smoke` - blocked_missing_database
- `20260704-063822-lumberjacks-native-runtime-smoke` - blocked_missing_database
- `20260704-064816-lumberjacks-native-runtime-smoke` - fail_probe
- `20260704-073020-lumberjacks-native-runtime-smoke` - command_plan_failed
- `20260704-073145-lumberjacks-native-runtime-smoke` - command_plan_failed
- `20260704-083529-valheim-era16-volunteer-readiness-baseline` - baseline_incomplete
- `20260705-224940-lumberjacks-native-runtime-smoke` - fail_probe
- `20260708-072234-valheim-lumberjacks-priority-mirror` - fail_priority_mirror_post
- `20260708-072837-valheim-lumberjacks-priority-mirror` - blocked_eventlog_database_unavailable
- `20260708-072940-valheim-lumberjacks-priority-mirror` - blocked_eventlog_database_unavailable
- `20260708-073029-valheim-lumberjacks-priority-mirror` - blocked_eventlog_database_unavailable
- `20260708-092311-valheim-lumberjacks-priority-gateway-plan` - blocked_gateway_priority_endpoint

## Superseded

- `20260704-055835-thesis-gold-progressive-enhancement` superseded by `20260704-060120-thesis-gold-progressive-enhancement`
- `20260704-060120-thesis-gold-progressive-enhancement` superseded by `20260704-061025-thesis-gold-progressive-enhancement`
- `20260704-061025-thesis-gold-progressive-enhancement` superseded by `20260704-061329-thesis-gold-progressive-enhancement`
- `20260704-061329-thesis-gold-progressive-enhancement` superseded by `20260704-062338-thesis-gold-progressive-enhancement`
- `20260704-071715-lumberjacks-native-runtime-smoke` superseded by `20260704-071907-lumberjacks-native-runtime-smoke`
- `20260704-071907-lumberjacks-native-runtime-smoke` superseded by `20260704-073300-lumberjacks-native-runtime-smoke`
- `20260704-083637-valheim-era16-volunteer-readiness-baseline` superseded by `20260704-083714-valheim-era16-volunteer-readiness-baseline`
- `20260704-083714-valheim-era16-volunteer-readiness-baseline` superseded by `20260704-085746-valheim-era16-volunteer-readiness-baseline`
- `20260704-084803-valheim-era16-teleport-rehearsal` superseded by `20260704-085020-valheim-era16-teleport-rehearsal`
- `20260704-085020-valheim-era16-teleport-rehearsal` superseded by `20260704-085758-valheim-era16-teleport-rehearsal`
- `20260704-085746-valheim-era16-volunteer-readiness-baseline` superseded by `20260704-085944-valheim-era16-volunteer-readiness-baseline`
- `20260704-085758-valheim-era16-teleport-rehearsal` superseded by `20260704-085956-valheim-era16-teleport-rehearsal`
- `20260704-085944-valheim-era16-volunteer-readiness-baseline` superseded by `20260704-092258-valheim-era16-volunteer-readiness-baseline`
- `20260704-085956-valheim-era16-teleport-rehearsal` superseded by `20260704-090559-valheim-era16-teleport-rehearsal`
- `20260704-090559-valheim-era16-teleport-rehearsal` superseded by `20260704-092306-valheim-era16-teleport-rehearsal`
- `20260704-092258-valheim-era16-volunteer-readiness-baseline` superseded by `20260704-092354-valheim-era16-volunteer-readiness-baseline`
- `20260704-092306-valheim-era16-teleport-rehearsal` superseded by `20260704-092402-valheim-era16-teleport-rehearsal`
- `20260705-225728-valheim-lumberjacks-bridge-feasibility` superseded by `20260705-230043-valheim-lumberjacks-bridge-feasibility`
- `20260705-230043-valheim-lumberjacks-bridge-feasibility` superseded by `20260705-230109-valheim-lumberjacks-bridge-feasibility`
- `20260705-230109-valheim-lumberjacks-bridge-feasibility` superseded by `20260706-011710-valheim-lumberjacks-bridge-feasibility`
- `20260706-011710-valheim-lumberjacks-bridge-feasibility` superseded by `20260706-011747-valheim-lumberjacks-bridge-feasibility`
- `20260706-011747-valheim-lumberjacks-bridge-feasibility` superseded by `20260706-013136-valheim-lumberjacks-bridge-feasibility`
- `20260706-013136-valheim-lumberjacks-bridge-feasibility` superseded by `20260706-013316-valheim-lumberjacks-bridge-feasibility`
- `20260706-013316-valheim-lumberjacks-bridge-feasibility` superseded by `20260706-014633-valheim-lumberjacks-bridge-feasibility`
- `20260706-015719-valheim-lumberjacks-shadow-authority` superseded by `20260707-205433-valheim-lumberjacks-shadow-authority`
- `20260707-210807-valheim-lumberjacks-shadow-route` superseded by `20260707-224720-valheim-lumberjacks-shadow-route`
- `20260707-224720-valheim-lumberjacks-shadow-route` superseded by `20260708-001549-valheim-lumberjacks-shadow-route`
- `20260708-001549-valheim-lumberjacks-shadow-route` superseded by `20260708-022138-valheim-lumberjacks-shadow-route`
- `20260708-032738-valheim-lumberjacks-priority-load-order` superseded by `20260708-032910-valheim-lumberjacks-priority-load-order`
- `20260708-032910-valheim-lumberjacks-priority-load-order` superseded by `20260708-033021-valheim-lumberjacks-priority-load-order`
- `20260708-033021-valheim-lumberjacks-priority-load-order` superseded by `20260708-035932-valheim-lumberjacks-priority-load-order`
- `20260708-035932-valheim-lumberjacks-priority-load-order` superseded by `20260708-040111-valheim-lumberjacks-priority-load-order`
- `20260708-040111-valheim-lumberjacks-priority-load-order` superseded by `20260708-041345-valheim-lumberjacks-priority-load-order`
- `20260708-041345-valheim-lumberjacks-priority-load-order` superseded by `20260708-041510-valheim-lumberjacks-priority-load-order`
- `20260708-041510-valheim-lumberjacks-priority-load-order` superseded by `20260708-042140-valheim-lumberjacks-priority-load-order`
- `20260708-042140-valheim-lumberjacks-priority-load-order` superseded by `20260708-042303-valheim-lumberjacks-priority-load-order`
- `20260708-084141-valheim-lumberjacks-priority-live-mirror` superseded by `20260708-091406-valheim-lumberjacks-priority-live-mirror`

## Historical

Era-bound July 4-10 work: thesis-gold bootstrap, native runtime smoke, Era16 density/readiness/teleport, dead Docker autonomous-lab topology, yolo swarm, i-era probe workspaces, and the final successful run of each early scenario.

- `20260704-054718-thesis-gold-progressive-enhancement`
- `20260704-055804-thesis-gold-progressive-enhancement`
- `20260704-060200-thesis-gold-progressive-enhancement`
- `20260704-060549-thesis-gold-progressive-enhancement`
- `20260704-062338-thesis-gold-progressive-enhancement`
- `20260704-070538-lumberjacks-native-runtime-smoke`
- `20260704-072542-lumberjacks-native-runtime-smoke`
- `20260704-073300-lumberjacks-native-runtime-smoke`
- `20260704-080802-era16-density-pressure-matrix`
- `20260704-080822-era16-density-pressure-matrix`
- `20260704-080932-era16-density-pressure-matrix`
- `20260704-083053-valheim-era16-volunteer-readiness-baseline`
- `20260704-083118-valheim-era16-volunteer-readiness-baseline`
- `20260704-083203-valheim-era16-volunteer-readiness-baseline`
- `20260704-083305-valheim-era16-volunteer-readiness-baseline`
- `20260704-083332-valheim-era16-volunteer-readiness-baseline`
- `20260704-083415-valheim-era16-volunteer-readiness-baseline`
- `20260704-083454-valheim-era16-volunteer-readiness-baseline`
- `20260704-084952-valheim-era16-teleport-rehearsal`
- `20260704-092029-valheim-autonomous-lab`
- `20260704-092040-valheim-autonomous-lab`
- `20260704-092053-valheim-autonomous-lab`
- `20260704-092113-valheim-autonomous-lab`
- `20260704-092127-valheim-autonomous-lab`
- `20260704-092140-valheim-autonomous-lab`
- `20260704-092208-valheim-autonomous-lab`
- `20260704-092241-valheim-autonomous-lab`
- `20260704-092251-valheim-autonomous-lab`
- `20260704-092257-valheim-autonomous-lab`
- `20260704-092353-valheim-autonomous-lab`
- `20260704-092354-valheim-era16-volunteer-readiness-baseline`
- `20260704-092402-valheim-era16-teleport-rehearsal`
- `20260704-092441-valheim-autonomous-lab`
- `20260704-092944-valheim-autonomous-lab`
- `20260704-092950-valheim-autonomous-lab`
- `20260704-093016-valheim-autonomous-lab`
- `20260704-093117-valheim-autonomous-lab`
- `20260704-093201-valheim-autonomous-lab`
- `20260704-094427-valheim-autonomous-lab`
- `20260704-095039-valheim-autonomous-lab`
- `20260704-100820-valheim-autonomous-lab`
- `20260704-101421-valheim-autonomous-lab`
- `20260704-102122-valheim-autonomous-lab`
- `20260704-102358-valheim-autonomous-lab`
- `20260704-103801-valheim-yolo-swarm`
- `20260704-103822-valheim-yolo-swarm`
- `20260704-103854-valheim-yolo-swarm`
- `20260704-105016-valheim-yolo-swarm`
- `20260704-105050-valheim-yolo-swarm`
- `20260704-113501-valheim-yolo-swarm`
- `20260704-141320-era16-density-pressure-matrix`
- `20260704-142501-valheim-era16-volunteer-readiness-baseline`
- `20260706-014633-valheim-lumberjacks-bridge-feasibility`
- `20260707-205433-valheim-lumberjacks-shadow-authority`
- `20260708-022138-valheim-lumberjacks-shadow-route`
- `20260708-032718-valheim-lumberjacks-priority-load-order`
- `20260708-040041-valheim-lumberjacks-priority-load-order`
- `20260708-042303-valheim-lumberjacks-priority-load-order`
- `20260708-043315-valheim-lumberjacks-priority-mirror`
- `20260708-071750-valheim-lumberjacks-priority-mirror`
- `20260708-075942-valheim-lumberjacks-priority-mirror`
- `20260708-091406-valheim-lumberjacks-priority-live-mirror`
- `20260708-101308-valheim-lumberjacks-priority-gateway-plan`
- `20260708-104818-valheim-lumberjacks-priority-gateway-plan`
- `20260708-121319-valheim-era16-teleport-rehearsal`
- `20260709-053502-valheim-autonomous-lab`
- `i1`
- `i1-airtight`
- `i2-observe`
- `manual-tcp-probe`
