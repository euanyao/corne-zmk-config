# corne-zmk-config — working context

Context for agents picking this repo up mid-stream. Records what has been
**measured**, what has been **decided**, and what is still **open**, so the
analysis doesn't have to be redone.

Claims are tagged:
- **[verified]** — measured from this repo or run locally
- **[inferred]** — read off the config, not documented by the original author
- **[unverified]** — believed true, not confirmed in this environment

All work is on branch **`keymap-redesign`**. `master` is untouched.
**Nothing has been flashed or tested on hardware.**

---

## 1. What this is

ZMK firmware config for a 42-key split Corne (3x6 + 3 thumbs per half).
Layout originally inherited from an upstream config (Camilo Martinez /
Equiman — see copyright headers in `config/helpers/*.dtsi`), **not** designed
by the current owner, who has only a few weeks on any ergo keyboard.
**[verified]**

Consequence for design work: there is **no muscle memory worth preserving**.
Don't weight "matches previous behaviour" highly. Simplicity and
learnability are worth more here than continuity.

### Hardware / build

| | |
|---|---|
| Board | `nice_nano//zmk`, shields `corne_left` / `corne_right` |
| Central | **left** (carries the studio snippet + USB UART) |
| Peripheral | **right** |
| Builds | GitHub Actions only — **no local ZMK toolchain, no `west`** |
| Layers | 9 of ZMK's 32 |
| ZMK Studio | enabled (`-DCONFIG_ZMK_STUDIO=y`) |
| LEDs | 27 per half (21 per-key + 6 underglow) |

**The case covers the physical reset button.** Bootloader access via the
keymap is therefore safety-critical — losing it means losing the ability to
flash. **[verified — stated by owner]**

### Owner's devices

1 macOS work laptop (MDM-managed), 2 Windows PCs (personal).

---

## 2. Requirements and status

| | requirement | status |
|---|---|---|
| 1 | Constant Win/macOS switching; don't duplicate keys across two layer sets | **done** — one shared set, §3 |
| 2 | Dev-friendly base layer, `/` needed | **done** — `/` at pos 34, `'` at 35 |
| 3 | Reclaim duplicate thumb layer-switch keys | **done** — §3 thumb map |
| 4 | Bootloader reachable from a layer | **done, UNTESTED** — §3 |
| 5 | Gaming layer for Windows | **deferred** by owner; layer 7 free |
| 6 | Avoid home-row mods (hold timing hard) | **resolved by fixing, not removing** — §4.3 |

Still missing from the base layer: **`-`** (kebab-case, flags, ranges),
currently DEV-only. No obvious home without a compromise. Raise if it bites.

### Standing constraint

ZMK hard-caps at **32 layers** (uint32_t bitmask). At 9 the cap is *not* the
binding constraint — **maintenance is**. Full layer-set duplication for OS
variants was explicitly rejected by the owner; do not reintroduce it. Note
the cap and the 42-key count are independent: fewer physical keys pushes
toward *more* layers, not fewer.

---

## 3. Current architecture — authoritative

9 layers, one shared set plus two Windows overlays:

| # | layer | |
|---|---|---|
| 0 | BAS | shared; always active, everything falls through to it |
| 1 | WIN | OS flag, almost all `&trans`. 3 keys: pos 0, 11, 12 |
| 2 | DEV | shared |
| 3 | AXN | shared; the only latchable layer |
| 4 | FNK | shared; empty slots `&trans` so it composes over AXN |
| 5 | NAV | shared; arrows + HOME/END/PgUp/PgDn, held by right thumb |
| 6 | STG | shared; **keyboard config only**, OS-independent |
| 7 | WIN_DEV | conditional `<WIN DEV>` — 1 key |
| 8 | WIN_AXN | conditional `<WIN AXN>` — 9 keys |

**WIN sits at 1, below the typing layers, on purpose.** ZMK's built-in OLED
status screen shows the *highest active* layer, so a high WIN made the OLED
read "WIN" permanently in Windows mode and mask DEV/AXN/FNK. It resolves
correctly down there only because DEV/AXN/FNK are `&trans` at all three
positions WIN binds — so WIN only has to outrank BAS. `check-keymap.sh`
asserts that invariant, because breaking it silently kills Windows
word-delete rather than failing the build. STG is exempt: it legitimately
overrides those positions and word-delete isn't wanted there.

Layer order lives in the **include list in `corne.keymap`**, which
interleaves `os/shared/keymap/` and `os/windows/keymap/`.

Source: `config/os/shared/**` is everything shared; `config/os/windows/**`
is only the two overlays. There is **no** `config/os/macos/` — macOS *is*
the shared default.

### 3.1 Keycode convention — read before editing any binding

**Write keycodes natively. There is NO host remap.** `LGUI` is Command on
macOS and the Win key on Windows; `LCTRL` is Control on both. What you write
is what the host receives.

Shared layers are Mac-flavoured because macOS is the unflagged default.
Where a Windows chord genuinely differs it gets a **conditional overlay**,
so the firmware does the translating:

| overlay | layer | carries |
|---|---|---|
| `WIN` | 1 | word-delete + ESC panic — identical on every typing layer |
| `WIN_DEV` | 7 | DEV pos 25, Cmd+R → Ctrl+R |
| `WIN_AXN` | 8 | nine AXN shortcuts: clipboard, find, replace, tab/desktop switching |

**History, so it isn't re-litigated.** An earlier design wrote everything
Cmd-canonical and relied on a PowerToys Win/Ctrl remap on the Windows
machines. That was abandoned once the remap was shown to be **machine-wide
only** — it cannot be scoped to one keyboard, so it would have affected the
built-in keyboard, RDP and VM sessions too. Do not reintroduce a host-remap
assumption.

**Home-row mods are swapped per OS by those same overlays.** BAS puts the
primary modifier (Command) on **S/L** and the secondary (Control) on
**A/`;`**. Windows wants Control as primary, so `WIN`, `WIN_DEV` and
`WIN_AXN` swap them — S/L become `LCTRL`, A/`;` become `LGUI`. **The primary
modifier keeps the same finger on both OSes.**

| layer | 13 (A) | 14 (S) | 21 (L) | 22 (;) |
|---|---|---|---|---|
| BAS / DEV / AXN / FNK / NAV | **LGUI** | LCTRL | RCTRL | **RGUI** |
| WIN / WIN_DEV / WIN_AXN | **LCTRL** | LGUI | RGUI | **RCTRL** |

Primary modifier on **A/`;`**, secondary on **S/L**, consistent on every
layer and mirrored per OS. FNK pos 21 and NAV pos 13/14 bind other things,
so they are not part of the pattern.

`WIN` covers BAS for free — it already sat directly above it. DEV and AXN
bind those positions themselves, so their overlays carry the swap.

**STILL UNSWAPPED: FNK pos 14 and NAV pos 21.** Neither has an overlay, so
both are the Win key on Windows. **NAV's actively misfires** — `Win+arrow`
snaps windows there, so selection-by-word would rearrange your desktop
instead. FNK's is milder: a Win-key hold while pressing F-keys. Fixing needs
a `WIN_FNK` / `WIN_NAV` pair, one key each, +2 layers.

### 3.2 OS flag

macOS is the **unflagged default**; WIN is lit for Windows.

```
   what lights WIN               where
   ---------------------------   -----------------------------------
   m_s_b3..b6 (BT profiles 2-5)  STG positions 13/14/25/26
   &tog WIN   (OS toggle)        STG position 31, self-inverse
   to_BAS_win_kp (ESC-hold)      on WIN itself — relight after &to
```

BT profiles: **0-1 = macOS, 2-5 = Windows**, in
`os/shared/macros/settings.dtsi`. **Nothing detects the OS** — it's pure
convention, so pair the Mac to slot 0 or 1. A mismatched flag only breaks
word-delete and the ESC panic; typing and shortcuts still work,
because the modifier mapping is host-side.

`&to BAS` before `&tog WIN` is what keeps the profile macros idempotent:
`&to` guarantees WIN is off, so the `&tog` always turns it **on**.

The **OS toggle at STG position 31** exists because the profile macros only
set the OS as a side effect. USB connections don't touch the profile, and
deep-sleep wake resets layer state while the profile survives — either way
the flag and reality can disagree. It no longer needs the self-inverse
fall-through trick that constrained it to positions 31/32: with WIN_STG gone
nothing shadows STG, so `&tog WIN` simply toggles.

There is **no `&out` binding**, so USB/BLE output isn't selectable from the
keymap. Pre-existing.

### 3.3 What each overlay carries

**WIN** — 3 keys, all layer-independent, which is why one overlay can carry
them without colliding:

```
   pos 0    ESC-hold -> &to BAS + &tog WIN   relight the flag &to clears
   pos 11   BSPC hold -> LC(BSPC)            Ctrl+Bspc, written natively
```

Backspace word-delete differs by OS: macOS wants Option+Bspc, Windows wants
Ctrl+Bspc, and Cmd+Bspc on the Mac is delete-to-line-start. Both are
identical on every typing layer, which is why one overlay can carry them.

**DEL has no word-delete counterpart.** Position 24 carries the STG hold
instead, so there is nothing for WIN to override there — which is why
`check-keymap.sh` asserts only positions 0 and 11.

**WIN_STG is gone.** It existed solely to give Windows counterparts for 13
host application shortcuts on STG (zoom, accessibility zoom, screenshot,
input source, Finder, Mission Control, force quit, app windows). Those were
dropped — the owner uses none of them — so STG became pure keyboard config
and the overlay had nothing left to override.

What that bought:

- **STG is OS-independent.** The WIN flag has no effect on it.
- **Nothing sits above STG**, so an overlay can no longer shadow the
  bootloader keys. That bug was live: task manager sat at position 11 and
  would have silently replaced DFU in Windows mode.
- **STG has room again** — 14 of 42 positions used. `BT_CLR` moved out from
  behind Alt onto its own key, and ZMK Studio unlock got its own key rather
  than sharing one.

**If host shortcuts are wanted later, they go on FNK with a `WIN_FNK`
conditional overlay** — the same pattern WIN_STG used, on the layer that has
the space. Do not put them back on STG.

**WIN_AXN** — 9 keys at positions 2, 4, 5, 17, 25, 26, 27, 28, 29:
clipboard (undo/cut/copy/paste/redo), find, replace, tab and
virtual-desktop switching. This is what removed the PowerToys dependency —
without it AXN's clipboard cluster arrives as Win+Z/X/C/V on Windows and
opens snap layouts, the power-user menu, Copilot and clipboard history.

Redo is `Ctrl+Y` there rather than `Ctrl+Shift+Z` (both work; Ctrl+Y is more
universal), and replace is `Ctrl+H`, which is the reason it needs an
override at all — macOS uses Opt+Cmd+F and there is no shared chord.

**WIN_DEV** — 1 key: DEV pos 25, Cmd+R → Ctrl+R. Thin, but the alternative
sends Win+R and opens the Run dialog. It is also where future DEV divergence
belongs. Notably `Shift+Cmd+Z` is redo on both, and replace is
`Opt+Cmd+F` rather than `Ctrl+H` — the latter arrived as ⌘H and hid the
window.

### 3.4 Layer switching — does NOT use `&to`

`&to` deactivates every other layer and would take the OS flag with it (§4.1
has the full analysis). So:

- DEV, FNK, NAV, STG are **momentary** — releasing the thumb is the way
  back, so they need no return key anywhere.
- **AXN is the only latchable layer**, via `&tog`. Hold the thumb for
  momentary, tap to latch.
- The only `&to` is the ESC-hold panic reset, which relights WIN on the WIN
  layer.

State space is 4 and every state is escapable: `BAS`, `BAS+WIN`, `BAS+AXN`,
`BAS+WIN+AXN`.

Thumb map (BAS is the only layer that binds thumbs; the rest are `&trans`):

```
   36 DEV(mo)   37 SPACE   38 AXN   |  39 FNK(mo)  40 SPACE  41 NAV(mo)
                                hold = momentary
                                tap  = &tog AXN
```

AXN position 38 carries `tog_AXN_off` rather than `&trans` so the host
signal knows which way the toggle went.

**STG is no longer on a thumb at all.** Thumb 41 became NAV; STG is reached
by holding TAB (pos 24, left half) or RET (pos 35, right half) via
`&ht_STG`. Two routes, one per half, so either hand can hold the layer while
the other reaches a bootloader key — see §3.6. `ht_STG` wraps `mo_STG`
rather than a bare `&mo` so the host layer signal still fires.

**NAV is held by the RIGHT thumb (41) on purpose** — that puts the arrows on
the LEFT hand, so every arrow press is cross-hand. The modifiers on NAV's
right home row (pos 19-22) are plain `&kp`, not hold-taps: they only ever
get held while the left hand arrows, so there is no tap to disambiguate.
Thumb 41 is redundant now and could be reclaimed if a thumb is ever needed.

### 3.5 Gotchas that have already bitten

**Node order in `corne.keymap` determines layer index.** The `#define`s in
`os/shared/layers.dtsi` don't cause anything — they're names that must
*match*. Swap the two `#include`s and it compiles fine but the keyboard is
nearly dead. `check-keymap.sh` asserts this.

**Use `&none`, not `&trans`, where a layer wants a key to do nothing.**
`&trans` falls through to BAS and types a letter. STG positions 31/32 were
briefly `&trans` and typed `M` and `,`. Fixed in `0435707`.

**The outer columns are bound once on BAS and inherited.** ESC, BSPC, DEL,
TAB, quote (pos 23) and both spaces are `&trans` on every layer above. Only
put a real binding above BAS where the layer genuinely differs.

**RET is no longer an outer-column key.** It was swapped with quote, so it
now sits at **pos 35** — which DEV, AXN and STG already bind (F12,
`Ctl+Gui+D`, RGB brightness down). **Enter is therefore unavailable on those
three layers.** Accepted deliberately; if it bites, free pos 35 on DEV/AXN
or move RET back to an outer column.

**Pos 35 still carries the STG hold**, so RET there is `&ht_STG 0 RET`, not
a plain `&kp`. That hold is the right-hand route to STG and is what makes
the left-half bootloader reachable (§3.6) — do not replace it with a plain
binding. The cost is that RET lost its old F2/rename hold.

**Volume, media and screen brightness live on FNK's right half**, moved off
STG when that became config-only. They are OS-independent HID consumer
codes, so they need no overlay — and duplicating them per OS is what once
left one OS with no media keys and volume in two different places, so keep
them on the shared layer.

Cost of putting them there: FNK rows 0 and 1 no longer compose over a
latched AXN. Row 2 and the thumbs are still `&trans`, so the bottom numpad
row does.

### 3.6 Bootloader

Bare `&bootloader` at the **top outer corners**: position 0 is the left
half, position 11 the right. Reached **cross-hand**:

```
   flash LEFT    hold ' (pos 35, right hand)  ->  press pos 0  (left hand)
   flash RIGHT   hold TAB (pos 24, left hand) ->  press pos 11 (right hand)
```

**STG is bound on both halves for this reason** — `&ht_STG` on TAB (pos 24)
and quote (pos 35), tap keeps the original key. A single thumb-held STG
cannot reach a boot key on its own half: the earlier design put them on STG
thumbs 37/40, but STG was held with the right thumb at pos 41 and 40 is the
adjacent thumb key, so the same thumb had to do both. Cross-hand removes the
conflict. Costs no keys; `KEY_TAB` lost only its hold (was right-arrow).

**[verified] Split semantics.** ZMK reset behaviours are **source
locality** — they act on the half the key physically sits on, so each half
needs its own binding. Confirmed from ZMK's split-keyboards docs:
*"These behaviors only affect the keyboard part that they are invoked
from: Reset behaviors."*

**Never put these behind a combo.** Same docs: *"Combos always invoke
behaviors with source locality on the central"* — a combo would reset the
left half regardless of which keys were pressed, leaving the right
unflashable.

**Peripheral caveat:** the halves must be paired and connected, since
bindings are processed on the central which then instructs the peripheral.
If the split link is down, the right-half key won't fire.

**Still untested on hardware.** Press each and confirm that half enumerates
as a USB drive.

### 3.7 Host companions

`host/windows/ahk/` watches F13–F18 signal keys emitted alongside layer
changes. Unchanged by the merge — the old mac and windows signal defines
were already the same keycodes. **[verified]**

---

## 4. Why it looks like this — decisions and dead ends

### 4.1 The `&to` / OS-flag conflict

To collapse to one layer set, something must remember which OS you're on.
ZMK's only runtime state is **which layers are active**, so the flag must be
a layer that stays lit.

| | effect on other layers |
|---|---|
| `&mo LAYER` | on while held — leaves others alone |
| `&tog LAYER` | flips that layer — leaves others alone |
| `&to LAYER` | on, **and switches every other layer off** |

The original config used `&to` for every sticky jump, which would wipe the
flag on the first layer change. Confirmed dead ends:

- **A single overlay can't fix the home-row mods.** To override DEV's mods it
  must sit above DEV, but then its BAS-flavoured taps leak onto DEV. One
  overlay per typing layer = no saving.
- **`&tog` is not a drop-in for `&to`** while sideways routes exist
  (DEV→AXN, AXN→FNK, FNK→AXN, STG→AXN): tog stacks layers instead of
  switching.
- **A macro re-asserting the flag after `&to`** needs an OS-specific twin of
  every layer-switch key, and each layer's thumb has a different
  destination — one binding at position 38 can't be three things.

**Resolution:** sideways routes were dropped. With momentary layers,
"sideways" is free — release one thumb, press another. Only AXN↔FNK was ever
latched→latched, and FNK doesn't need latching (F-keys are single presses).
That reduced the machinery to one `&tog AXN`.

Self-inverse latch trick, used for both the AXN latch and the OS toggle: put
`&tog X` at position P on the lower layer and leave P `&trans` on the layer
above. Pressing P falls through to the same binding and toggles back off.

### 4.2 Divergence measurement (on the *pre-merge* config)

Historical, but it's the evidence the merge rested on. 210 bindings
(42 keys × 5 layer pairs): **[verified]**

| | count | |
|---|---:|---|
| identical | 131 | 62% |
| layer-ref only | 19 | mechanical |
| pure modifier swap | 26 | mechanical |
| genuinely OS-specific | 34 | 22 of them in STG alone |

Outside STG, 168 bindings shared 156 — **93% identical**. Four duplicated
layers existed to express about twelve keys, and the duplication was already
drifting: mAXN and mFNK never received the `,` and `.` their Windows
counterparts had.

### 4.3 Home-row mods — the config was never configured for a split

**[verified]** `KP_LEFT` / `KP_RIGHT` were defined in `times.dtsi` and
referenced **nowhere**. `&hm` was a bare hold-tap with no
`hold-trigger-key-positions`, no `require-prior-idle-ms`, no
`hold-trigger-on-release` — the three things that make HRM usable. The
author clearly intended positional HRM and never wired it up, so the owner's
"timing is tricky" was almost certainly that gap.

**DECIDED: keep HRM, fix the config.** `&hm` split into `&hml` (left home
row) and `&hmr` (right), each with the opposite finger block **plus both
thumbs** as trigger positions, `require-prior-idle-ms = 150`, and
`hold-trigger-on-release`.

Thumbs are in both trigger lists deliberately — strict cross-hand would
break mod + layer-thumb chords like Ctrl + AXN-arrow for word jumps.

Why not drop HRM: on 21 keys/half it buys 8 modifiers at **zero key cost**.
Sticky keys add a keypress and a layer hop to every shortcut; base-layer
combos misfire while typing; thumb mods don't fit. `HR_PRIOR_IDLE` is a
starting guess and wants tuning — one number in `times.dtsi`.

---

## 5. Host-side setup required — NONE

> **DECISION (owner): drop the PowerToys remap entirely.** The firmware
> emits native Windows keycodes via the `WIN_DEV` and `WIN_AXN` conditional
> overlays instead of relying on the host to translate. **Neither OS needs
> any host-side configuration.**

**macOS:** nothing.
**Windows:** nothing.

### Why the remap was abandoned

> **[verified] PowerToys cannot scope a remap to one device.** Evidence from
> `microsoft/PowerToys`:
> [#31877](https://github.com/microsoft/PowerToys/issues/31877) ("Keyboard
> Manager settings per device") closed as a duplicate of #26086;
> [#40605](https://github.com/microsoft/PowerToys/issues/40605) closed as a
> duplicate of #44666; and
> [PR #49276](https://github.com/microsoft/PowerToys/pull/49276)
> ("Per-keyboard remap profiles") is an **open draft, unmerged**.

A machine-wide remap would have affected the laptop's built-in keyboard,
every other keyboard on both PCs, and RDP/VM sessions from them. Two
conditional overlays (10 bindings total) were cheaper than accepting that,
and they make the config self-contained.

**Do not reintroduce a host-remap assumption.** If a future binding needs a
different chord per OS, add it to `WIN_DEV` or `WIN_AXN`, or create the
matching overlay for whichever layer it lives on.

**What this did not fix:** the home-row GUI mods at positions 14/21 — see
§3.1. They are the one place where the OS difference is still visible to the
user rather than absorbed by the firmware.

---

## 6. Commit map on `keymap-redesign`

```
d10d5c8  feat: reachable bootloader via cross-hand STG   <- supersedes 95638ee
30999c6  docs: cost out the deep-sleep flag options
d7e5626  refactor: move WIN below the typing layers
3eb54d3  feat: OS mode toggle decoupled from the bluetooth profile
0435707  refactor: make macOS the default, flag Windows instead
b97894e  refactor: inherit outer columns via &trans
21b9752  refactor: strip unused WIN_STG keys, unify volume and media
9d10d86  refactor: drop the AXN overlay, AXN is fully shared
6d941f6  refactor: merge the two OS layer sets into one
ed9bdce  fix: make home-row mods positional
ed67234  build: add offline keymap sanity check
95638ee  feat: bind bootloader on both halves      <- superseded, see above
```

**Recommended flash order: bootloader first**, verified, before anything
else. It's the recovery path for everything after it. Note `95638ee`'s
placement was unreachable on the right half — cherry-pick `d10d5c8`, not it.

### Divergence from `master`

`master` is tagged **`v1.0`** and has been **flashed and hardware-verified**;
this branch has not. Work exists on each that the other lacks:

| | `master` (`v1.0`) | `keymap-redesign` |
|---|---|---|
| layers | 10, duplicated per-OS | 7, one shared set |
| home-row mods | plain, misfires | positional |
| bootloader | none | both halves |
| morph cleanup, accent removal | yes (13 morphs cut) | no |
| outer-column moves (11/12/23/40) | yes | different arrangement |
| hardware-tested | **extensively** | never flashed |

Master's `v1.0` also verified on hardware: all 54 RGB LEDs, full key matrix,
OLED, split pairing, deep sleep config. Those findings apply here too — same
hardware, and several are recorded in this repo's git history rather than
only in this file.

---

## 7. Open

- **Hardware verification of this branch.** Nothing on `keymap-redesign` has
  been flashed. Priority order: DFU on each half (§3.6), then HRM feel, then
  whether deep sleep clears the flag. The Windows remap question (§5) is now
  **measured** — it needs a decision, not an experiment.
- **Deep sleep and the OS flag.** `CONFIG_ZMK_SLEEP=y` with a 10-minute
  timeout. ZMK deep sleep is System OFF, so waking is effectively a reboot;
  the BT profile survives in settings but layer state does not. **[unverified
  — mechanism is confident, behaviour untested.]**

  **Test this before fixing it.** In Windows mode, idle past 10 minutes,
  wake, read the OLED: `WIN` means the flag survived and this whole item is
  moot. `BAS` means it was lost.

  Note BLE auto-reconnect does **not** restore it. Reconnection is a radio
  event; the profile macros only run the `&tog WIN` half on a key press, and
  ZMK has no on-connect hook in the keymap.

  If confirmed lost, in increasing cost:
  1. **OS toggle at STG 31** — already built, one tap, zero risk.
  2. **Raise `CONFIG_ZMK_IDLE_SLEEP_TIMEOUT`** — one line, zero risk, costs
     battery. The conf notes deep sleep is the biggest power win.
  3. **A ZMK module with a boot/connect listener** — ~20 lines of C calling
     `zmk_keymap_layer_activate()` off the persisted profile index. Only
     worth it if 1 and 2 are both unacceptable *and* you can build locally.
     Caveats: C can't live in a zmk-config repo without a module and the
     in-repo mechanism is uncertain; `zmk_ble_active_profile_changed`
     probably won't fire on wake-from-reset since the profile didn't
     change, so it wants boot-time init and therefore Zephyr init-order
     care; and CI would be the only feedback loop.
- **GAME layer** (req 5), deferred. Layer 7 free. Should be flat, **no
  home-row mods**, real Shift/Ctrl, no layer-taps on thumbs, self-contained.

- **Nav cluster** — **resolved** by the NAV layer (§3), which puts arrows,
  HOME/END and PgUp/PgDn together on one layer held by the right thumb.
  **The old copies are still in place**: arrows remain on AXN (pos 3, 14-16)
  and HOME/PgDn/END on FNK (pos 19-21). That was deliberate — NAV is
  additive so nothing breaks while it is being tried. Once NAV proves out,
  strip the duplicates; AXN's arrow positions are hold-taps carrying
  modifiers for the right-hand numpad, so removing the arrows means deciding
  what those four positions tap instead, not just deleting them.
- **`docs/keymap.svg` / `keymap.yaml`** must be regenerated after any keymap
  change — see §8. They have drifted before.

---

## 8. Tooling

- **`./check-keymap.sh`** — offline validator; no deps beyond `cpp` and
  `python3`. Preprocesses `config/corne.keymap` against stubbed ZMK headers
  and asserts: every layer binds exactly 42 keys, every `&behavior`
  resolves, and keymap node order matches `layers.dtsi`. A pass means
  "worth flashing", **not** "correct" — it does not validate devicetree
  semantics. Current: *9 layers, 61 behaviours, order ok*.
- **`./draw-keymap.sh`** — regenerates `docs/keymap.yaml` + `docs/keymap.svg`.
  Needs `keymap-drawer` (installed, v0.23.0 at `~/.local/bin/keymap`; export
  `PATH="$HOME/.local/bin:$PATH"` first). **Re-run after any keymap change.**
- `docs/keymap.yaml` is the fully-resolved keymap and the best source for
  analysis — all `#define` indirection is expanded, so script against it
  rather than parsing `config/os/**` by hand.
- No `west`, no `dtc`, no local Zephyr. **CI is the only real build**, and it
  triggers on push to any branch.
- Package installs were blocked for this agent (denied sandboxed *and*
  unsandboxed); the owner installed keymap-drawer manually. Ask rather than
  burning attempts on `pip install`.

---

## 9. Process notes for agents

- The owner asked to **ask before jumping ahead** — clarify and confirm the
  approach before implementing.
- Prefer measuring over asserting. Most numbers here came from scripting
  over `docs/keymap.yaml`; redo that rather than trusting prose.
- **Verify doc edits landed.** A long `re.sub` against this file silently
  failed to match once and left §3, §5 and §7 describing a superseded
  design for two commits. Check the diff, not the exit code.
- Permissions are broadened globally in `~/.claude/settings.json` (Bash,
  Edit, Write, web tools; destructive Bash still denied). Note `rm -rf` is
  denied, which also blocks `git rm -rf`-style cleanups.
