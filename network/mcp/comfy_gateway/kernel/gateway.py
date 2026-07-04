"""Comfy MCP gateway.

Runs a local FastMCP streamable-http server for Valheim mod development:

  python -m comfy_gateway.kernel.gateway --providers comfy_gateway.toolsurface.valheim,comfy_gateway.toolsurface.inference

Default endpoint: http://127.0.0.1:8720/mcp
Auth header: X-Comfy-Key
"""

from __future__ import annotations

import argparse
import importlib
import inspect
import json
import logging
import time
import typing
from pathlib import Path
from typing import Any, Callable, Optional

from mcp.server.fastmcp import FastMCP
from starlette.responses import JSONResponse

from comfy_gateway.kernel.auth import HEADER_NAME, AuthRegistry
from comfy_gateway.kernel.context import ComfyContext
from comfy_gateway.kernel.ledger import REPO_ROOT, Ledger, new_event

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8720
BUILTIN_PROVIDER = "comfy_gateway.kernel.gateway#builtin"

log = logging.getLogger("comfy.gateway")


def make_header_key_provider(mcp: FastMCP) -> Callable[[], Optional[str]]:
    def provider() -> Optional[str]:
        try:
            request = mcp.get_context().request_context.request
        except (ValueError, LookupError):
            return None
        if request is None or not hasattr(request, "headers"):
            return None
        return request.headers.get(HEADER_NAME)
    return provider


def make_task_id_provider(mcp: FastMCP) -> Callable[[], Optional[str]]:
    def provider() -> Optional[str]:
        try:
            meta = mcp.get_context().request_context.meta
        except (ValueError, LookupError):
            return None
        if meta is None:
            return None
        task_id = getattr(meta, "task_id", None)
        if task_id is None:
            extra = getattr(meta, "model_extra", None) or {}
            task_id = extra.get("task_id")
        return str(task_id) if task_id is not None else None
    return provider


def _resolved_signature(fn: Callable) -> tuple[inspect.Signature, dict]:
    sig = inspect.signature(fn)
    try:
        hints = typing.get_type_hints(fn)
    except Exception:
        hints = {}
    params = [
        param.replace(annotation=hints.get(param.name, param.annotation))
        for param in sig.parameters.values()
    ]
    return sig.replace(
        parameters=params,
        return_annotation=hints.get("return", sig.return_annotation),
    ), hints


def make_wrapper(
    fn: Callable,
    context: ComfyContext,
    auth: AuthRegistry,
    key_provider: Callable[[], Optional[str]],
    task_id_provider: Callable[[], Optional[str]],
) -> Callable:
    tool_name = fn.__name__
    sig, hints = _resolved_signature(fn)

    def wrapper(**kwargs: Any) -> Any:
        started = time.perf_counter()
        caller = auth.resolve(key_provider())
        if caller is None:
            raise PermissionError(f"unknown or missing {HEADER_NAME} key")
        context.caller = caller
        task_id = task_id_provider()

        def elapsed_ms() -> float:
            return (time.perf_counter() - started) * 1000.0

        result, ok, error = None, True, None
        try:
            result = fn(**kwargs)
            return result
        except Exception as exc:
            ok, error = False, f"{type(exc).__name__}: {exc}"
            raise
        finally:
            context.ledger.append(new_event(
                caller.as_dict(),
                tool_name,
                args=kwargs,
                result=result,
                ok=ok,
                error=error,
                duration_ms=elapsed_ms(),
                task_id=task_id,
            ))

    wrapper.__name__ = tool_name
    wrapper.__qualname__ = tool_name
    wrapper.__doc__ = fn.__doc__
    wrapper.__signature__ = sig  # type: ignore[attr-defined]
    wrapper.__annotations__ = dict(hints)
    return wrapper


def builtin_get_tools(context: ComfyContext, mounted: list[str]) -> list[Callable]:
    def comfy_gateway_status() -> dict[str, Any]:
        """Return gateway identity, mounted providers, ledger path, and caller."""
        return {
            "kernel": "comfy_gateway",
            "repo_root": str(context.repo_root),
            "providers": list(mounted),
            "ledger_dir": str(context.ledger.dir),
            "event_count": len(context.ledger.query(limit=1000000)),
            "caller": context.caller.as_dict() if context.caller else None,
        }

    return [comfy_gateway_status]


def load_providers(spec: str) -> dict[str, list[Callable]]:
    providers: dict[str, list[Callable]] = {}
    for name in filter(None, (part.strip() for part in spec.split(","))):
        module = importlib.import_module(name)
        get_tools = getattr(module, "get_tools", None)
        if not callable(get_tools):
            raise ValueError(f"provider {name!r} has no get_tools()")
        providers[name] = list(get_tools())
    return providers


def build_server(
    providers_spec: str = "",
    host: str = DEFAULT_HOST,
    port: int = DEFAULT_PORT,
    callers_path: Optional[Path | str] = None,
    ledger_dir: Optional[Path | str] = None,
) -> FastMCP:
    ledger = Ledger(ledger_dir)
    context = ComfyContext(repo_root=REPO_ROOT, ledger=ledger)
    auth = AuthRegistry(callers_path=callers_path, ledger=ledger)

    mcp = FastMCP("comfy-gateway")
    mcp.settings.host = host
    mcp.settings.port = port

    @mcp.custom_route("/healthz", methods=["GET"])
    async def healthz(request):  # noqa: ANN001
        return JSONResponse({"ok": True, "gateway": "comfy-gateway"})

    @mcp.custom_route("/valheim/report", methods=["GET"])
    async def valheim_report(request):  # noqa: ANN001
        from comfy_gateway.toolsurface.valheim import valheim_networksense_report

        sample_count = int(request.query_params.get("sample_count", "30"))
        return JSONResponse(valheim_networksense_report(sample_count=sample_count))

    @mcp.custom_route("/valheim/next-test", methods=["GET"])
    async def valheim_next_test(request):  # noqa: ANN001
        from comfy_gateway.toolsurface.valheim import valheim_suggest_next_test

        sample_count = int(request.query_params.get("sample_count", "30"))
        return JSONResponse(valheim_suggest_next_test(sample_count=sample_count))

    @mcp.custom_route("/valheim/config-suggestion", methods=["GET"])
    async def valheim_config_suggestion(request):  # noqa: ANN001
        from comfy_gateway.toolsurface.valheim import valheim_suggest_config

        sample_count = int(request.query_params.get("sample_count", "30"))
        return JSONResponse(valheim_suggest_config(sample_count=sample_count))

    @mcp.custom_route("/valheim/apply-profile", methods=["POST"])
    async def valheim_apply_profile(request):  # noqa: ANN001
        from comfy_gateway.toolsurface.valheim import valheim_apply_config_profile

        try:
            body = await request.body()
            payload = json.loads(body.decode("utf-8")) if body else {}
        except json.JSONDecodeError:
            payload = {}
        profile = str(payload.get("profile") or request.query_params.get("profile") or "default_dev")
        return JSONResponse(valheim_apply_config_profile(profile=profile))

    key_provider = make_header_key_provider(mcp)
    task_id_provider = make_task_id_provider(mcp)

    providers = load_providers(providers_spec)
    mounted = [BUILTIN_PROVIDER, *providers]
    providers[BUILTIN_PROVIDER] = builtin_get_tools(context, mounted)

    registered: set[str] = set()
    for module_name, tools in providers.items():
        for fn in tools:
            if fn.__name__ in registered:
                log.warning("duplicate tool %s from %s skipped", fn.__name__, module_name)
                continue
            mcp.add_tool(make_wrapper(fn, context, auth, key_provider, task_id_provider))
            registered.add(fn.__name__)
    log.info("comfy gateway: %d tools from %d providers", len(registered), len(providers))
    return mcp


def main(argv: Optional[list[str]] = None) -> None:
    parser = argparse.ArgumentParser(description="Comfy Valheim development MCP gateway")
    parser.add_argument(
        "--providers",
        default="comfy_gateway.toolsurface.valheim,comfy_gateway.toolsurface.inference",
    )
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--callers", default=None)
    parser.add_argument("--ledger-dir", default=None)
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
    mcp = build_server(
        providers_spec=args.providers,
        host=args.host,
        port=args.port,
        callers_path=args.callers,
        ledger_dir=args.ledger_dir,
    )
    mcp.run(transport="streamable-http")


if __name__ == "__main__":
    main()
