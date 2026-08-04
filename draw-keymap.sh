#!/usr/bin/env bash
# Render every layer of this keymap to docs/keymap.svg for reading.
#
# Uses keymap-drawer, which runs the same preprocessing ZMK does -- so all
# the #include and #define indirection in config/os/** is expanded before
# parsing. Hold-taps, mod-morphs and combos are picked up automatically.
#
#   pip install keymap-drawer
#   ./draw-keymap.sh
#
# Web alternative (no install): https://caksoylar.github.io/keymap-drawer
set -euo pipefail
cd "$(dirname "$0")"

command -v keymap >/dev/null || { echo "keymap-drawer not installed: pip install keymap-drawer" >&2; exit 1; }

mkdir -p docs

# -c 12 = total columns, so layers are grouped as a 6+6 split
keymap parse -c 12 -z config/corne.keymap > docs/keymap.yaml

# The corne lookup in keymap-drawer's catalog doesn't resolve, so state the
# physical layout explicitly: 3x6 split plus 3 thumbs per side.
python3 - <<'PY'
p = "docs/keymap.yaml"
s = open(p).read()
old = "layout: {zmk_keyboard: corne, layout_name: default_layout}"
new = "layout: {ortho_layout: {split: true, rows: 3, columns: 6, thumbs: 3}}"
if old in s:
    s = s.replace(old, new, 1)
    open(p, "w").write(s)
PY

keymap draw docs/keymap.yaml > docs/keymap.svg
echo "wrote docs/keymap.yaml and docs/keymap.svg"
