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

sys.exit(fail)
PY
echo "keymap check passed"
