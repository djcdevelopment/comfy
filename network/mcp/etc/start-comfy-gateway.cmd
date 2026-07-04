@echo off
setlocal
cd /d C:\work\comfy
set PYTHONPATH=C:\work\comfy\network\mcp
C:\work\commandcenter\fleet-worker-node\.venv-omen\Scripts\python.exe -m comfy_gateway.kernel.gateway --callers network\mcp\comfy_gateway\etc\callers.json --providers comfy_gateway.toolsurface.valheim,comfy_gateway.toolsurface.inference >> network\mcp\var\gateway-task.log 2>&1

