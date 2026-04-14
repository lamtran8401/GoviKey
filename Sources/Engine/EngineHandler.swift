// VietnameseEngine+Handler.swift
// GoviKey Engine
//
// Event handlers: main event dispatch, word break, space, delete, main flow.

import Foundation

extension VietnameseEngine {

    // MARK: - Word Break Helpers

    func isWordBreak(event: InputEvent, state: InputEventState, data: UInt16) -> Bool {
        if event == .mouse { return true }
        return kBreakCode.contains(data)
    }

    func isBracketPunctuationBreak(_ data: UInt16) -> Bool {
        data == KEY_LEFT_BRACKET || data == KEY_RIGHT_BRACKET
    }

    func isShiftedNumericPunctuationBreak(_ data: UInt16, _ capsStatus: UInt8) -> Bool {
        guard capsStatus == 1 else { return false }
        return data == KEY_1 || data == KEY_9 || data == KEY_0
    }

    func isAutoRestoreWordBreak(event: InputEvent, state: InputEventState, data: UInt16, capsStatus: UInt8) -> Bool {
        isWordBreak(event: event, state: state, data: data) ||
        isShiftedNumericPunctuationBreak(data, capsStatus)
    }

    func getEnglishLookupStateLength() -> Int {
        var lookupLen = stateIdx
        while lookupLen > 0 {
            let kc = UInt16(keyStates[lookupLen - 1] & UInt32(CHAR_MASK))
            if isEnglishLetterKeyCode(kc) { break }
            lookupLen -= 1
        }
        return lookupLen
    }

    func isEnglishLetterKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J,
             KEY_K, KEY_L, KEY_M, KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T,
             KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z: return true
        default: return false
        }
    }

    // MARK: - Main Event Handler

    func vKeyHandleEvent(event: InputEvent, state: InputEventState, data: UInt16, capsStatus: UInt8, otherControlKey: Bool) {
        if config.restoreOnEscape && idx > 0 && data == KEY_ESC {
            if restoreToRawKeys() { return }
        }

        isCaps = (capsStatus == 1 || capsStatus == 2)
        let isAutoRestoreBreakKey = isAutoRestoreWordBreak(event: event, state: state, data: data, capsStatus: capsStatus)
        let isBracketAutoRestore = isBracketPunctuationBreak(data) && getEnglishLookupStateLength() > 2

        if (isNumberKey(data) && capsStatus == 1) || otherControlKey || isAutoRestoreBreakKey || isBracketAutoRestore || (idx == 0 && isNumberKey(data)) {
            handleWordBreak(event: event, state: state, data: data, capsStatus: capsStatus, otherControlKey: otherControlKey, isAutoRestoreBreakKey: isAutoRestoreBreakKey || isBracketAutoRestore)
        } else if data == KEY_SPACE {
            handleSpace(state: state, data: data)
        } else if data == KEY_DELETE {
            handleDelete()
        } else {
            handleMainFlow(state: state, data: data, otherControlKey: otherControlKey)
        }
    }

    // MARK: - Word Break Handler

    func handleWordBreak(event: InputEvent, state: InputEventState, data: UInt16, capsStatus: UInt8, otherControlKey: Bool, isAutoRestoreBreakKey: Bool) {
        hCode = EngineAction.doNothing.rawValue
        hBPC = 0; hNCC = 0; hExt = 1

        if (config.quickStartConsonant || config.quickEndConsonant) &&
            !tempDisableKey && checkQuickConsonant() {
            // Quick consonant handled
        } else if isAutoRestoreBreakKey {
            if config.checkSpelling { checkSpelling(forceCheckVowel: true) }
            if tempDisableKey && config.restoreIfWrongSpelling {
                _ = checkRestoreIfWrongSpelling(EngineAction.restoreAndStartNewSession.rawValue)
            }
        }

        isCharKeyCode = state == .keyDown && kCharKeyCode.contains(data)
        if !isCharKeyCode {
            specialChar.removeAll(); typingStates.removeAll()
        } else {
            if spaceCount > 0 { saveWord(UInt32(KEY_SPACE), spaceCount); spaceCount = 0 } else { saveWord() }
            specialChar.append(UInt32(data) | (isCaps ? CAPS_MASK : 0))
            hExt = 3
        }

        if hCode == EngineAction.doNothing.rawValue {
            startNewSession(); willTempOffEngine = false
        }
    }

    func checkRestoreIfWrongSpelling(_ handleCode: Int32) -> Bool {
        for ii in 0..<idx {
            if !isConsonant(chr(ii)) &&
               ((typingWord[ii] & MARK_MASK) != 0 || (typingWord[ii] & TONE_MASK) != 0 || (typingWord[ii] & TONEW_MASK) != 0) {
                hCode = handleCode
                hBPC = idx
                hNCC = stateIdx
                for i in 0..<stateIdx {
                    typingWord[i] = keyStates[i]
                    hData[stateIdx - 1 - i] = typingWord[i]
                }
                idx = stateIdx
                return true
            }
        }
        return false
    }

    // MARK: - Space Handler

    func handleSpace(state: InputEventState, data: UInt16) {
        if (config.quickStartConsonant || config.quickEndConsonant) &&
            !tempDisableKey && checkQuickConsonant() {
            spaceCount += 1
        } else if tempDisableKey {
            if config.restoreIfWrongSpelling && checkRestoreIfWrongSpelling(EngineAction.restore.rawValue) {
                // Restore succeeded — the Space event will be consumed by EventRouter,
                // so append the Space character to the output directly.
                // hData is stored in reverse (index 0 = last char), so shift right and insert at 0.
                if hNCC < hData.count {
                    for j in stride(from: hNCC - 1, through: 0, by: -1) {
                        hData[j + 1] = hData[j]
                    }
                    hData[0] = UInt32(0x0020) | PURE_CHARACTER_MASK
                    hNCC += 1
                }
            } else {
                hCode = EngineAction.doNothing.rawValue
            }
            spaceCount += 1
        } else {
            hCode = EngineAction.doNothing.rawValue; spaceCount += 1
        }

        if spaceCount == 1 {
            if !specialChar.isEmpty { saveSpecialChar() } else { saveWord() }
        }
        willTempOffEngine = false
    }

    // MARK: - Delete Handler

    func handleDelete() {
        hCode = EngineAction.doNothing.rawValue; hExt = 2; tempDisableKey = false
        if !specialChar.isEmpty {
            specialChar.removeLast()
            if specialChar.isEmpty { restoreLastTypingState() }
        } else if spaceCount > 0 {
            spaceCount -= 1
            if spaceCount == 0 { restoreLastTypingState() }
        } else {
            if stateIdx > 0 { stateIdx -= 1 }
            if idx > 0 {
                idx -= 1
                if !longWordHelper.isEmpty {
                    for i in stride(from: ENGINE_MAX_BUFF - 1, through: 1, by: -1) { typingWord[i] = typingWord[i - 1] }
                    typingWord[0] = longWordHelper.removeLast()
                    idx += 1
                }
                if config.checkSpelling { checkSpelling() }
            }
            hBPC = 0; hNCC = 0; hExt = 2
            if idx == 0 {
                startNewSession()
                specialChar.removeAll(); restoreLastTypingState()
            } else {
                checkGrammar(deltaBackSpace: 1)
            }
        }
    }

    // MARK: - Main Flow Handler

    func handleMainFlow(state: InputEventState, data: UInt16, otherControlKey: Bool) {
        if willTempOffEngine { hCode = EngineAction.doNothing.rawValue; hExt = 3; return }

        if spaceCount > 0 {
            hBPC = 0; hNCC = 0; hExt = 0
            let savedSpaceCount = spaceCount
            startNewSession()
            saveWord(UInt32(KEY_SPACE), savedSpaceCount)
        } else if !specialChar.isEmpty {
            saveSpecialChar()
        }

        insertState(data, isCaps)

        // Spell gate
        let allowMarkDespiteTempDisable = isMarkKey(data)
        var allowVowelChangeDespiteTempDisable = false
        if tempDisableKey && isSpecialKey(data) && !allowMarkDespiteTempDisable {
            if isKeyDouble(data) || isKeyW(data) || isBracketKey(data) {
                var hasToneOrDiacritic = false
                for scan in 0..<idx where (typingWord[scan] & (MARK_MASK | TONE_MASK | TONEW_MASK)) != 0 {
                    hasToneOrDiacritic = true; break
                }
                allowVowelChangeDespiteTempDisable = hasToneOrDiacritic
            }
        }
        var allowSpecialDespiteTempDisable = allowMarkDespiteTempDisable || allowVowelChangeDespiteTempDisable
        if config.checkSpelling && allowSpecialDespiteTempDisable {
            checkSpelling(forceCheckVowel: true)
            if tempDisableKey && allowMarkDespiteTempDisable {
                var hasToneWTransform = false
                if idx > 0 {
                    for scan in 0..<idx where (typingWord[scan] & TONEW_MASK) != 0 {
                        hasToneWTransform = true; break
                    }
                }
                let allowElongatedTonePlacement = canFixVowelWithDiacriticsForElongatedMark(data)
                let allowToneOnInvalidVowel =
                    spellingOK && !spellingVowelOK && canFixVowelWithDiacriticsForMark()
                let allowToneOnInvalidEndConsonant = !spellingOK && spellingVowelOK && hasToneWTransform
                let allowToneOnInvalid =
                    allowToneOnInvalidVowel || allowToneOnInvalidEndConsonant ||
                    hasToneWTransform || allowElongatedTonePlacement
                if !allowToneOnInvalid { allowSpecialDespiteTempDisable = false }
            }
        }

        // Block tone marks on words with unrecognized consonant starts (English words).
        // e.g. "featur" should not become "featủ" — r is blocked as a tone key.
        let blockMarkForUnrecognizedStart = unrecognizedConsonantStart && isMarkKey(data)

        if !isSpecialKey(data) || (tempDisableKey && !allowSpecialDespiteTempDisable) || blockMarkForUnrecognizedStart {
            hCode = EngineAction.doNothing.rawValue; hBPC = 0; hNCC = 0; hExt = 3
            insertKey(data, isCaps)
        } else {
            hCode = EngineAction.doNothing.rawValue; hBPC = 0; hNCC = 0; hExt = 3
            handleMainKey(data, isCaps)
        }

        // Post
        if !isKeyD(data) {
            if hCode == EngineAction.doNothing.rawValue { checkGrammar(deltaBackSpace: -1) } else { checkGrammar(deltaBackSpace: 0) }
        }

        if hCode == EngineAction.restore.rawValue {
            let prevHNCC = hNCC
            insertKey(data, isCaps)
            // Include the newly typed key in the output so the display matches the buffer.
            // e.g. 'đ' + 'd' → restore outputs 'dd' (not just 'd'), matching iOS Telex behavior.
            if prevHNCC < hData.count {
                for j in stride(from: prevHNCC - 1, through: 0, by: -1) {
                    hData[j + 1] = hData[j]
                }
                hData[0] = get(typingWord[idx - 1])
                hNCC = prevHNCC + 1
            }
        }

        if isBracketKey(data) && (isBracketKey(UInt16(hData[0] & CHAR_MASK)) || false) {
            if idx - (hCode == EngineAction.willProcess.rawValue ? hBPC : 0) > 0 {
                idx -= 1; saveWord()
            }
            idx = 0; tempDisableKey = false; stateIdx = 0; hExt = 3
            specialChar.append(UInt32(data) | (isCaps ? CAPS_MASK : 0))
        }
    }

    // MARK: - Init

    func vKeyInit() {
        idx = 0; stateIdx = 0
        typingStatesData.removeAll(); typingStates.removeAll(); longWordHelper.removeAll()
    }
}
