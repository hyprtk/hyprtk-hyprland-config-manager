# hyprtk-config-manager — Plan

A Hyprland configuration manager for the hyprtk desktop suite.
Qt/QML (Quickshell) front end, Python backend, **Lua-first** (Hyprland 0.55+).

Status: M0 complete (2026-10-22) — read path, scanner, write primitives, RPC, CLI, first GUI
Owner: Kori Tk (hyprtk)
Location: `/home/hyprtk/Projects/AI-Projects/config-manager/`
Vendored into: `hyprtk-merged/installer/config-manager/` → `dotfiles` + live via `push-all`

---

## 0. M0 delivered (2026-10-22)

What actually exists now:

- `backend/config_manager/data/prelude.lua` — recording `hl` stub (known API +
  callable/indexable proxy for unknown namespaces such as `hl.dsp.window.close()`),
  provenance via `debug.getinfo`, dependency-free JSON encoder.
- `lua_probe.py` — runs the real module chain, normalizes calls into the model
  (config, curves, animations, binds, monitors, rules, gestures, env, exec,
  unknown) with per-item sources.
- `lua_scan.py` — comment/string-aware masking, call spans, nested key paths,
  surgical replace/insert, `require("animations-*")` flipping.
- `lua_edit.py` — `set_config`, `set_animation`, `set_curve` (bézier + spring),
  `set_animations_mode`.
- `state.py` — per-file backups, atomic writes, `Session` (sequential verified
  edits, byte-identical rollback), restore/prune.
- `verify.py` — one-probe semantic verification of config/animation/curve/require
  expectations after a write.
- `rpc.py` + `cli.py` — `dump/get/set/apply/validate/backup/bar/serve/open`.
- Quickshell GUI — sidebar, schema-driven option pages with pending changes and
  Apply, Animations page (curves, preview canvas, tree, bar mirror).
- 37 unit/integration tests, including a two-edit apply on a temp copy of the
  real `hyprtk-merged/hypr` tree.

Verified against `hyprtk-merged/hypr`: probes clean (12 modules, 4 curves,
8 animation leaves, 66 binds, 13 env vars, 1 monitor, 8 rules); a dry-run of
`set decoration.rounding 14` produces a one-line diff in `decoration.lua`.

---
---

## 1. Why this exists

Hyprland 0.55 replaced `hyprlang` with **Lua** (`hyprland.lua` + `hl.*` API).
The existing GUIs are either Lua-blind or Lua-adjacent:

| | HyprMod | HyprViz | **hyprtk-config-manager** |
|---|---|---|---|
| Toolkit | GTK4 / libadwaita (Python) | GTK4 / Rust | **Qt6 / QML (Quickshell)** + Python |
| Config syntax | hyprlang, early Lua migrate/edit | hyprlang only (0.54.2; Lua is a TODO) | **Lua-native, both read and write** |
| Write model | own `hyprland-gui.conf`, never touches yours | edits `hyprland.conf` in place | **edits the owning module in place** (AST-lite, backups) |
| Modular `require()` trees | partial | partial | **first-class module provenance** |
| Live preview | yes (`hyprctl`) | yes | **in-app preview; apply on save** |
| Curves | Bézier editor | curve editor | Bézier **+ spring**, with preview |
| Extra | profiles, undo, rules, keybinds | full option coverage, i18n | pages below, plus hyprtk bar animation settings |

The gap we fill: **nobody edits a modular Lua Hyprland tree surgically and safely.**
HyprMod's override model is safe but blind to what your modules already set;
HyprViz can't read Lua at all. hyprtk's config is exactly the modular-Lua shape
that breaks both.

---

## 2. Goals / non-goals

### Goals
- Read the **effective** Hyprland config by executing the real `hyprland.lua`
  module chain with a recording `hl` stub — not by regex-parsing it.
- Know **which file and line** every value came from (provenance).
- Write changes back to the file that owns them, preserving comments,
  formatting, and the surrounding Lua (surgical span replacement).
- Never lose a working config: backup → write → re-execute → compare →
  auto-restore on mismatch.
- Ship as a hyprtk app: Quickshell window, pywal-aware theme, desktop entry,
  CLI for scripting/keybinds.
- Absorb the **Animations** page currently in `hyprtk-bar-qt` Settings.

### Non-goals (v1)
- Wi-Fi/Bluetooth/printing/default apps/GTK theming (control-center territory).
- Hyprland ≤0.54 hyprlang files. Read-only warning if found.
- Plugin management (`hyprpm`) — later.
- Editing running state through IPC. We write files, then `hyprctl reload`;
  the GUI animates previews itself.
- Hot-reload of arbitrary running values from `hyprctl getoption`.

---

## 3. Architecture

```
┌──────────────────────────── Quickshell (Qt6/QML) ───────────────────────────┐
│  shell.qml → PanelWindow (centered, focusable, ExclusionMode.Ignore)        │
│  surface/Main.qml   sidebar + page stack + pending-changes bar              │
│  surface/pages/*.qml  Animations · General · Decoration · Monitors ·        │
│                       Input · Keybinds · Rules                              │
│  components/  SRow, TCheckBox, TComboBox, TSpinBox, TColor, TBezier, …      │
│  config/Config.qml  app prefs (window size, last page, animation preview)   │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │ JSON-lines over stdio (Quickshell Process)
┌───────────────────────────────▼─────────────────────────────────────────────┐
│  backend/config_manager                                                     │
│  rpc.py      request/response router                                        │
│  lua_probe.py  run real modules under a recording `hl` stub (provenance)     │
│  lua_scan.py   comment/string-aware scanner: brace spans, key paths          │
│  lua_edit.py   span replacement / key insertion, syntax + semantic verify   │
│  schema.py     page & option metadata (types, ranges, labels, lua paths)    │
│  state.py      backups, pending changes, undo/redo                          │
│  writers/hypr.py  write Lua modules                                         │
│  writers/bar.py   write hyprtk-bar-qt config.json animation keys            │
│  cli.py      dump · schema · get · set · validate · backup · restore · serve│
└─────────────────────────────────────────────────────────────────────────────┘
                                │
                    ~/.config/hypr/*.lua   ~/.config/hyprtk-bar-qt/config.json
```

### 3.1 Read path — execute, don't parse

`lua_probe.py` launches `lua5.4` with a prelude that defines a recording `hl`:

- `hl.config(t)`, `hl.curve(n,t)`, `hl.animation(t)`, `hl.bind(...)`,
  `hl.monitor(t)`, `hl.window_rule(t)`, `hl.layer_rule(t)`,
  `hl.workspace_rule(t)`, `hl.gesture(t)`, `hl.env(k,v)`, `hl.exec*`, `hl.on(...)`
- unknown `hl.*` names are caught by a metatable `__index` recorder, so a new
  API call never crashes the probe.
- every call records `debug.getinfo(2, "Sl")` → `source`, `currentline`
  (provenance), plus the raw argument table.
- `package.path` includes the hypr dir; the main file is `dofile`d inside
  `pcall`; the prelude serializes calls to JSON on stdout (small JSON encoder,
  no third-party deps).

Python then normalizes the call log into a model:

```json
{
  "root": "/home/hyprtk/.config/hypr",
  "main": "hyprland.lua",
  "requires": ["environment", "autostart", "input", "..."],
  "config": {"general": {"gaps_in": 5}, "decoration": {...}},
  "curves": {"wind": {"type": "bezier", "points": [[0.05,0.9],[0.1,1.05]]}},
  "animations": {"windows": {"enabled": true, "speed": 6, "bezier": "wind", "style": "slide"}},
  "binds": [...], "monitors": [...], "rules": {...}, "env": [...], "exec": [...],
  "provenance": [{"call": "config", "file": "/home/hyprtk/.config/hypr/decoration.lua", "line": 12}],
  "error": null
}
```

Why this beats parsing: `require()` order, variables, conditionals, loops, and
computed values all resolve exactly as Hyprland resolves them. A `gaps_in`
written as `gaps_in = base + 2` needs no special case.

### 3.2 Write path — surgical, verified, reversible

1. **Locate** — from provenance, the owning file + the call span (brace-matched
   from the recorded line, comment/string aware).
2. **Patch** — replace the value token for an existing key, or insert
   `key = value` before the table's closing brace, keeping indentation. Whole
   call rewritten only when the table shape must change.
3. **Verify syntax** — `lua5.4 -e "assert(loadfile(path))"`.
4. **Verify semantics** — re-run `lua_probe`; assert the effective value equals
   the requested value. If not (shadowing by a later module, conditional, etc.),
   report the conflict and suggest the file that actually wins.
5. **Commit or roll back** — on success keep an atomic write + backup record;
   on failure restore the byte-identical original.

Backups: `~/.config/hyprtk-config-manager/backups/<UTC-stamp>/<relpath>` plus a
`manifest.json` (reason, files, values). Undo/redo replays backups.

Writes are **debounced and explicit**: page edits accumulate as *pending
changes*; `Apply` runs the pipeline; `Revert` drops them. Closing with pending
changes prompts.

### 3.3 Provenance is the core abstraction

Every option in the UI is `(file, line, call, key_path)`. That one tuple powers:
- correct-owner writes (no override-file guessing),
- "where is this set?" (jump-to-line in the editor),
- conflict detection when two modules set the same key,
- the Pending Changes diff.

### 3.4 Live preview

Preview stays in the GUI: the animation page animates a mock window with the
selected curve/speed; decoration/monitor pages render a schematic. Saving runs
`hyprctl reload` and re-probes. We deliberately do **not** push transient values
into the compositor (avoids state that isn't in any file and can desync).

---

## 4. Module map (hyprtk tree)

```
~/.config/hypr/hyprland.lua      entry: require(...) chain
  environment.lua                hl.env
  autostart.lua                  hl.on("hyprland.start", …) / hl.exec
  input.lua                      hl.config({ input = … })
  monitors.lua                   hl.monitor({ … })
  window.lua                     hl.config({ general = … })
  decoration.lua                 hl.config({ decoration = … })
  layouts.lua                    hl.config({ dwindle = …, master = … })
  misc.lua                       hl.config({ misc = … })
  keybindings.lua                hl.bind(…)
  windowrules.lua                hl.window_rule(…) / layer / workspace
  nvidia.lua                     env + config
  animations-high.lua            hl.curve + hl.animation   ← active
  animations-low.lua             alternate set
```

The bar's `animations.mode` (`low|high|custom`) selects which file wins: the
entry file keeps one `require("animations-*")` line active and the other
commented. **Switching mode from the manager flips that require line** rather
than duplicating animation data.

Manager is hyprtk-first but generic-aware:
- known module names get friendly grouping and the right page,
- unknown `hl.*` calls still appear (read-only "Discovered" section),
- a non-hyprtk tree with a single `hyprland.lua` works with generic discovery.

---

## 5. Pages (v1)

| Page | Contents | Source |
|---|---|---|
| **Animations** | curves (Bézier + spring), per-leaf tree (windows, border, fade, workspaces, layers, zoom…), enabled/speed/style, live preview, low/high/custom mode, **bar** border + UI animation settings (moved from bar-qt) | `animations-*.lua`, `hyprland.lua`, bar `config.json` |
| **General** | gaps in/out, border size, layout, resize/rotate, snap, float, cursor | `window.lua` (`general`) |
| **Decoration** | rounding, opacity, blur (size/passes), shadow, dim, border colours (pywal/manual/gradient) | `decoration.lua` |
| **Monitors** | visual layout editor, mode/refresh, scale, position, transform, VRR, 10-bit, mirror | `monitors.lua` |
| **Input** | kb layout/variant/options, repeat, numlock, touchpad (tap, natural scroll, accel), mouse sensitivity/accel, gestures | `input.lua` (`input`, `device`) |
| **Keybinds** | grouped list, key capture, dispatcher/args, `bindm`, flags, search/filter | `keybindings.lua` |
| **Rules** | window / layer / workspace rules, match builder, preview | `windowrules.lua` |

Post-v1: profiles, env/autostart page, hyprlock/hypridle/hyprpaper pages,
plugin manager.

### 5.1 Animations move-out from bar-qt

Bar settings keys today (`hyprtk-bar-qt/config.json`):

```json
"theme": { "border_animation": true },
"animations": { "mode": "high", "speed": 15 },
"uiAnimations": true, "animationDuration": 140
```

Plan:
1. Config-manager gains a **Bar** group in the Animations page that reads/writes
   those keys via `writers/bar.py` (atomic read-modify-write, same as
   `barsettings.py`).
2. `surface/Settings.qml` in bar-qt drops the Animations page; leaves a row
   "Hyprland & animation settings → Open Config Manager" launching
   `config-manager --page animations`.
3. `backend/hyprtk_bar_qt/hypr_animations.py` stays (the bar still mirrors the
   effective border speed); it becomes a consumer only. Its unit tests stay.
4. Bar reload: `config.json` writes bump `mtime`; the bar's `Config.qml`
   `FileView` reloads on change (confirm during M4).

---

## 6. Repo layout

```
config-manager/
  shell.qml                  Quickshell entry (single settings window)
  surface/                   Main.qml, PageRouter, pages/
  components/                T*, SRow, preview widgets
  config/Config.qml          app prefs (independent of bar config)
  theme/                     pywal-derived palette
  backend/config_manager/    Python backend (toolkit-free, no deps)
    lua_probe.py             run modules + normalize the call log
    lua_scan.py              mask/comments/strings, spans, key paths
    lua_edit.py              set_config / set_animation / set_curve / require flip
    verify.py                post-write semantic checks (single probe)
    state.py                 Session, backups, atomic writes, restore/prune
    schema.py                page + option metadata
    rpc.py cli.py            JSON-lines RPC and the CLI
    writers/bar.py           bar config.json animation keys (atomic RMW)
    data/prelude.lua         recording `hl` stub + JSON encoder
  bin/config-manager         launcher (PYTHONPATH + python -m config_manager.cli)
  tests/                     unittest (probe, scan, edit, schema, session, real tree)
  scripts/                   dev run, sandbox copy, smoke (empty at M0)
  data/                      desktop entry; generated snapshots later
  README.md PLAN.md CHANGELOG.md
```

Conventions copied from `hyprtk-bar-qt`: toolkit-free Python backend, JSON-lines
IPC over `Quickshell.Io.Process`, `unittest` (not pytest), GPL-2.0-only,
pywal theme with `#c084fc` / `#22d3ee` accents.

---

## 7. CLI

```bash
config-manager                    # open GUI
config-manager --page animations  # open a page
config-manager dump [--json]      # effective model
config-manager schema             # page/option metadata
config-manager get decoration.rounding
config-manager set decoration.rounding 12 [--dry-run]
config-manager validate           # syntax + probe; exit 1 on error
config-manager backup list|create|restore <stamp>
config-manager serve              # JSON-lines RPC (used by QML)
```

`set` never silently edits the wrong file: it resolves provenance first and
prints the target file/line, then verifies after writing.

---

## 8. Testing

- **Unit** (`python3 -m unittest discover -s tests`):
  - `lua_probe`: fixture tree with `require` chain, helper function, computed
    value, shadowed key → correct effective model + provenance.
  - `lua_scan`: comments/strings containing braces and `key =`; nested tables.
  - `lua_edit`: replace existing, insert new, preserve comments, refuse
    ambiguous keys, round-trip parse.
  - `state`: backup/restore byte-identical, undo/redo.
  - `schema`: every option path resolves in a real hyprtk model dump.
- **Golden**: probe the real `hyprtk-merged/hypr` tree, snapshot normalized
  model, review diffs on Hyprland config changes.
- **Integration**: copy tree to temp → `set` several values across modules →
  `validate` → probe → compare → restore. Never test against the live tree.
- **QML smoke**: `qs -p .` opens the window, every page instantiates, backend
  request/response works; kill all dev instances afterwards.

---

## 9. Milestones

### M0 — scaffold — DONE (2026-10-22)
Repo, plan, package skeleton, recording `hl` probe + normalized model, scanner +
edits for config/animation/curve/require, backups, JSON-lines RPC, CLI, minimal
Quickshell window with a live Animations read-out and editable option pages.

**Acceptance (met):** `config-manager dump` returns the correct effective model
for `hyprtk-merged/hypr`; `get decoration.rounding` = 10; `set` dry-run shows a
one-line diff; `python3 -m unittest` 37/37 green; `qs -p .` loads and the live
read-out shows `ok · 12 modules · 8 animations`.

### M1 — read + write core
Provenance-based writes for scalars/booleans/colours/enums, syntax + semantic
verify, auto-rollback, pending changes + undo. Unit + integration tests.

**Acceptance:** `set` on a temp copy changes exactly one span in the owning
file, re-probe reflects it, backup restores byte-identically.

### M2 — Animations page (first real UI)
Bézier/spring curve editor with preview, animation tree table, mode switch
(`require` flip), custom speed. Wire `hl.curve`/`hl.animation` writes.

**Acceptance:** edit a curve + speed in the GUI → Apply → `animations-high.lua`
diff is minimal → preview matches → `hyprctl reload` succeeds.

### M3 — bar animation move
Bar group in Animations page; remove the page from bar-qt Settings and add the
launcher row; keep `hypr_animations.py` as consumer; bar reloads on write.

**Acceptance:** bar border speed follows manager edits; bar Settings has no
Animations page; bar-qt tests still green.

### M4 — General, Decoration, Monitors
Option schema + widgets, colour picker (pywal-aware), monitor layout canvas,
VRR/scale/transform; `hyprctl monitors -j` used for display names only.

### M5 — Input, Keybinds, Rules
Key capture, dispatcher catalog, bind flags, rule builders, search.

### M6 — hardening + release
Golden-model test against merged, QML smoke in CI, packaging/vendoring,
desktop entry, `push-all` integration, docs.

---

## 10. Vendoring & install

Follow the bar/usb/ISO model:

1. Develop here (`hyprtk-config-manager`, own git repo).
2. Vendor byte-identically:
   `git -C config-manager archive HEAD | tar -x -C hyprtk-merged/installer/config-manager`
3. `push-all` carries it to `dotfiles` + live.
4. Installer places:
   - backend → `~/.local/share/hyprtk-config-manager/`
   - launcher → `~/.local/bin/config-manager`
   - desktop entry → `~/.local/share/applications/hyprtk-config-manager.desktop`
   - QML runs directly from the installed share dir (`qs -p <dir>`).
5. Add a keybind in `keybindings.lua` (`SUPER, C` or similar — decide at M4) and
   a bar quicklink/menu entry.

Never patch the vendored copy; fix here and re-vendor.

---

## 11. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Surgical Lua edits corrupt config | brace/string-aware scanner, syntax check, semantic re-probe, auto-rollback, backups |
| Setting shadowed by a later module | provenance + verify: report the winning file instead of silently writing a dead value |
| Hyprland Lua API drift | callable/indexable proxy accepts unknown `hl.*` namespaces; golden dump catches changes |
| Spring field name drift (`damping` vs `dampening`) | preserve the key already in the file when updating; use `damping` for new curves, revisit at M2 against the installed Hyprland |
| Probing executes user Lua | config is trusted code at the user's privilege level (same as Hyprland); the backend never requires root |
| bar-qt/bar config both writing `config.json` | single writer module, atomic read-modify-write, mtime reload |
| Quickshell QML churn | pin to Quickshell 0.3.2 semantics; window is one PanelWindow, no exotic APIs |
| Edit model can't represent keybinds/rules cleanly | list-shaped editors are M5; the write engine is span-based, not whole-file regeneration |
| Hyprland ≤0.54 users | detect missing `hyprland.lua`, show a clear read-only notice |

---

## 12. Open decisions

- Keybind for launching (`SUPER, C` collides with common apps — pick at M4).
- Whether profiles ship in v1.x (likely yes, after M5).
- Whether animations mode `custom` becomes a third file (`animations-custom.lua`)
  or stays bar-only. Current plan: bar-only, Hyprland keeps low/high.
