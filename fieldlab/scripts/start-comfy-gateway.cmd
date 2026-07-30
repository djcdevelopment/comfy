@echo off
rem comfy-gateway boot-start wrapper -- same posture as commandcenter's
rem hearth\etc\start-hearth-gateway.cmd, which this deliberately mirrors.
rem Registered as scheduled task "ComfyGatewayBoot" (boot trigger, OMEN\derek, S4U).
rem
rem WHY THIS EXISTS (ADR-0028, commandcenter): comfy-gateway used to run as the
rem Docker service comfy-valheim-lab-comfy-gateway-1, and Docker's
rem `restart: unless-stopped` was its persistence. But a container cannot reach the
rem host's loopback, so giving it Ollama meant COMFY_OLLAMA=http://host.docker.internal
rem and OLLAMA_HOST=0.0.0.0 on the host -- which put an unauthenticated inference
rem server on every interface. Running natively removes that pressure entirely
rem (the gateway's own DEFAULT_ENDPOINT is already http://127.0.0.1:11434), and it
rem binds 127.0.0.1:8720 instead of the container's 0.0.0.0:8720. This wrapper is
rem what replaces the restart policy.
rem
rem The .ps1 beside this file is the interactive/foreground equivalent; keep the two
rem in step if the provider list or port changes.
cd /d C:\work\comfy

rem PATH python is a broken Store stub -- use the real interpreter explicitly.
set "PY=C:\Users\derek\AppData\Local\Programs\Python\Python312\python.exe"
set "PYTHONPATH=C:\work\comfy\network\mcp"
set "PYTHONUTF8=1"

rem Optional gitignored secrets fragment, same convention as hearth\var\gateway.cmd.
rem MUST be .cmd (not .env): `call` only executes .bat/.cmd as batch.
if exist fieldlab\var\comfy-gateway.cmd call fieldlab\var\comfy-gateway.cmd

rem Boot-safe logging, inherited from the HEARTH wrapper's 2026-07-20 lesson: a stale
rem EXCLUSIVE handle on the log (a zombie gateway that died without releasing it) must
rem NEVER stop the gateway from starting. Redirecting straight to a fixed path meant
rem that when the path was locked, cmd could not open it, python never launched, and
rem the task exited 1 having written NOTHING to the log meant to explain it -- an
rem invisible ~40-minute outage. So: probe the primary log, retry a few times (a
rem bounce holds the old handle for a second or two, and retrying keeps normal
rem restarts consolidated on one file), and only if it is still wedged fall back to a
rem unique per-launch file so the redirect below can always open something.
rem The sleep is `ping`, not `timeout`: `timeout` aborts under redirected stdin.
if not exist fieldlab\var mkdir fieldlab\var
set "GWLOG=fieldlab\var\comfy-gateway-task.log"
set "_LOGTRY=0"
:comfy_trylog
(echo [%date% %time%] ComfyGatewayBoot task starting)>> "%GWLOG%" 2>nul && goto comfy_gotlog
set /a _LOGTRY+=1
if %_LOGTRY% lss 6 (ping -n 2 127.0.0.1 >nul & goto comfy_trylog)
set "GWLOG=fieldlab\var\comfy-gateway-task-%RANDOM%%RANDOM%.log"
:comfy_gotlog

"%PY%" -m comfy_gateway.kernel.gateway --providers comfy_gateway.toolsurface.valheim,comfy_gateway.toolsurface.inference,comfy_gateway.toolsurface.matrix --host 127.0.0.1 --port 8720 >> "%GWLOG%" 2>&1
echo [%date% %time%] ComfyGatewayBoot exited with %errorlevel% >> "%GWLOG%"
