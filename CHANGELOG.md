# Changelog

## 0.2.0 — 2026-10-23 (M1 sections + M2 animations editing)

### Sections from the real tree
- Every `*.lua` file is now a sidebar section, ordered by the actual
  `require()` chain; files not loaded by `hyprland.lua` appear as inactive.
- `hyprland.lua` is a read-only "Load order" page; `animations-*` are collapsed
  into the Animations page.
- Options are assigned by provenance, so each setting appears under the file
  that owns it; extra known options can be added from curated metadata.
- Non-config modules show their discovered calls: env, binds, rules, monitors,
  exec and unknown `hl.*` calls.
- `hyprlock`/`hypridle` stay out of scope (bar themer owns them).

### Animations
- File dropdown targets `animations-high.lua` or `animations-low.lua`; edits are
  read from and written to the selected file (active file shown as a badge).
- "Make active" flips the `require("animations-*")` line.
- Editable curve list: bézier points or spring (mass/stiffness/damping), with a
  live preview; editable tree: enabled, speed, curve and style per leaf.
- Animation/curve verification probes the target file, so editing an inactive
  module cannot silently verify against the effective tree.
- Env values are editable per module (`hl.env`), adding the call when missing.

### UI
- Real dropdown component (QtQuick Controls Basic popup) for all combos.
- File/active badges and discovered lists on module pages; pending-changes bar
  accepts mixed config, animation, curve and env edits.

### Tests
- 44 tests: dynamic sections, provenance assignment, inactive animation-file
  targeting, standalone module probing, env edit/add, live-tree build.

## 0.1.0 — 2026-10-22 (M0 scaffold)

Initial scaffold for the hyprtk Hyprland configuration manager.

### Read path
- Recording `hl` prelude: executes the real `hyprland.lua` require chain,
  captures every call with file/line provenance, tolerates unknown API
  namespaces (`hl.dsp.*`).
- Normalized model: config, curves, animations, binds, monitors, window/layer/
  workspace rules, gestures, env, exec, unknown calls.

### Write path
- Comment/string-aware Lua scanner: call spans, nested key paths, inline and
  multi-line insertion.
- Editors: `set_config`, `set_animation`, `set_curve` (bézier + spring),
  `set_animations_mode` (flips the active `require("animations-*")`).
- `Session`: sequential edits, per-file backups, atomic writes, one-probe
  semantic verification, byte-identical rollback.
- Backups under `~/.config/hyprtk-config-manager/backups/<stamp>/`.

### Interfaces
- CLI: `dump`, `get`, `set [--dry-run]`, `apply`, `validate`, `schema`,
  `backup list|restore`, `bar get|set`, `serve`, `open`.
- JSON-lines RPC for the GUI.
- Quickshell window: sidebar, schema-driven option pages with pending changes
  and Apply, Animations page with curve preview, animation tree, bar mirror.

### Tests
- 37 unit/integration tests (probe, scan, edit, schema, session, real tree).
- Integration apply verified on a temp copy of `hyprtk-merged/hypr`.

### Notes
- `hyprtk-bar-qt` Animations move-out is planned for M3; this release only reads
  its animation keys.
