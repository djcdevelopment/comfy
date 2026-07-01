# Mikers demo: Slayer rank proof

This demo shows the control-surface path as Mikers would feel it: rank proof becomes a rep-readable
review and a Slayer command draft.

## Import

From the repo root:

```powershell
python .\handoffs\comfy-control-surface\bridge-consumer\bridge_consumer.py `
  .\handoffs\comfy-control-surface\bridge-consumer\mikers-demo
```

## Review

```powershell
python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  .\handoffs\comfy-control-surface\bridge-consumer\mikers-demo list

python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  .\handoffs\comfy-control-surface\bridge-consumer\mikers-demo show 20260701-210000-slayer-rank-thrall-demo
```

## Accept and export

```powershell
python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  .\handoffs\comfy-control-surface\bridge-consumer\mikers-demo accept 20260701-210000-slayer-rank-thrall-demo

python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  .\handoffs\comfy-control-surface\bridge-consumer\mikers-demo export 20260701-210000-slayer-rank-thrall-demo
```

Expected export command:

```text
/slayer submit rank:Thrall proof:evidence/20260701-210000-slayer-rank-thrall-demo.png
```

## In-game action fixture

`actions.slayer-rank.json` shows the intended control-surface actions for the first three known Slayer
ranks: Thrall, Thegn, and Jarl.

