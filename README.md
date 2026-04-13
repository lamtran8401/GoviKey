# GoviKey

Vietnamese input method (IME) for macOS — pure Swift, no Apple IME framework required.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Telex** and **VNI** input methods
- iOS-like restore behaviour — pressing the same key twice reverts to raw (e.g. `đ` + `d` → `dd`)
- Tone mark cycling: `ắ` + `a` → `ấ`
- Vietnamese spell checking — blocks invalid syllable structures
- Modern and classic orthography modes (`hoàng` vs `hoàng`)
- Auto capitalize first character
- Game mode — minimal latency, skips Accessibility API
- Per-app game mode classification (Riot, Blizzard, Steam, Epic, EA, Ubisoft, …)
- Configurable language-switch shortcut (modifier-only or modifier + key)
- Switch sound with volume control
- Menu bar indicator (`Vi` / `En`)
- No dock icon (LSUIElement)

---

## Requirements

| | Minimum |
|---|---|
| macOS | 13 Ventura |
| Swift | 5.9 |
| Xcode | 15 |
| Permission | Accessibility (System Settings → Privacy & Security) |

---

## Build & Run

```bash
# Clone
git clone https://github.com/yourname/govikey.git
cd govikey/VietKey

# Build
swift build

# Run (requires Accessibility permission granted first)
swift run GoviKey

# Run tests
swift test
```

> **Note:** `swift test` and `swift run` require Accessibility permission. Grant it in  
> **System Settings → Privacy & Security → Accessibility**, then re-run.

---

## Input Methods

### Telex

| Key(s) | Output |
|--------|--------|
| `aa` | â |
| `aw` | ă |
| `oo` | ô |
| `ow` / `uw` | ơ / ư |
| `ee` | ê |
| `dd` | đ |
| `s` | sắc (´) |
| `f` | huyền (`) |
| `r` | hỏi (?) |
| `x` | ngã (~) |
| `j` | nặng (.) |
| `z` | undo last mark |

Pressing the same composition key twice restores raw input:  
`â` + `a` → `aa`, `ô` + `o` → `oo`, `đ` + `d` → `dd`

### VNI

| Key | Tone |
|-----|------|
| `1` | sắc |
| `2` | huyền |
| `3` | hỏi |
| `4` | ngã |
| `5` | nặng |
| `6` | circumflex (â, ô, ê) |
| `7` | horn (ư, ơ) |
| `8` | breve (ă) |
| `9` | đ |
| `0` | undo |

---

## Architecture

```
Sources/
  Engine/        Pure Swift state machine — no system dependencies
  EventTap/      CGEventTap bridge, output sender, hotkey detection
  App/           NSStatusItem menu bar, SwiftUI settings window
Tests/
  EngineTests/   Unit tests for composition, tones, spelling, orthography
```

### Data flow

```
User keystroke
  → CGEventTap (HID level)
  → InputController
      → VietnameseEngine.handleKeyEvent()
      → EngineResult { backspaceCount, newCharCount, chars[] }
  → KeyEventSender: send backspaces + inject Unicode (NFC precomposed)
```

Self-generated events are tagged with a `"GOVI"` marker on `eventSourceUserData` and skipped by the tap to prevent feedback loops.

---

## Settings

| Setting | Description |
|---------|-------------|
| Input method | Telex / VNI |
| Spell check | Block transforms that produce invalid Vietnamese syllables |
| Modern orthography | Use new tone placement rules (e.g. `hoàng` not `hoàng`) |
| Quick Telex | Expand consonant shortcuts (e.g. `cc` → `ch`) |
| Free mark (Z F W J) | Allow tone/mark keys without a vowel in buffer |
| Auto capitalize | Uppercase first character of each word |
| Game mode | Fast path — no Accessibility API, minimal latency |
| Switch shortcut | Modifier-only (e.g. Ctrl+Shift) or modifier + key (e.g. Ctrl+Space) |
| Switch sound | Play a sound when toggling input mode |

---

## Permissions

GoviKey uses `CGEventTap` at the HID level to intercept keystrokes system-wide. macOS requires **Accessibility permission** for this.

1. Open **System Settings → Privacy & Security → Accessibility**
2. Add and enable **GoviKey**
3. Restart GoviKey if it was already running

---

## Contributing

1. Fork the repo
2. Create a feature branch
3. Run `swift test` — all tests must pass
4. Open a pull request

See `CLAUDE.md` for architecture notes and `MEMORY.md` for known invariants before making engine changes.

---

## License

MIT
