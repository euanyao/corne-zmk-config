#!/usr/bin/env bash
# Offline sanity check for the keymap, for when a real ZMK build isn't handy.
#
# Runs the C preprocessor over config/corne.keymap against stubbed ZMK
# headers, then checks the expanded result for the mistakes that actually
# break builds:
#
#   - unresolved #include
#   - a layer whose binding count isn't 42
#   - a &behavior that is referenced but never defined
#   - keymap node order not matching the indices in layers.dtsi
#   - a typing layer shadowing the OS flag at a position it binds
#
# It does NOT validate devicetree semantics -- only GitHub Actions does
# that. Treat a pass as "worth flashing", not "correct".
set -euo pipefail
cd "$(dirname "$0")"

STUB=$(mktemp -d)
trap 'rm -rf "$STUB"' EXIT
mkdir -p "$STUB/dt-bindings/zmk"
: > "$STUB/behaviors.dtsi"
: > "$STUB/physical_layouts.dtsi"
for h in keys bt rgb; do : > "$STUB/dt-bindings/zmk/$h.h"; done

OUT="$STUB/expanded.dts"
cpp -nostdinc -undef -x assembler-with-cpp -P \
    -I "$STUB" -I config \
    config/corne.keymap -o "$OUT"

python3 - "$OUT" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
fail = 0

# 1. every layer must bind exactly 42 keys
layers = re.findall(r'display-name\s*=\s*"(\w+)";\s*bindings\s*=\s*<(.*?)>;', src, re.S)
if not layers:
    print("FAIL  no layers found -- preprocessing probably broke"); fail = 1
for name, body in layers:
    n = len(re.findall(r'&\w+', body))
    if n != 42:
        print(f"FAIL  layer {name}: {n} bindings, expected 42"); fail = 1
print(f"ok    {len(layers)} layers, all 42 bindings" if not fail else "")

# 2. every referenced &behavior must be defined somewhere
defined = set(re.findall(r'^\s*(\w+)\s*:\s*\w+\s*\{', src, re.M))
defined |= set(re.findall(r'(\w+)\s*:\s*\w+\s*\{', src))
builtin = {
    'kp','mo','to','tog','trans','none','sl','lt','mt','bt','rgb_ug','out',
    'bootloader','sys_reset','studio_unlock','caps_word','key_repeat','none',
    'macro_press','macro_release','macro_tap','macro_pause_for_release',
    'macro_wait_time','macro_tap_time','soft_off','ext_power',
    # provided by the board/shield, not by this repo
    'default_transform','key_physical_attrs','led_strip',
}
used = set(re.findall(r'&(\w+)', src))
missing = sorted(used - defined - builtin)
if missing:
    print(f"FAIL  referenced but never defined: {', '.join(missing)}"); fail = 1
else:
    print(f"ok    all {len(used)} referenced behaviors resolve")

# 3. keymap node order must match the indices in layers.dtsi. ZMK assigns
#    layer numbers by node order, so a reordered node silently changes
#    which layer wins at a position, and the WIN flag's placement relative
#    to the typing layers is load bearing (see assertion 4).
import pathlib
decl = pathlib.Path("config/os/shared/layers.dtsi").read_text()
want = [
    m.group(1)
    for m in sorted(
        re.finditer(r"^#define\s+(\w+)\s+(\d+)", decl, re.M),
        key=lambda m: int(m.group(2)),
    )
]
got = [n for n, _ in layers]
if want != got:
    print(f"FAIL  layer order\n        layers.dtsi: {want}\n        keymap:      {got}")
    fail = 1
else:
    print(f"ok    layer order matches layers.dtsi: {' '.join(got)}")

# 4. The OS flag sits BELOW the typing layers so the OLED shows the layer
#    in use rather than permanently reading "WIN". That only resolves
#    correctly while DEV/AXN/FNK stay transparent everywhere WIN binds --
#    give one of them a real binding at position 0, 11 or 12 and Windows
#    word-delete silently stops working. STG is exempt: it legitimately
#    overrides those positions, and word-delete isn't wanted there.
byname = dict(layers)
if "WIN" in byname:
    win = re.findall(r"&\w+[^&]*", byname["WIN"])
    bound = [i for i, b in enumerate(win) if not b.strip().startswith("&trans")]
    leaks = []
    for name in ("DEV", "AXN", "FNK"):
        if name not in byname:
            continue
        binds = re.findall(r"&\w+[^&]*", byname[name])
        for p in bound:
            if not binds[p].strip().startswith("&trans"):
                leaks.append(f"{name} position {p} = {binds[p].strip()}")
    if leaks:
        print("FAIL  WIN is shadowed, word-delete will break:")
        for l in leaks:
            print(f"        {l}")
        fail = 1
    else:
        print(f"ok    WIN unshadowed at positions {bound} across DEV/AXN/FNK")

sys.exit(fail)
PY
echo "keymap check passed"
