# GoviKey

Vietnamese input method (IME) for macOS. Pure Swift, CGEventTap-based.
Supports Telex and VNI input methods. macOS 13+.

## Build & Test

```bash
swift build          # Build all targets
swift test           # Run engine tests (36+ tests)
swift run GoviKey    # Run the app (requires Accessibility permission)
```

> `swift test` requires running outside the sandbox — use `required_permissions: ["all"]` in Cursor.

## Project Structure

```
Sources/
  Engine/
    VietnameseEngine.swift      # Core state machine: handleKeyEvent() -> EngineResult
    EngineHandler.swift         # Main flow: handleMainFlow(), handleWordBreak(), handleDelete()
    EngineComposition.swift     # Key composition: insertKey(), insertAOE(), insertD(), insertW()
    EngineVowel.swift           # Vowel diacritic logic
    EngineMark.swift            # Tone mark insertion and cycling
    EngineSpelling.swift        # checkSpelling() + checkGrammar() — syllable validation
    VietnameseData.swift        # Key codes, bit masks, vowel/consonant/end-consonant tables
    EngineResult.swift          # EngineResult value type + EngineConfig settings struct
  EventTap/
    EventRouter.swift           # InputController: owns engine + sender, C callback dispatcher
    EventTapManager.swift       # CGEventTap lifecycle (HID tap -> session tap fallback)
    KeyEventSender.swift        # Synthetic backspaces + Unicode output via CGEvent
    EventMarker.swift           # Self-event detection (0x564B4559 "VKEY" marker)
    AccessibilityOutput.swift   # AX-based text replacement (Spotlight / text fields)
    AppClassifier.swift         # Per-app game mode classification
    SpotlightDetector.swift     # Detects Spotlight/search context for AX output path
  App/
    GoviKeyApp.swift            # NSStatusItem menu bar app (LSUIElement, no dock icon)
    UserSettings.swift          # ObservableObject backed by AppStorage; applies to InputController
    SettingsView.swift          # SwiftUI settings window (Input, Apps, General tabs)
Tests/
  EngineTests/                  # Unit tests for engine (Telex, VNI, tones, spelling, orthography)
```

## Architecture

### Three-layer design

1. **Engine** (pure Swift, no system deps) — State machine with UInt32 bit-packed typing buffer. Returns `EngineResult` value type (action + backspaceCount + newCharCount + data). No I/O, no globals.
2. **EventTap** — CGEventTap at HID level. `InputController` bridges C callback to engine, sends output via `KeyEventSender`. Self-events skipped via `eventSourceUserData` marker.
3. **App** — NSApplication + NSStatusItem ("Vi"/"En" indicator). SwiftUI settings window with Input/Apps/General tabs.

### Data flow

```
CGEventTap callback
  -> skip self-events (EventMarker check)
  -> re-enable if tap disabled by system
  -> flagsChanged -> checkModifierHotkey() (modifier-only shortcut)
  -> keyDown only
     -> shortcut recording mode (isRecordingShortcut)
     -> markKeyPressedWhileModifiersHeld()
     -> checkKeyDownHotkey() (modifier + key shortcut)
     -> Vietnamese mode guard
     -> InputController.handleKeyDown()
          -> engine.handleKeyEvent(keyCode, capsStatus)
          -> EngineResult { action, backspaceCount, newCharCount, data[] }
          -> sender.sendBackspaces() + sender.sendUnicodeString()  // NFC precomposed
```

### Engine internals

- **Buffer**: `[UInt32]` of size `ENGINE_MAX_BUFF` (32). Each element is bit-packed:
  - Bits 0-15: character/key code (`CHAR_MASK = 0xFFFF`)
  - Bit 16: caps (`CAPS_MASK`)
  - Bit 17: has circumflex/diacritic tone (`TONE_MASK`)
  - Bit 18: breve/horn tone-w marker (`TONEW_MASK`)
  - Bits 19-23: vowel mark type (`MARK1_MASK`=sắc … `MARK5_MASK`=nặng, combined `MARK_MASK`)
  - Bit 30: char code flag (`CHAR_CODE_MASK`)
  - Bit 31: pure character flag (`PURE_CHARACTER_MASK`)
- **Actions**: `doNothing` (passthrough), `willProcess` (replace chars), `restore` (undo Vietnamese → raw), `breakWord` (word boundary), `restoreAndStartNewSession`
- **Telex processing keys**: S, F, R, X, J (tones) + A, O, E, W (marks/diacritics) + D (stroke Đ) + Z (undo)
- **VNI processing keys**: 1-9, 0
- **`tempDisableKey`**: Set by `checkSpelling()` when the current syllable structure is invalid; blocks further transforms for that word.
- **`skipGrammarMarkNormalizationOnce`**: Suppresses one round of `checkGrammar()` during tone-mark cycling to preserve user intent.

### EngineResult decoding

Engine data values are decoded in `decodeEngineChar()`:
1. `PURE_CHARACTER_MASK` set → raw Unicode in lower 16 bits
2. `CHAR_CODE_MASK` set → resolved Unicode in lower 16 bits
3. Neither → raw key code, look up via `vnKeyCodeToCharacter()`

Output is converted to NFC precomposed Unicode (`precomposedStringWithCanonicalMapping`) for app compatibility.

### Hotkey detection (`EventRouter.swift`)

Two independent hotkey styles are supported:

| Style | Setting | Detection |
|---|---|---|
| Modifier-only (e.g. Ctrl+Shift) | `hotkeyModifierMask` | `checkModifierHotkey()` — triggers on first modifier **release** after the full combo was held without any other key |
| Modifier + key (e.g. Ctrl+Space) | `secondaryHotkeyKeyCode` + `secondaryHotkeyModifiers` | `checkKeyDownHotkey()` — triggers on keyDown of the key with matching modifiers |

`keyPressedWhileModifiersHeld` guards against accidental triggers when Ctrl+Shift+X is typed. It is reset when:
- A new modifier chord begins (`currentModifiers > previousModifiers` branch)
- Any modifier is released (`currentModifiers < previousModifiers` branch)
- All modifiers are released (`currentModifiers == 0`)

### Spell checking (`EngineSpelling.swift`)

Controlled by `EngineConfig.checkSpelling`. When enabled:

- `checkSpelling()` validates the current buffer as a Vietnamese syllable: consonant cluster → vowel nucleus → end consonant.
- Sets `spellingOK` (full syllable valid), `spellingVowelOK` (vowel part valid), and `tempDisableKey` (blocks further transforms).
- `checkGrammar()` auto-normalises tone mark placement (e.g. moves sắc from first to second vowel in `oa`, `oe` combos) according to modern/old orthography rules.
- **Key edge case**: Unrecognised consonant starts (e.g. `f`, `j`, `fj`) are not in `vnConsonantTable` with `allowConsonantZFWJ = false` → `!matched → spellingOK = true` → transforms proceed regardless of spell check setting.

## Conventions

- `@inline(__always)` on hot-path engine helpers
- Engine returns value types; caller handles all I/O
- Synthetic events marked with `EventMarker.vietKey` on `eventSourceUserData`
- Key codes use Mac virtual key codes (not ASCII) — e.g., `KEY_A = 0`, `KEY_S = 1`
- `EngineConfig` struct replaces PHTV's C bridge calls for runtime settings
- Test helper `type("string")` simulates keystrokes through the engine
- `UserSettings.apply(to:)` is the single point where settings flow to `InputController`

## Bug fixes applied

### 1. Restore does not output full raw sequence (EngineHandler.swift)
After a `.restore` action (e.g. `đ` + `d` → should output `dd`), `hNCC` and `hData` were not updated to include the newly typed key. Fixed by capturing `prevHNCC`, shifting `hData`, setting `hData[0]` to the restored character, and setting `hNCC = prevHNCC + 1`. Applies to all restorable keys (D, A, E, O, W).

### 2. KEY_O restore re-cycled on next `o` (EngineComposition.swift — insertAOE)
After a restore, `tempDisableKey` was not set for `KEY_O` (unlike other keys), allowing the next `o` press to cycle back to `ô`. Fixed by always setting `tempDisableKey = true` on restore, matching iOS Telex behaviour.

### 3. `ấ` + `a` expanded to `áaa` instead of `áa` (EngineComposition.swift)
`tryExpandMarkedAOEElongation()` was called before `shouldAppendRawElongatedVowel()` in `handleMainKey`, incorrectly expanding a tone-marked single vowel. Fixed by removing the `tryExpandMarkedAOEElongation` call and updating `shouldAppendRawElongatedVowel` to return `false` for any single A/E vowel with any mark (`(trailing & MARK_MASK) != 0`), letting `insertAOE` handle cycling and restore.

### 4. `ắ` + `a` stayed as `ắa` instead of cycling to `ấ` (EngineComposition.swift)
Same root cause as fix 3 — `shouldAppendRawElongatedVowel` was returning `true` for single toned vowels with only a `TONEW_MASK`/`TONE_MASK` diacritic (no `MARK_MASK`). The refined condition (`(trailing & MARK_MASK) != 0`) covers all mark types and lets the AOE cycling logic resolve the vowel correctly.

### 5. Language switch shortcut requires two presses after typing (EventRouter.swift)
`markKeyPressedWhileModifiersHeld()` is called on every `keyDown`, including normal letter keys with no modifiers held. Because `keyPressedWhileModifiersHeld` was only reset on modifier *release* (not on the start of a new modifier chord), normal typing always left the flag `true`. The first Ctrl+Shift press then failed the `!keyPressedWhileModifiersHeld` guard. Fixed by resetting the flag in the `currentModifiers > previousModifiers` branch of `checkModifierHotkey()`.

## Planned (not yet implemented)

- Phase 4: Game mode (2-tier callback, <100us fast path, no AX)
- Phase 6: Code signing, notarization, distribution
