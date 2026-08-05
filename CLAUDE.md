# corne-zmk-config — working context

Context for agents picking this repo up mid-stream. Records what has been
**measured**, what has been **decided**, and what is still **open**, so the
analysis doesn't have to be redone.

Every claim below is tagged:
- **[verified]** — measured from this repo or run locally
- **[inferred]** — read off the config, not documented by the original author
- **[unverified]** — believed true, not confirmed in this environment

---

## 1. What this is

ZMK firmware config for a 42-key split Corne (3x6 + 3 thumbs per half).
Layout inherited from an upstream config (Camilo Martinez / Equiman — see
copyright headers in `config/helpers/*.dtsi`), **not** designed by the
current owner, who has only a few weeks on any ergo keyboard. **[verified]**

Consequence for design work: there is **no muscle memory worth preserving**.
Don't weight "matches current behaviour" highly. Simplicity and
learnability are worth more here than continuity.

### Hardware / build

| | |
|---|---|
| Board | `nice_nano//zmk`, shields `corne_left` / `corne_right` |
| Central | **left** (carries the studio snippet + USB UART) |
| Peripheral | **right** |
| Builds | GitHub Actions only — **no local ZMK toolchain, no `west`** |
| ZMK Studio | enabled (`-DCONFIG_ZMK_STUDIO=y`) |
| LEDs | 27 per half (21 per-key + 6 underglow) |

**The case covers the physical reset button.** Bootloader access via the
keymap is therefore safety-critical — losing it means losing the ability to
flash. **[verified — stated by owner]**

### Owner's devices

1 macOS work laptop, 2 Windows PCs (personal). OS mode is currently tied to
the **Bluetooth profile**: `m_s_b1..b3` → profiles 0-2 → Mac, `m_s_b4..b6`
→ profiles 3-5 → Windows, in `config/os/shared/macros/settings.dtsi`.
Worth rebalancing to 2 Mac / 4 Windows to match reality. **[verified]**

---

## 2. Requirements

From the owner, in priority order as given:

1. **Constant Windows/macOS switching.** Do not duplicate the same keys
   across two layer sets unless forced to.
2. **Dev-friendly base layer** — `/` is missing and needed. (`-` is
   arguably the other gap; currently DEV-only.)
3. **Review duplicate thumb layer-switch keys**; reclaim them for frequent
   keys such as space.
4. **Bootloader must be reachable from a layer** — reset button is blocked.
5. **Gaming layer for Windows**, likely needed in future.
6. **Avoid home-row mods where practical** — the hold timing is hard to get
   right. **Soft requirement.** Owner has said it can be ditched if
   dropping HRM is constrained by the key budget (21 keys/half) or works
   against split-keyboard ergonomics. See §7.1 — current evidence says
   ditch it and fix the config instead.

### Standing constraint

ZMK hard-caps at **32 layers** (uint32_t bitmask). Current usage is 10/32,
so the cap is *not* the binding constraint — **maintenance is**. Full
layer-set duplication for OS variants was explicitly rejected by the owner;
do not reintroduce it without a clear reason. Note the cap and the 42-key
count are independent: fewer physical keys pushes toward *more* layers.

---

## 3. Current architecture (as-is)

10 layers — 5 per OS, mirrored:

| macOS | Windows | purpose |
|---|---|---|
| mBAS (0) | wBAS (5) | QWERTY base + home-row mods |
| mDEV (1) | wDEV (6) | dev symbols |
| mAXN (2) | wAXN (7) | nav (left) + numpad (right) |
| mFNK (3) | wFNK (8) | F-keys + HOME/END/PgUp/PgDn |
| mSTG (4) | wSTG (9) | settings, BT, RGB, OS tooling |

Source layout: `config/os/{macos,windows,shared}/**`, assembled by
`config/corne.keymap`. Heavy `#define` indirection; helper macros in
`config/helpers/` generate hold-taps, mod-morphs and layer macros.

Host-side companions in `host/windows/ahk/` (layer/caps indicators) and
`host/android/automate/`. They watch F13–F18 signal keys emitted alongside
layer switches. **`F_mBAS` and `F_wBAS` are both `LS(F14)`** — the host
signals are already OS-agnostic, so merging layers does not break them.
**[verified]**

---

## 4. Measured findings

### 4.1 Mac/Windows divergence — 210 bindings (42 keys × 5 layer pairs)

| | count | |
|---|---:|---|
| identical | 131 | 62% |
| layer-ref only (`&to_mBAS`↔`&to_wBAS`) | 19 | mechanical |
| pure modifier swap (Ctrl↔Cmd, Alt↔Ctrl) | 26 | mechanical |
| **genuinely OS-specific** | **34** | — |

**22 of the 34 are in STG alone.** Outside STG, 168 bindings share 156 —
**93% identical**. Four duplicated layers exist to express ~12 keys.
**[verified]**

The irreducible non-STG set:

```
DEV[35]  Alt+Gui+I          ~  F12              browser devtools
AXN[1]   Ctl+Sft+Gui+RIGHT  ~  Alt+Sft+RIGHT    expand selection
AXN[13]  Ctl+Sft+Gui+LEFT   ~  Alt+Sft+LEFT     shrink selection
AXN[17]  Alt+Gui+F          ~  Ctl+H            replace
AXN[28]  Gui+V              ~  Ctl+V            paste
AXN[29]  Sft+Gui+Z          ~  Ctl+Y            redo
AXN[35]  =                  ~  Gui+Ctl+D        virtual desktop
AXN[22]  .                  ~  =                (looks like drift)
AXN[36], AXN[41]  empty     ~  ,  .             DRIFT — Mac never got them
FNK[36], FNK[41]  empty     ~  ,  .             DRIFT — Mac never got them
```

`DEV[35]` is free to fix: **F12 opens devtools on macOS too** in
Chrome/Edge/Firefox, so that difference can just be deleted — *if* browser
devtools was the intent; ⌘⌥I suggests it may have meant VS Code.
**[inferred]**

### 4.2 Drift is already happening

The four `, / .` entries above are Mac-side omissions, not design. Commits
like `a1b113f refactor: consistent outer columns across all typing layers`
are exactly the changes that must land twice. The duplication tax is being
paid today. **[verified]**

### 4.3 Layer occupancy

```
mBAS   0 empty      mDEV   0 empty      mAXN   2 empty (thumbs 36,41)
mFNK  16 empty      mSTG   2 empty
```

FNK is **38% dead**. Its real content is F1-F12 plus a 4-key nav cluster.
**[verified]**

### 4.4 Thumb map (macOS; Windows identical modulo prefix)

| layer | 36 | 38 tap | 38 hold | 39 tap | 39 hold | 41 |
|---|---|---|---|---|---|---|
| BAS | DEV *(mom)* | **AXN latch** | AXN mom | **FNK latch** | AXN mom | DEV *(mom)* |
| DEV | `,` | BAS | AXN mom | **AXN latch** | AXN mom | `.` |
| AXN | — | BAS | — | **FNK latch** | FNK mom | — |
| FNK | — | BAS | — | **AXN latch** | — | — |
| STG | BRI DN | BAS | — | **AXN latch** | — | BRI UP |

Read-outs **[inferred]**:
- Position 38 is "home" on every non-base layer. Consistent.
- Position 39 is "the other layer".
- On BAS, 38 and 39 **hold to the same thing** — that's the req-3 duplication.
- **The layout is already 2/3 momentary.** DEV and STG are momentary by
  default (`mp_m_dev`, `mp_m_stg`); latching needs shift. Only AXN and FNK
  latch by default.

---

## 5. The `&to` / OS-flag conflict — read this before proposing a merge

To collapse to one layer set, something must remember "I'm on Mac". ZMK's
only runtime state is **which layers are active**, so the OS flag must be a
layer (`MAC`) that stays lit.

ZMK layer-activation behaviours:

| | effect on other layers |
|---|---|
| `&mo LAYER` | on while held — leaves others alone |
| `&tog LAYER` | flips that layer — leaves others alone |
| `&to LAYER` | on, **and switches every other layer off** |

**This config uses `&to` for every sticky jump.** `&to` would wipe the MAC
flag on the first layer change, silently reverting word-delete and the STG
right half to Windows behaviour until the BT profile is re-selected.

So a persistent OS flag and `&to` are mutually exclusive. Confirmed dead
ends:

- **A single overlay can't fix the home-row mods** — to override DEV's mods
  it must sit above DEV, but then its BAS-flavoured taps leak onto DEV.
  One overlay per typing layer = no saving (11 layers, worse than 10).
- **`&tog` is not a drop-in for `&to`** — the config cross-navigates
  (DEV→AXN, AXN→FNK, FNK→AXN, STG→AXN), so tog stacks layers instead of
  switching. Tapping "go to FNK" from AXN leaves both on.
- **A macro re-asserting the flag after `&to`** needs a Mac-specific twin
  of every layer-switch key, and each layer's thumb has a different
  destination — one binding at position 38 can't be three things.

### Ways through

`&to` can be rebuilt from tog pairs, since the binding always lives on a
known source layer: `AXN: &to BAS` → `&tog AXN`; `DEV: &to AXN` →
`&tog DEV + &tog AXN`. ~10 small macros, in the style
`config/helpers/macros.dtsi` already uses. **[unverified — macros
containing `&tog` should be fine but were not built]**

**But the sideways routes don't earn their keep** (analysis below), and
removing them cuts this to a single `&tog AXN`.

### Sideways routes: verdict = drop them

1. With momentary layers, sideways is free — release thumb A, press thumb
   B. Routes only matter latched→latched.
2. Only AXN↔FNK is latched→latched; DEV and STG are momentary by default.
3. That pair exists because the **nav cluster is split** — arrows on AXN,
   HOME/END/PgUp/PgDn on FNK. It papers over fragmentation.
4. FNK is 38% empty and otherwise F1-F12, which are single presses.

Consolidate nav onto AXN → all four routes vanish → one `&tog AXN` → clean
4-state model (`BAS`, `BAS+MAC`, `BAS+AXN`, `BAS+MAC+AXN`), all reachable,
all escapable, no stuck states.

Self-inverse latch trick: put `&tog AXN` on BAS at position P and leave
AXN's P as `&trans`. Pressing P while latched falls through to BAS's own
binding and turns it off. One binding, both directions.

---

## 6. The macOS modifier remap (gates the merge)

The Ctrl↔Cmd home-row swap is what forces per-layer duplication. Kill it in
firmware by making the keymap **Windows-canonical** and remapping on the
Mac instead:

> System Settings → Keyboard → Keyboard Shortcuts… → Modifier Keys →
> **"Select keyboard"** → pick the Corne → swap ⌘ Command and ⌃ Control.

macOS applies this **per keyboard**, so the laptop's built-in keyboard is
unaffected. Configures 1 machine instead of 2. **[unverified — exact menu
path is from memory and has moved between macOS versions; no web access in
the session where this was written]**

Test without touching firmware: after the swap, hold the Corne's `A`
(currently `LCTRL` on the Mac layer) and press `C`. If text copies, it
works.

**Risks:** it's a work laptop, so MDM may lock the pane. Owner has said to
proceed **assuming it works**; if it turns out locked, the home-row
unification reverts and everything else still stands.

Residual after the remap: **word-delete**. Mac wants ⌥BSPC; firmware Ctrl
becomes ⌘ on the Mac and ⌘BSPC is delete-to-line-start. Irreducible — but
it's the *same* on all four typing layers, so one overlay position handles
it collision-free. This is the property that makes the merged design work.

---

## 7. Proposed target (NOT yet implemented)

9 layers, every typing layer written once:

| # | layer | |
|---|---|---|
| 0 | BAS | shared; always-active fallback |
| 1 | DEV | shared |
| 2 | AXN | shared |
| 3 | FNK | shared |
| 4 | STG | shared |
| 5 | MAC | OS flag + base overrides (pos 11/12 word-delete, pos 0 ESC) |
| 6 | MAC_AXN | conditional `<MAC AXN>` — the IDE/selection diffs |
| 7 | MAC_STG | conditional `<MAC STG>` — Mac system tools |
| 8 | GAME | Windows gaming |

Ordering matters: MAC=5 must sit above DEV/AXN/FNK so its overrides win;
`&trans` elsewhere falls through. MAC_AXN/MAC_STG must sit above MAC.

Panic key, collision-free at position 0 (ESC on every layer):
```
BAS  pos 0 ESC-hold  ->  &to BAS               (Windows: clear all)
MAC  pos 0 ESC-hold  ->  &to BAS + &tog MAC    (Mac: clear all, relight flag)
```

Other planned changes:
- **Thumbs**: `DEV · SPACE · AXN ‖ FNK · SPACE · STG` — drops the duplicate
  DEV, keeps both spaces, moves STG to the freed thumb.
- **Base bottom-right**: `N M , . / '` — restores `/` at pos 34, `'` moves
  to pos 35 (freed by STG going to a thumb). Swappable if `'` is wanted
  under the stronger finger.
- **GAME**: flat, **no home-row mods**, real Shift/Ctrl, no layer-taps on
  thumbs. Self-contained; `&to`/`&tog` from STG, dedicated exit key.

### 7.1 Home-row mods — the config is missing both key features

**Finding: HRM here has never been configured for a split keyboard.**
**[verified]**

```
config/os/shared/times.dtsi:21   #define KP_RIGHT   6 7 8 ... 41
config/os/shared/times.dtsi:22   #define KP_LEFT    0 1 2 ... 38
                                 ^ defined, and referenced NOWHERE
```

`&hm` in `config/os/shared/hold/shared.dtsi` is a bare hold-tap —
flavor, tapping-term, quick-tap, nothing else:

| knob | present? | what it does |
|---|---|---|
| `hold-trigger-key-positions` | **no** | positional / cross-hand HRM: only hold if the next key is on the *other* half. Kills same-hand roll misfires — the #1 HRM failure mode. |
| `require-prior-idle-ms` | **no** | refuse a hold if you just typed. Kills misfires mid-flow. |
| `hold-trigger-on-release` | **no** | lets you chord two mods on one hand. |

The only `hold-trigger-key-positions` in the repo is `<0>` on `&mt` in
`os/shared/general.dtsi`, which is the outer-column mod-taps, not HRM.

The author clearly *intended* positional HRM — that's what `KP_LEFT` /
`KP_RIGHT` are for — and never wired it up. So the owner's "timing is
tricky" is very likely this gap, not an inherent HRM problem.

**Recommendation: fix HRM before ditching it.** Wire `KP_LEFT`/`KP_RIGHT`
into `&hm` as `hold-trigger-key-positions`, add `require-prior-idle-ms`
(~150ms is a common starting point), then re-evaluate. **[inferred —
standard ZMK practice, not tested on this board]**

Why not just drop HRM: on 21 keys/half, HRM buys 8 modifiers at **zero key
cost**. Without it they must displace something, and the alternatives are
all worse here — sticky keys (`&sk`) add a keypress and a layer hop to
every shortcut; combos on the base layer misfire while typing; dedicated
thumb mods don't fit (6 thumbs already owe space, 3 layer keys, and the
freed one is spoken for). Getting modifiers without pinky stretches is one
of the main reasons a 42-key split works at all.

Also relevant: HRM accounts for **26 of the 79** Mac/Windows differences,
so if it *is* dropped, most of the divergence goes with it and the merge
calculus in §7 changes. The macOS remap applies wherever mods sit.

### Open — needs a design pass before the merge

- **§7.1 above** — tune HRM, or drop it. Gates the merge either way, since
  the MAC overlay design depends on where modifiers live.
- **Nav cluster placement** — where HOME/END/PgUp/PgDn go when nav
  consolidates onto AXN. AXN's left hand is fairly full, and the obvious
  trick (shift+arrows) collides with shift+arrow = select.

---

## 8. Work completed

Uncommitted in the working tree at time of writing:

1. **`config/os/shared/morph/boot.dtsi`** — `&bootloader` on both halves,
   behind shift on an STG thumb (left thumb → left half, right thumb →
   right half). Wired into `config/corne.keymap` and both
   `os/*/keymap.dtsi`. Costs no keys.

   **[unverified] Split semantics.** ZMK reset behaviours are believed to
   act on the half the key sits on, so both halves are bound — correct
   under either semantics. **This must be tested before being relied on:**
   press it and confirm the half enumerates as a USB drive. Getting this
   wrong means an unflashable half with the reset button blocked.

2. **`check-keymap.sh`** — offline validator, since there's no local ZMK
   build. Preprocesses `config/corne.keymap` with `cpp` against stubbed ZMK
   headers, then asserts every layer binds exactly 42 keys and every
   `&behavior` resolves. Current: *10 layers, all 42 bindings; all 109
   referenced behaviors resolve*. Does **not** validate devicetree
   semantics — a pass means "worth flashing", not "correct".

### Recommended flash order

Flash and verify **bootloader first**, before any restructure. It's the
recovery path for everything after it.

---

## 9. Tooling notes

- `./check-keymap.sh` — offline sanity check, no deps beyond `cpp` +
  `python3`.
- `./draw-keymap.sh` — regenerates `docs/keymap.yaml` + `docs/keymap.svg`.
  Needs `pip install keymap-drawer`, **not installed** in the working
  environment and the owner declined installing it. `docs/keymap.yaml` is
  the fully-resolved keymap and is the best source for analysis — it has
  all `#define` indirection already expanded.
- No `west`, no `dtc`, no local Zephyr. CI is the only real build.

---

## 10. Process notes for agents

- The owner asked to **ask before jumping ahead** — clarify and confirm the
  approach before implementing.
- Permissions have been broadened globally in `~/.claude/settings.json`
  (Bash, Edit, Write, web tools allowed; destructive Bash still denied).
- Prefer measuring over asserting. Most claims in this file came from
  scripting over `docs/keymap.yaml`; redo that rather than trusting prose
  if something looks off.
