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
| Layers | 7 of ZMK's 32 |
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

ZMK hard-caps at **32 layers** (uint32_t bitmask). At 7 the cap is *not* the
binding constraint — **maintenance is**. Full layer-set duplication for OS
variants was explicitly rejected by the owner; do not reintroduce it. Note
the cap and the 42-key count are independent: fewer physical keys pushes
toward *more* layers, not fewer.

---

## 3. Current architecture — authoritative

7 layers, one shared set:

| # | layer | |
|---|---|---|
| 0 | BAS | shared; always active, everything falls through to it |
| 1 | DEV | shared |
| 2 | AXN | shared; the only latchable layer |
| 3 | FNK | shared; empty slots `&trans` so it composes over AXN |
| 4 | STG | shared, macOS-flavoured; Windows replaces 10 positions |
| 5 | WIN | OS flag, almost all `&trans`. 3 keys: pos 0, 11, 12 |
| 6 | WIN_STG | conditional `<WIN STG>` — 10 keys |

Source: `config/os/shared/**` is everything shared; `config/os/windows/**`
is only the two overlays. There is **no** `config/os/macos/` — macOS *is*
the shared default.

### 3.1 Keycode convention — read before editing any binding

**MAC-CANONICAL.** The primary shortcut modifier is Command (`LGUI`/`RGUI`).
macOS needs **no host configuration at all**.

The Windows machines carry a **Win/Ctrl remap** (PowerToys) instead, so a
firmware `LGUI` arrives as Control there. When writing a Windows-only
binding:

> **want Control → write `LG`. want the Win key → write `LC`.**

This was deliberately inverted from an earlier Windows-canonical design
(commit `0435707`). Reason: the Mac is MDM-managed and the System Settings
change might be blocked, whereas the two Windows PCs are personal. See §5
for the caveat — this trade is **not fully verified**.

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
word-delete, the ESC panic and WIN_STG; typing and shortcuts still work,
because the modifier mapping is host-side.

`&to BAS` before `&tog WIN` is what keeps the profile macros idempotent:
`&to` guarantees WIN is off, so the `&tog` always turns it **on**.

The **OS toggle at STG position 31** exists because the profile macros only
set the OS as a side effect. USB connections don't touch the profile, and
deep-sleep wake resets layer state while the profile survives — either way
the flag and reality can disagree. Positions 31 and 32 are the only ones
free on STG *and* `&trans` on WIN_STG, which is what makes the self-inverse
fall-through work; 32 is still free.

There is **no `&out` binding**, so USB/BLE output isn't selectable from the
keymap. Pre-existing.

### 3.3 What each overlay carries

**WIN** — 3 keys, all layer-independent, which is why one overlay can carry
them without colliding:

```
   pos 0    ESC-hold -> &to BAS + &tog WIN   relight the flag &to clears
   pos 11   BSPC hold -> LG(BSPC)            = Ctrl+Bspc after the remap
   pos 12   DEL  hold -> LG(DEL)
```

Word-delete is the one thing the remap can't fix: macOS wants Option+Bspc,
Windows wants Ctrl+Bspc, and Cmd+Bspc on the Mac is delete-to-line-start.

**WIN_STG** — 10 keys at positions 4, 6, 10, 11, 18, 22, 23, 28, 30, 34:
colour picker, magnifier ×3, fancy zones, task manager, system info,
settings, security, file explorer. Cannot fold into WIN — those positions
are letters on the typing layers. Position 11 is bound on both; WIN_STG is
higher so task manager wins on the settings layer, which is intended.

There is **no WIN_AXN**: every AXN key either works on both OSes unaided or
was unused. Notably `Shift+Cmd+Z` is redo on both, and replace is
`Opt+Cmd+F` rather than `Ctrl+H` — the latter arrived as ⌘H and hid the
window.

### 3.4 Layer switching — does NOT use `&to`

`&to` deactivates every other layer and would take the OS flag with it (§4.1
has the full analysis). So:

- DEV, FNK, STG are **momentary** — releasing the thumb is the way back, so
  they need no return key anywhere.
- **AXN is the only latchable layer**, via `&tog`. Hold the thumb for
  momentary, tap to latch.
- The only `&to` is the ESC-hold panic reset, which relights WIN on the WIN
  layer.

State space is 4 and every state is escapable: `BAS`, `BAS+WIN`, `BAS+AXN`,
`BAS+WIN+AXN`.

Thumb map (BAS is the only layer that binds thumbs; the rest are `&trans`):

```
   36 DEV(mo)   37 SPACE   38 AXN   |  39 FNK(mo)  40 SPACE  41 STG(mo)
                                hold = momentary
                                tap  = &tog AXN
```

AXN position 38 carries `tog_AXN_off` rather than `&trans` so the host
signal knows which way the toggle went.

### 3.5 Gotchas that have already bitten

**Node order in `corne.keymap` determines layer index.** The `#define`s in
`os/shared/layers.dtsi` don't cause anything — they're names that must
*match*. Swap the two `#include`s and it compiles fine but the keyboard is
nearly dead. `check-keymap.sh` asserts this.

**Use `&none`, not `&trans`, where a layer wants a key to do nothing.**
`&trans` falls through to BAS and types a letter. STG positions 31/32 were
briefly `&trans` and typed `M` and `,`. Fixed in `0435707`.

**The outer columns are bound once on BAS and inherited.** ESC, BSPC, DEL,
RET, TAB and both spaces are `&trans` on every layer above. Only put a real
binding above BAS where the layer genuinely differs.

**Volume, mute and media are OS-independent HID consumer codes.** They live
once on the shared layer at positions 7/8/9 and 19/20/21. Do not duplicate
them onto WIN_STG — that's the bug that previously left one OS with no media
keys and volume in two different places.

### 3.6 Bootloader

`&bootloader` on **both halves**, behind shift on an STG thumb — left thumb
(pos 37) resets the left half, right thumb (pos 40) the right. Costs no
keys. `os/shared/morph/boot.dtsi`.

**[unverified] Split semantics.** ZMK reset behaviours are believed to act
on the half the key sits on, so both are bound — correct under either
semantics. **Test before relying on it:** press each and confirm that half
enumerates as a USB drive. Getting this wrong means an unflashable half with
the reset button blocked.

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

## 5. Host-side setup required — UNVERIFIED, gates the design

**Windows (both PCs):** a Win/Ctrl remap, so firmware `LGUI` arrives as
Control. PowerToys Keyboard Manager is the obvious tool.

> **[unverified] and important.** macOS's modifier swap is *per-keyboard*.
> I do not believe PowerToys can scope a remap to one device — if it's
> per-machine, it will affect every keyboard on those PCs. No web access in
> the session where this was decided. **If that's unacceptable, the honest
> fix is reverting to Windows-canonical: `git revert 0435707`, cheap while
> nothing is flashed.**

**macOS:** nothing. That's the point of the inversion.

---

## 6. Commit map on `keymap-redesign`

```
3eb54d3  feat: OS mode toggle decoupled from the bluetooth profile
0435707  refactor: make macOS the default, flag Windows instead
b97894e  refactor: inherit outer columns via &trans
21b9752  refactor: strip unused WIN_STG keys, unify volume and media
9d10d86  refactor: drop the AXN overlay, AXN is fully shared
6d941f6  refactor: merge the two OS layer sets into one
ed9bdce  fix: make home-row mods positional
ed67234  build: add offline keymap sanity check
95638ee  feat: bind bootloader on both halves      <- cherry-pick first
```

**Recommended flash order: bootloader first**, verified, before anything
else. It's the recovery path for everything after it.

---

## 7. Open

- **Hardware verification of everything.** Nothing has been flashed.
  Priority order: DFU on each half (§3.6), the Windows remap question (§5),
  HRM feel, then whether deep sleep clears the flag.
- **Deep sleep and the OS flag.** `CONFIG_ZMK_SLEEP=y` with a 10-minute
  timeout. ZMK deep sleep is System OFF, so waking is effectively a reboot;
  the BT profile survives in settings but layer state does not. **[unverified
  — mechanism is confident, behaviour untested.]** The OS toggle (§3.2)
  makes recovery one keypress. Test: idle past 10 minutes, wake, check
  whether the STG right half still shows macOS keys.
- **GAME layer** (req 5), deferred. Layer 7 free. Should be flat, **no
  home-row mods**, real Shift/Ctrl, no layer-taps on thumbs, self-contained.
- **Windows screenshot.** `mp_sSTG_screenshot` is macOS-shaped
  (Shift+Cmd+5/4/3) and does nothing useful on Windows, which wants
  Win+Shift+S. Pre-existing, not a regression, worth fixing.
- **Nav cluster is split** — arrows on AXN, HOME/END/PgUp/PgDn on FNK. Not a
  blocker (that was resolved by dropping sideways routes), but possibly
  annoying in use. Judge from using it. Note shift+arrows is taken by
  select, so the obvious consolidation doesn't work.
- **`docs/keymap.svg` / `keymap.yaml`** must be regenerated after any keymap
  change — see §8. They have drifted before.

---

## 8. Tooling

- **`./check-keymap.sh`** — offline validator; no deps beyond `cpp` and
  `python3`. Preprocesses `config/corne.keymap` against stubbed ZMK headers
  and asserts: every layer binds exactly 42 keys, every `&behavior`
  resolves, and keymap node order matches `layers.dtsi`. A pass means
  "worth flashing", **not** "correct" — it does not validate devicetree
  semantics. Current: *7 layers, 63 behaviours, order ok*.
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
