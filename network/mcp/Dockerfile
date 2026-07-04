# Comfy MCP gateway image.
#
# Bakes the comfy_gateway package into the image instead of running it from a
# live bind mount. On Docker Desktop / Windows, bind-mounted source can be
# served stale by the container's page cache — editing a .py file on the host
# does not reliably invalidate what a long-running interpreter (or a fresh one
# started later) sees through the mount. Baking the code in means every
# rebuild ships exactly the source that was built, and `docker compose build`
# becomes the one required step after a code change.
#
# State (ledger, matrix plan/results, dev notes) and read-only telemetry
# inputs still come from host mounts — see valheim-lab.compose.yml, which
# sets COMFY_MCP_ROOT / COMFY_MATRIX_VAR_DIR / COMFY_VALHEIM_NOTES so those
# paths resolve under the mounted /workspace/network/mcp/var, not inside the
# image.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/workspace/network/mcp

RUN pip install --no-cache-dir "mcp==1.28.1" starlette

WORKDIR /workspace/network/mcp

COPY comfy_gateway ./comfy_gateway

ENTRYPOINT ["python", "-m", "comfy_gateway.kernel.gateway"]
