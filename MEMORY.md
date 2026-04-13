# GoviKey — Codebase Memory

Reference for any agent or developer starting on this codebase. Covers architecture, key invariants, non-obvious design choices, and known pitfalls.

---

## What this project is

macOS Vietnamese IME. Pure Swift, no Apple IME framework.
A `CGEventTap` at HID level intercepts every keystroke, feeds it through a custom Vietnamese engine, then injects the transformed Unicode back via synthetic `CGEvent`s.

- **Package:** `VietKey/` folder, Swift Package named `GoviKey`
- **Original reference:** `PHTV/` — ObjC/C port from PHTV. Do NOT treat as authoritative; the Swift port diverges intentionally.
- **Targets:** `Engine` (pure logic, no system deps), `EventTap` (CGEventTap + output), `App` (NSStatusItem menu bar)

---

## Engine buffer: bit-packed UInt32

Every slot in `typingWord[UInt32]` stores one character as a bit field:

| Bits | Mask | Meaning |
|------|------|---------|
| 0–15 | `CHAR_MASK` | Raw key code or Unicode code point |
| 16 | `CAPS_MASK` | Uppercase |
| 17 | `TONE_MASK` | Circumflex diacritic (â, ô, ê) |
| 18 | `TONEW_MASK` | Breve/horn diacritic (ă, ư, ơ) |
| 19–23 | `MARK1_MASK`–`MARK5_MASK` | Tone marks: sắc, huyền, hỏi, ngã, nặng |
| 19–23 | `MARK_MASK` | Union of all five tone mark bits |
| 30 | `CHAR_CODE_MASK` | Lower 16 bits are a resolved Unicode code point |
| 31 | `PURE_CHARACTER_MASK` | Lower 16 bits are raw Unicode, bypass table lookup |

---

## Telex key → action mapping

| Key | Action |
|-----|--------|
| S | sắc (´) |
| F | huyền (`) |
| R | hỏi (?) |
| X | ngã (~) |
| J | nặng (.) |
| A | â / ă cycling |
| O | ô / ơ cycling |
| E | ê cycling |
| W | ư / ơ / ă cycling |
| D | đ / Đ |
| Z | undo last mark |

---

## Engine state flags (critical)

### `tempDisableKey`
- Set by `checkSpelling()` when the current syllable structure is invalid.
- Blocks all further Telex transforms for the current word.
- Cleared on word break or session reset.
- **Exception:** Unrecognised consonant starts (`f`, `j`, `fj`) are not in `vnConsonantTable` when `allowConsonantZFWJ = false` → `!matched → spellingOK = true` → transforms proceed regardless.

### `skipGrammarMarkNormalizationOnce`
- One-shot flag, suppresses one round of `checkGrammar()` during vowel cycling.
- Preserves user intent when the tone mark is on the correct vowel and must not be auto-moved.

### `hCode` (EngineAction)
- `.doNothing` — pass keystroke through unchanged
- `.willProcess` — replace characters (normal composition)
- `.restore` — undo Vietnamese, output raw keystrokes
- `.breakWord` — word boundary, reset session
- `.restoreAndStartNewSession` — restore + immediate reset

---

## Hotkey system (`EventRouter.swift`)

### Primary: modifier-only (default Ctrl+Shift)
- Stored as `hotkeyModifierMask` (UInt64 CGEventFlags bitmask).
- Fires on the **first modifier release** after the full combo was held clean.
- Guard: `keyPressedWhileModifiersHeld` — set by any `keyDown` while modifiers are held; blocks the trigger.
- `keyPressedWhileModifiersHeld` resets in three places:
  1. **`currentModifiers > previousModifiers`** (new chord starting) — clears stale flag from prior typing
  2. **`currentModifiers < previousModifiers`** (any modifier released)
  3. **`currentModifiers == 0`** (all released)

### Secondary: modifier + key (e.g. Ctrl+Space)
- Stored as `secondaryHotkeyKeyCode` (Int, -1 = disabled) + `secondaryHotkeyModifiers`.
- Fires on `keyDown` with exact modifier match.

---

## Spell check behaviour

`EngineConfig.checkSpelling = true` validates syllable structure before each transform.

| Input | Check ON | Check OFF |
|-------|----------|-----------|
| `bd` + `aa` | `tempDisableKey=true` → raw `bdaa` | `bdâ` |
| `ngl` + `ow` | `w` blocked → `nglow` | `nglơ` |
| Invalid syllable + SPACE | auto-restore raw sequence | commits composed form |
| `bach` + `f` (huyền on -ch) | tone blocked | `bàch` (invalid) |
| `fjow` | `spellingOK=true` → `fjơ` | `fjơ` (same) |

---

## Known pitfalls / do not revert

### 1. Restore must output full raw sequence
**`EngineHandler.swift` — `handleMainFlow()`**
After `.restore` action, `insertKey()` alone does not update `hData` for the restored character. The fix: capture `prevHNCC`, shift `hData` right, set `hData[0] = get(typingWord[idx - 1])`, set `hNCC = prevHNCC + 1`. Without this, `đ + d` outputs `d` instead of `dd`.

### 2. Always set `tempDisableKey = true` on restore in `insertAOE`
**`EngineComposition.swift` — `insertAOE()`**
The restore branch must set `tempDisableKey = true` for **all** keys including `KEY_O`. Removing this guard means `ô + o + o` cycles back to `ô` instead of staying raw.

### 3. Never call `tryExpandMarkedAOEElongation()` from `handleMainKey`
**`EngineComposition.swift`**
This function was removed from `handleMainKey` because it incorrectly expanded tone-marked single vowels (e.g. `ấ + a → áaa`). Do not re-add it.

### 4. `shouldAppendRawElongatedVowel` must check `MARK_MASK`, not just diacritics
**`EngineComposition.swift`**
The condition must be `(trailing & MARK_MASK) != 0` to cover all tone marks. Using only `TONE_MASK | TONEW_MASK` misses vowels with sắc/huyền/etc., causing `ắ + a` to raw-append instead of cycling to `ấ`.

### 5. Reset `keyPressedWhileModifiersHeld` when a new modifier chord starts
**`EventRouter.swift` — `checkModifierHotkey()`**
Without resetting in the `currentModifiers > previousModifiers` branch, normal typing leaves the flag `true`, causing the first language-switch hotkey press to silently fail every time.

---

## Output pipeline

```
keyDown event
  → markKeyPressedWhileModifiersHeld()
  → checkKeyDownHotkey()         (secondary hotkey)
  → handleKeyDown(event)
      → engine.handleKeyEvent(keyCode, caps)
      → EngineResult { action, hBPC (backspaces), hNCC (new chars), hData[] }
      → sender.sendBackspaces(hBPC)
      → sender.sendUnicodeString(hData[0..<hNCC])   // NFC precomposed
```

Self-generated events are marked with `EventMarker.goviKey` (`0x474F_5649` = "GOVI") on `eventSourceUserData` and skipped by the tap.

---

## Testing

```bash
# Must run outside sandbox (requires Accessibility tap)
swift test   # with required_permissions: ["all"] in Cursor
```

- Test file: `Tests/EngineTests/VietnameseEngineTests.swift`
- Helper: `type("telex input")` → returns composed output string
- 36+ tests covering Telex, VNI, tones, diacritics, restore, spelling
