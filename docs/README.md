# Documentation map

This directory holds the repo's understanding, method, strategy, and architecture. It is the best
entry point when you want to understand *why* something was built before opening its implementation.

## Read by intent

- **Core thesis:** [`kernel.md`](kernel.md), then [`community-insights.md`](community-insights.md).
- **Human lenses:** [`perspectives/README.md`](perspectives/README.md).
- **Reusable method:** [`method/the-lens-first-playbook.md`](method/the-lens-first-playbook.md), with
  the conversation ledger and extract beside it.
- **Adoption and governance:** [`positioning.md`](positioning.md),
  [`adoption-strategy.md`](adoption-strategy.md), and [`governance.md`](governance.md).
- **Built quest slice:** [`quest-vertical-slice-architecture.md`](quest-vertical-slice-architecture.md).
- **Base-layer and lab plans:** [`comfy-base-layer-architecture-plan.md`](comfy-base-layer-architecture-plan.md),
  [`thesis-gold-local-lab-plan.md`](thesis-gold-local-lab-plan.md), and
  [`lumberjacks-native-runtime-era-save-plan.md`](lumberjacks-native-runtime-era-save-plan.md).
- **Repository periodization:** [`repo-map/HOTSPOTS.md`](repo-map/HOTSPOTS.md) and the
  [interactive activity heatmap](repo-map/index.html).

## What belongs here

Use `docs/` for explanations and decisions that cross implementation boundaries. Runnable code,
operator commands, raw evidence, and generated data belong in their corresponding `handoffs/`,
`fieldlab/`, `network/`, `recipes/`, or `data/` area.
