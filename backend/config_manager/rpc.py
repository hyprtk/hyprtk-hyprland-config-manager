"""JSON-lines RPC used by the Quickshell front end.

One request per line on stdin, one response per line on stdout:

    {"id": 1, "method": "dump", "params": {"root": "..."}}
    {"id": 1, "result": {...}}
    {"id": 1, "error": "message"}
"""

from __future__ import annotations

import json
import sys
import traceback
from pathlib import Path
from typing import Any, Callable

from . import lua_edit, pages, schema, state, verify
from .lua_probe import ProbeError, discover, probe
from .paths import find_hypr_dir
from .writers import bar as bar_writer


class RpcError(RuntimeError):
    pass


def _root(params: dict) -> Path:
    root = params.get("root")
    if root:
        return Path(root).expanduser()
    found = find_hypr_dir()
    if found is None:
        raise RpcError("no hyprland.lua found (pass root or set HYPR_CM_DIR)")
    return found


def _model(params: dict) -> dict:
    return probe(_root(params))


def _get(params: dict) -> Any:
    path = str(params.get("path") or "")
    model = _model(params)
    node: Any = model["config"]
    for part in path.split("."):
        if not isinstance(node, dict) or part not in node:
            raise RpcError(f"{path} is not set")
        node = node[part]
    return {"path": path, "value": node}


def _dump(params: dict) -> dict:
    return _model(params)


def _schema(params: dict) -> dict:
    """Dynamic sections from the real tree; static fallback if it won't probe."""
    try:
        root = _root(params)
        return pages.build(root)
    except (ProbeError, OSError):
        return schema.schema()


def _module_dump(params: dict) -> dict:
    root = _root(params)
    name = str(params.get("file") or params.get("module") or "")
    if not name:
        raise RpcError("no module given")
    rel = name if name.endswith(".lua") else f"{name}.lua"
    target = (root / rel)
    try:
        target.resolve().relative_to(root.resolve())
    except ValueError as exc:
        raise RpcError(f"{rel} is outside {root}") from exc
    if not target.is_file():
        raise RpcError(f"{rel} does not exist")
    return {"file": rel, "model": probe(root, main=rel)}


def _validate(params: dict) -> dict:
    try:
        model = _model(params)
    except ProbeError as exc:
        return {"ok": False, "error": str(exc), "raw": exc.raw}
    return {
        "ok": model.get("error") is None,
        "error": model.get("error"),
        "requires": model["requires"],
    }


def _apply(params: dict) -> dict:
    root = _root(params)
    edits = params.get("edits") or []
    if not isinstance(edits, list) or not edits:
        raise RpcError("no edits")

    reason = str(params.get("reason") or "config-manager apply")
    session = state.Session(root, reason)
    specs: list[dict] = []
    diffs: list[dict] = []
    notes: list[str] = []

    try:
        for item in edits:
            kind = item.get("type")
            if kind == "config":
                edit = lua_edit.set_config(root, item["path"], item["value"], kind=item.get("kind"))
                specs.append({"type": "config", "path": item["path"], "value": item["value"]})
            elif kind == "animation":
                edit = lua_edit.set_animation(
                    root, item["leaf"], item["key"], item["value"],
                    kind=item.get("kind"), module=item.get("module")
                )
                spec = {"type": "animation", "leaf": item["leaf"], "key": item["key"],
                        "value": item["value"]}
                if item.get("module"):
                    spec["main"] = edit.relpath
                specs.append(spec)
            elif kind == "curve":
                spec = item.get("spec") or {}
                edit = lua_edit.set_curve(root, item["name"], spec, module=item.get("module"))
                check = {"type": "curve", "name": item["name"], "spec": spec}
                if item.get("module"):
                    check["main"] = edit.relpath
                specs.append(check)
            elif kind == "env":
                edit = lua_edit.set_env(root, item["key"], item["value"])
                specs.append({"type": "env", "key": item["key"], "value": item["value"]})
            elif kind == "animations_mode":
                edit = lua_edit.set_animations_mode(root, item["mode"])
                specs.append({"type": "require", "module": f"animations-{item['mode']}"})
            else:
                raise RpcError(f"unknown edit type: {kind!r}")

            if edit.changed:
                session.write(edit)
            notes.append(edit.note)

        verify.verify_specs(root, specs)
    except BaseException as exc:
        session.rollback()
        session.finish("rolled-back", str(exc))
        raise

    import difflib

    for rel, original in session.saved.items():
        final = (root / rel).read_text(encoding="utf-8")
        if final != original:
            diffs.append({
                "file": rel,
                "diff": "".join(difflib.unified_diff(
                    original.splitlines(keepends=True),
                    final.splitlines(keepends=True),
                    fromfile=f"a/{rel}", tofile=f"b/{rel}",
                )),
            })

    manifest = session.finish("ok")
    return {
        "ok": True,
        "files": session.files,
        "backup": manifest,
        "diffs": diffs,
        "notes": notes,
    }


def _bar_get(params: dict) -> dict:
    return bar_writer.get(Path(params["path"]) if params.get("path") else bar_writer.BAR_CONFIG)


def _bar_set(params: dict) -> dict:
    path = Path(params["path"]) if params.get("path") else bar_writer.BAR_CONFIG
    updates = params.get("updates") or {}
    before = bar_writer.get(path)
    data = bar_writer.update(updates, path)
    return {"ok": True, "before": before, "after": bar_writer.get(path), "config": data}


def _backups_list(params: dict) -> list[dict]:
    return state.backups()


def _backups_restore(params: dict) -> dict:
    stamp = str(params.get("stamp") or "")
    root = params.get("root")
    return state.restore(stamp, root=Path(root).expanduser() if root else None)


HANDLERS: dict[str, Callable[[dict], Any]] = {
    "dump": _dump,
    "get": _get,
    "validate": _validate,
    "apply": _apply,
    "schema": _schema,
    "module.dump": _module_dump,
    "pages": lambda p: schema.pages(),
    "bar.get": _bar_get,
    "bar.set": _bar_set,
    "backups.list": _backups_list,
    "backups.restore": _backups_restore,
}


def handle(request: dict) -> dict:
    rid = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    try:
        fn = HANDLERS.get(str(method))
        if fn is None:
            raise RpcError(f"unknown method: {method!r}")
        return {"id": rid, "result": fn(params)}
    except (RpcError, ProbeError, lua_edit.EditError, verify.VerifyError, state.TransactionError) as exc:
        return {"id": rid, "error": str(exc)}
    except Exception as exc:  # noqa: BLE001 - report, never kill the session
        traceback.print_exc(file=sys.stderr)
        return {"id": rid, "error": f"{type(exc).__name__}: {exc}"}


def serve() -> int:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError as exc:
            print(json.dumps({"id": None, "error": f"bad json: {exc}"}), flush=True)
            continue
        response = handle(request if isinstance(request, dict) else {})
        print(json.dumps(response), flush=True)
    return 0


def main() -> int:
    return serve()
