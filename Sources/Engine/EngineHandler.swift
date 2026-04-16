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
        var lookupLen = rawStateLen
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
        if config.restoreOnEscape && bufferLen > 0 && data == KEY_ESC {
            if restoreToRawKeys() { return }
        }

        isCaps = (capsStatus == 1 || capsStatus == 2)
        let isAutoRestoreBreakKey = isAutoRestoreWordBreak(event: event, state: state, data: data, capsStatus: capsStatus)
        let isBracketAutoRestore = isBracketPunctuationBreak(data) && getEnglishLookupStateLength() > 2

        if (isNumberKey(data) && capsStatus == 1) || otherControlKey || isAutoRestoreBreakKey || isBracketAutoRestore || (bufferLen == 0 && isNumberKey(data)) {
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
        actionCode = EngineAction.doNothing.rawValue
        backspaceCount = 0; newCharCount = 0; extCode = 1

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
            extCode = 3
        }

        if actionCode == EngineAction.doNothing.rawValue {
            startNewSession(); willTempOffEngine = false
        }
    }

    func checkRestoreIfWrongSpelling(_ handleCode: Int32) -> Bool {
        for ii in 0..<bufferLen {
            if !isConsonant(chr(ii)) &&
               ((typingWord[ii] & MARK_MASK) != 0 || (typingWord[ii] & TONE_MASK) != 0 || (typingWord[ii] & TONEW_MASK) != 0) {
                actionCode = handleCode
                backspaceCount = bufferLen
                newCharCount = rawStateLen
                for i in 0..<rawStateLen {
                    typingWord[i] = keyStates[i]
                    outputData[rawStateLen - 1 - i] = typingWord[i]
                }
                bufferLen = rawStateLen
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
                // outputData is stored in reverse (index 0 = last char), so shift right and insert at 0.
                if newCharCount < outputData.count {
                    for j in stride(from: newCharCount - 1, through: 0, by: -1) {
                        outputData[j + 1] = outputData[j]
                    }
                    outputData[0] = UInt32(0x0020) | PURE_CHARACTER_MASK
                    newCharCount += 1
                }
            } else {
                actionCode = EngineAction.doNothing.rawValue
            }
            spaceCount += 1
        } else {
            actionCode = EngineAction.doNothing.rawValue; spaceCount += 1
        }

        if spaceCount == 1 {
            if !specialChar.isEmpty { saveSpecialChar() } else { saveWord() }
        }
        willTempOffEngine = false
    }

    // MARK: - Delete Handler

    func handleDelete() {
        actionCode = EngineAction.doNothing.rawValue; extCode = 2; tempDisableKey = false
        if !specialChar.isEmpty {
            specialChar.removeLast()
            if specialChar.isEmpty { restoreLastTypingState() }
        } else if spaceCount > 0 {
            spaceCount -= 1
            if spaceCount == 0 { restoreLastTypingState() }
        } else {
            if rawStateLen > 0 { rawStateLen -= 1 }
            if bufferLen > 0 {
                bufferLen -= 1
                if !longWordHelper.isEmpty {
                    for i in stride(from: ENGINE_MAX_BUFF - 1, through: 1, by: -1) { typingWord[i] = typingWord[i - 1] }
                    typingWord[0] = longWordHelper.removeLast()
                    bufferLen += 1
                }
                if config.checkSpelling { checkSpelling() }
            }
            backspaceCount = 0; newCharCount = 0; extCode = 2
            if bufferLen == 0 {
                startNewSession()
                specialChar.removeAll(); restoreLastTypingState()
            } else {
                checkGrammar(deltaBackSpace: 1)
            }
        }
    }

    // MARK: - Main Flow Handler

    func handleMainFlow(state: InputEventState, data: UInt16, otherControlKey: Bool) {
        guard !willTempOffEngine else { actionCode = EngineAction.doNothing.rawValue; extCode = 3; return }

        flushPendingSessionState()
        insertState(data, isCaps)

        let shouldProcess = resolveSpellGate(data: data)
        resetOutputState()
        if shouldProcess {
            handleMainKey(data, isCaps)
        } else {
            insertKey(data, isCaps)
        }

        postProcessKey(data)
    }

    // MARK: - Main Flow Helpers

    private func flushPendingSessionState() {
        if spaceCount > 0 {
            backspaceCount = 0; newCharCount = 0; extCode = 0
            let savedSpaceCount = spaceCount
            startNewSession()
            saveWord(UInt32(KEY_SPACE), savedSpaceCount)
        } else if !specialChar.isEmpty {
            saveSpecialChar()
        }
    }

    private func resetOutputState() {
        actionCode = EngineAction.doNothing.rawValue
        backspaceCount = 0; newCharCount = 0; extCode = 3
    }

    /// Returns true if the key should be processed as a Vietnamese special key.
    private func resolveSpellGate(data: UInt16) -> Bool {
        guard isSpecialKey(data) else { return false }
        guard !unrecognizedConsonantStart || !isMarkKey(data) else { return false }
        guard tempDisableKey else { return true }
        return allowSpecialKeyDespiteDisable(data: data)
    }

    private func allowSpecialKeyDespiteDisable(data: UInt16) -> Bool {
        let allowMark = isMarkKey(data)
        var allowVowelChange = false

        if !allowMark && (isKeyDouble(data) || isKeyW(data) || isBracketKey(data)) {
            allowVowelChange = (0..<bufferLen).contains {
                (typingWord[$0] & (MARK_MASK | TONE_MASK | TONEW_MASK)) != 0
            }
        }

        var allow = allowMark || allowVowelChange
        if config.checkSpelling && allow {
            checkSpelling(forceCheckVowel: true)
            if tempDisableKey && allowMark {
                allow = canApplyMarkDespiteInvalidSpelling(data: data)
            }
        }
        return allow
    }

    private func canApplyMarkDespiteInvalidSpelling(data: UInt16) -> Bool {
        let hasToneW = (0..<bufferLen).contains { (typingWord[$0] & TONEW_MASK) != 0 }
        let allowOnInvalidVowel      = spellingOK && !spellingVowelOK && canFixVowelWithDiacriticsForMark()
        let allowOnInvalidConsonant  = !spellingOK && spellingVowelOK && hasToneW
        let allowElongated           = canFixVowelWithDiacriticsForElongatedMark(data)
        return allowOnInvalidVowel || allowOnInvalidConsonant || hasToneW || allowElongated
    }

    private func postProcessKey(_ data: UInt16) {
        if !isKeyD(data) {
            let delta = actionCode == EngineAction.doNothing.rawValue ? -1 : 0
            checkGrammar(deltaBackSpace: delta)
        }

        if actionCode == EngineAction.restore.rawValue {
            appendRestoredKey(data)
        }

        if isBracketKey(data) && isBracketKey(UInt16(outputData[0] & CHAR_MASK)) {
            commitBracketChar(data)
        }
    }

    private func appendRestoredKey(_ data: UInt16) {
        // Include the newly typed key in the restore output so the display matches the
        // buffer — e.g. 'đ' + 'd' → outputs 'dd', matching iOS Telex behaviour.
        let prevCount = newCharCount
        insertKey(data, isCaps)
        guard prevCount < outputData.count else { return }
        for j in stride(from: prevCount - 1, through: 0, by: -1) {
            outputData[j + 1] = outputData[j]
        }
        outputData[0] = get(typingWord[bufferLen - 1])
        newCharCount = prevCount + 1
    }

    private func commitBracketChar(_ data: UInt16) {
        if bufferLen - (actionCode == EngineAction.willProcess.rawValue ? backspaceCount : 0) > 0 {
            bufferLen -= 1; saveWord()
        }
        bufferLen = 0; tempDisableKey = false; rawStateLen = 0; extCode = 3
        specialChar.append(UInt32(data) | (isCaps ? CAPS_MASK : 0))
    }

    // MARK: - Init

    func vKeyInit() {
        bufferLen = 0; rawStateLen = 0
        typingStatesData.removeAll(); typingStates.removeAll(); longWordHelper.removeAll()
    }
}
