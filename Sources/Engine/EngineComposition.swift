// VietnameseEngine+Composition.swift
// GoviKey Engine
//
// Character composition: insert D, AOE, W, standalone, elongated vowels,
// quick telex, quick consonant, restore operations, main key handling.

import Foundation

extension VietnameseEngine {

    // MARK: - Insert D

    func insertD(_ data: UInt16, _ isCaps: Bool) {
        actionCode = EngineAction.willProcess.rawValue; backspaceCount = 0
        var ii = bufferLen - 1
        while ii >= 0 {
            backspaceCount += 1
            if chr(ii) == KEY_D {
                if (typingWord[ii] & TONE_MASK) != 0 {
                    actionCode = EngineAction.restore.rawValue
                    typingWord[ii] &= ~TONE_MASK
                    outputData[bufferLen - 1 - ii] = get(typingWord[ii])
                    tempDisableKey = true
                } else {
                    typingWord[ii] |= TONE_MASK
                    outputData[bufferLen - 1 - ii] = get(typingWord[ii])
                }
                break
            } else {
                outputData[bufferLen - 1 - ii] = get(typingWord[ii])
            }
            ii -= 1
        }
        newCharCount = backspaceCount
    }

    // MARK: - Insert AOE

    func insertAOE(_ data: UInt16, _ isCaps: Bool) {
        findAndCalculateVowel()
        let shouldPreserveEarlierMarkedVowelForCycle =
            vowelEnd == bufferLen - 1 &&
            chr(bufferLen - 1) == data &&
            (typingWord[bufferLen - 1] & (MARK_MASK | TONE_MASK | TONEW_MASK)) == 0 &&
            (data == KEY_A || data == KEY_E || data == KEY_O) &&
            (vowelStart..<(bufferLen - 1)).contains { (typingWord[$0] & MARK_MASK) != 0 }
        for ii in vowelStart...vowelEnd { typingWord[ii] &= ~TONEW_MASK }
        actionCode = EngineAction.willProcess.rawValue; backspaceCount = 0
        var ii = bufferLen - 1
        while ii >= 0 {
            backspaceCount += 1
            if chr(ii) == data {
                if (typingWord[ii] & TONE_MASK) != 0 {
                    actionCode = EngineAction.restore.rawValue
                    typingWord[ii] &= ~TONE_MASK
                    outputData[bufferLen - 1 - ii] = get(typingWord[ii])
                    tempDisableKey = true
                } else {
                    typingWord[ii] |= TONE_MASK
                    if !isKeyD(data) { typingWord[ii] &= ~TONEW_MASK }
                    if shouldPreserveEarlierMarkedVowelForCycle && ii == bufferLen - 1 {
                        skipGrammarMarkNormalizationOnce = true
                    }
                    outputData[bufferLen - 1 - ii] = get(typingWord[ii])
                }
                break
            } else {
                outputData[bufferLen - 1 - ii] = get(typingWord[ii])
            }
            ii -= 1
        }
        newCharCount = backspaceCount
    }

    // MARK: - Insert W

    func insertW(_ data: UInt16, _ isCaps: Bool) {
        wasWRestored = false
        findAndCalculateVowel()
        for ii in vowelStart...vowelEnd { typingWord[ii] &= ~TONE_MASK }

        if vowelCount > 1 {
            backspaceCount = bufferLen - vowelStart; newCharCount = backspaceCount
            let both = (typingWord[vowelStart] & TONEW_MASK) != 0 && (typingWord[vowelStart + 1] & TONEW_MASK) != 0
            let withI = (typingWord[vowelStart] & TONEW_MASK) != 0 && chr(vowelStart + 1) == KEY_I
            let withA = (typingWord[vowelStart] & TONEW_MASK) != 0 && chr(vowelStart + 1) == KEY_A
            if both || withI || withA {
                actionCode = EngineAction.restore.rawValue
                for ii in vowelStart..<bufferLen {
                    typingWord[ii] &= ~TONEW_MASK
                    outputData[bufferLen - 1 - ii] = get(typingWord[ii]) & ~STANDALONE_MASK
                }
                wasWRestored = true; tempDisableKey = true
            } else {
                actionCode = EngineAction.willProcess.rawValue
                var shouldRestore = false
                if chr(vowelStart) == KEY_U && chr(vowelStart + 1) == KEY_O {
                    let isThu = vowelStart - 2 >= 0 && typingWord[vowelStart - 2] == UInt32(KEY_T) && typingWord[vowelStart - 1] == UInt32(KEY_H)
                    let isQuo = vowelStart - 1 >= 0 && typingWord[vowelStart - 1] == UInt32(KEY_Q)
                    if isThu {
                        if (typingWord[vowelStart + 1] & TONEW_MASK) != 0 { shouldRestore = true }
                        else {
                            typingWord[vowelStart + 1] |= TONEW_MASK
                            if vowelStart + 2 < bufferLen && chr(vowelStart + 2) == KEY_N { typingWord[vowelStart] |= TONEW_MASK }
                        }
                    } else if isQuo {
                        if (typingWord[vowelStart + 1] & TONEW_MASK) != 0 { shouldRestore = true }
                        else { typingWord[vowelStart + 1] |= TONEW_MASK }
                    } else {
                        if (typingWord[vowelStart] & TONEW_MASK) != 0 && (typingWord[vowelStart + 1] & TONEW_MASK) == 0 {
                            typingWord[vowelStart + 1] |= TONEW_MASK
                        } else if (typingWord[vowelStart] & TONEW_MASK) != 0 || (typingWord[vowelStart + 1] & TONEW_MASK) != 0 {
                            shouldRestore = true
                        } else {
                            typingWord[vowelStart] |= TONEW_MASK; typingWord[vowelStart + 1] |= TONEW_MASK
                        }
                    }
                } else if (chr(vowelStart) == KEY_U && chr(vowelStart + 1) == KEY_A) ||
                          (chr(vowelStart) == KEY_U && chr(vowelStart + 1) == KEY_I) ||
                          (chr(vowelStart) == KEY_U && chr(vowelStart + 1) == KEY_U) ||
                          (chr(vowelStart) == KEY_O && chr(vowelStart + 1) == KEY_I) {
                    if (typingWord[vowelStart] & TONEW_MASK) != 0 { shouldRestore = true }
                    else { typingWord[vowelStart] |= TONEW_MASK }
                } else if (chr(vowelStart) == KEY_I && chr(vowelStart + 1) == KEY_O) ||
                          (chr(vowelStart) == KEY_O && chr(vowelStart + 1) == KEY_A) {
                    if (typingWord[vowelStart + 1] & TONEW_MASK) != 0 { shouldRestore = true }
                    else { typingWord[vowelStart + 1] |= TONEW_MASK }
                } else {
                    // eu/ei and other unrecognised multi-vowel+w combos: insert literal w
                    // and keep didTransform=true so the !didTransform fallback in handleMainKey
                    // does NOT create a spurious standalone ư.
                    tempDisableKey = true; actionCode = EngineAction.doNothing.rawValue
                    insertKey(data, isCaps, false)
                }
                if shouldRestore {
                    actionCode = EngineAction.restore.rawValue
                    for ii in vowelStart..<bufferLen {
                        typingWord[ii] &= ~TONEW_MASK
                        outputData[bufferLen - 1 - ii] = get(typingWord[ii]) & ~STANDALONE_MASK
                    }
                    wasWRestored = true; tempDisableKey = true
                } else if actionCode == EngineAction.willProcess.rawValue {
                    for ii in vowelStart..<bufferLen { outputData[bufferLen - 1 - ii] = get(typingWord[ii]) }
                }
            }
            return
        }

        actionCode = EngineAction.willProcess.rawValue; backspaceCount = 0
        var ii = bufferLen - 1
        while ii >= 0 {
            if ii < vowelStart { break }
            backspaceCount += 1
            switch chr(ii) {
            case KEY_A, KEY_U, KEY_O:
                if (typingWord[ii] & TONEW_MASK) != 0 {
                    if (typingWord[ii] & STANDALONE_MASK) != 0 {
                        actionCode = EngineAction.willProcess.rawValue
                        if chr(ii) == KEY_U {
                            typingWord[ii] = UInt32(KEY_W) | ((typingWord[ii] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                        } else if chr(ii) == KEY_O {
                            actionCode = EngineAction.restore.rawValue
                            typingWord[ii] = UInt32(KEY_O) | ((typingWord[ii] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                            wasWRestored = true
                        }
                        outputData[bufferLen - 1 - ii] = get(typingWord[ii])
                    } else {
                        actionCode = EngineAction.restore.rawValue
                        typingWord[ii] &= ~TONEW_MASK
                        outputData[bufferLen - 1 - ii] = get(typingWord[ii])
                        wasWRestored = true
                    }
                    tempDisableKey = true
                } else {
                    typingWord[ii] |= TONEW_MASK; typingWord[ii] &= ~TONE_MASK
                    outputData[bufferLen - 1 - ii] = get(typingWord[ii])
                }
            default:
                outputData[bufferLen - 1 - ii] = get(typingWord[ii])
            }
            ii -= 1
        }
        newCharCount = backspaceCount
    }

    // MARK: - Standalone and Caps

    func reverseLastStandaloneChar(_ keyCode: UInt32, _ isCaps: Bool) {
        actionCode = EngineAction.willProcess.rawValue
        backspaceCount = 0; newCharCount = 1; extCode = 4
        typingWord[bufferLen - 1] = keyCode | TONEW_MASK | STANDALONE_MASK | (isCaps ? CAPS_MASK : 0)
        outputData[0] = get(typingWord[bufferLen - 1])
    }

    func checkForStandaloneChar(_ data: UInt16, _ isCaps: Bool, _ keyWillReverse: UInt16) {
        if bufferLen > 0 && chr(bufferLen - 1) == keyWillReverse && (typingWord[bufferLen - 1] & TONEW_MASK) != 0 {
            actionCode = EngineAction.willProcess.rawValue
            backspaceCount = 1; newCharCount = 1
            typingWord[bufferLen - 1] = UInt32(data) | (isCaps ? CAPS_MASK : 0)
            outputData[0] = get(typingWord[bufferLen - 1])
            return
        }
        if bufferLen > 0 && chr(bufferLen - 1) == KEY_U && keyWillReverse == KEY_O {
            insertKey(keyWillReverse, isCaps)
            reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
            return
        }
        if bufferLen == 0 {
            insertKey(data, isCaps, false)
            reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
            return
        } else if bufferLen == 1 {
            if vnStandaloneWBad.contains(chr(0)) {
                insertKey(data, isCaps)
                return
            }
            insertKey(data, isCaps, false)
            reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
            return
        } else if bufferLen == 2 {
            for pattern in vnDoubleWAllowed {
                if chr(0) == pattern[0] && chr(1) == pattern[1] {
                    insertKey(data, isCaps, false)
                    reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
                    return
                }
            }
            insertKey(data, isCaps)
            return
        }
        insertKey(data, isCaps)
    }

    // MARK: - Elongated Vowel Helpers

    func shouldAppendRawElongatedVowel(_ data: UInt16) -> Bool {
        guard bufferLen > 0, !isConsonant(data), chr(bufferLen - 1) == data else { return false }

        var runStart = bufferLen - 1
        while runStart > 0 && chr(runStart - 1) == data { runStart -= 1 }
        let runLength = bufferLen - runStart
        let trailing = typingWord[bufferLen - 1]

        // A single toned A/E vowel (with any diacritic or not) should cycle via insertAOE,
        // not be raw-appended as elongation. Let the AOE handler manage cycling.
        if (data == KEY_A || data == KEY_E) &&
           runLength == 1 &&
           (trailing & MARK_MASK) != 0 {
            return false
        }

        for ii in runStart..<bufferLen {
            guard (typingWord[ii] & MARK_MASK) != 0 else { continue }
            if data == KEY_O { return runLength >= 2 }
            if data == KEY_A || data == KEY_E { return true }
        }
        return false
    }

    func tryExpandMarkedAOEElongation(_ data: UInt16, _ isCaps: Bool) -> Bool {
        guard (data == KEY_A || data == KEY_E), bufferLen > 0, chr(bufferLen - 1) == data else { return false }

        var runStart = bufferLen - 1
        while runStart > 0 && chr(runStart - 1) == data { runStart -= 1 }
        guard bufferLen - runStart == 1 else { return false }

        let trailing = typingWord[bufferLen - 1]
        guard (trailing & MARK_MASK) != 0 else { return false }
        guard (trailing & TONE_MASK) != 0, (trailing & TONEW_MASK) == 0 else { return false }
        guard bufferLen + 1 < ENGINE_MAX_BUFF else { return false }

        findAndCalculateVowel()
        let vowelStart = vowelStart
        let oldIdx = bufferLen

        typingWord[bufferLen - 1] &= ~TONE_MASK
        setKeyData(bufferLen, data, isCaps)
        bufferLen += 1
        setKeyData(bufferLen, data, isCaps)
        bufferLen += 1

        actionCode = EngineAction.willProcess.rawValue
        extCode = 0
        backspaceCount = oldIdx - vowelStart
        newCharCount = bufferLen - vowelStart

        var outIndex = 0
        for ii in stride(from: bufferLen - 1, through: vowelStart, by: -1) {
            outputData[outIndex] = get(typingWord[ii])
            outIndex += 1
        }

        didTransform = true
        return true
    }

    func tryInsertMarkForElongatedTrailingVowel(_ data: UInt16) -> Bool {
        guard let markMask = markMask(for: data), bufferLen >= 3 else { return false }

        let tailVowel = chr(bufferLen - 1)
        guard !isConsonant(tailVowel) else { return false }

        var tailStart = bufferLen - 1
        while tailStart > 0 && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
        guard bufferLen - tailStart >= 2, tailStart > 0 else { return false }

        var hasExistingMark = false
        for ii in 0..<bufferLen where (typingWord[ii] & MARK_MASK) != 0 {
            hasExistingMark = true
            break
        }
        guard !hasExistingMark else { return false }

        let savedTypingWord = typingWord
        let savedIdx = bufferLen
        let savedHCode = actionCode
        let savedExt = extCode
        let savedBPC = backspaceCount
        let savedNCC = newCharCount
        let savedHData = outputData
        let savedIsChanged = didTransform
        let savedTempDisable = tempDisableKey
        let savedVowelCount = vowelCount
        let savedVSI = vowelStart
        let savedVEI = vowelEnd
        let savedVWSM = markPosition

        bufferLen = tailStart + 1
        insertMark(markMask, canModifyFlag: false)

        var applied = false
        for ii in 0..<bufferLen where (typingWord[ii] & MARK_MASK) == markMask {
            applied = true
            break
        }

        if !applied {
            typingWord = savedTypingWord
            bufferLen = savedIdx
            actionCode = savedHCode
            extCode = savedExt
            backspaceCount = savedBPC
            newCharCount = savedNCC
            outputData = savedHData
            didTransform = savedIsChanged
            tempDisableKey = savedTempDisable
            vowelCount = savedVowelCount
            vowelStart = savedVSI
            vowelEnd = savedVEI
            markPosition = savedVWSM
            return false
        }

        bufferLen = savedIdx
        actionCode = EngineAction.willProcess.rawValue
        extCode = 0
        backspaceCount = savedIdx
        newCharCount = savedIdx
        for ii in stride(from: savedIdx - 1, through: 0, by: -1) {
            outputData[savedIdx - 1 - ii] = get(typingWord[ii])
        }
        didTransform = true
        tempDisableKey = savedTempDisable
        return true
    }

    func canFixVowelWithDiacriticsForElongatedMark(_ data: UInt16) -> Bool {
        guard markMask(for: data) != nil, bufferLen >= 3 else { return false }

        let tailVowel = chr(bufferLen - 1)
        guard !isConsonant(tailVowel) else { return false }

        var tailStart = bufferLen - 1
        while tailStart > 0 && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
        guard bufferLen - tailStart >= 2, tailStart > 0 else { return false }

        for ii in 0..<bufferLen where (typingWord[ii] & MARK_MASK) != 0 {
            return false
        }

        let savedIdx = bufferLen
        bufferLen = tailStart + 1
        let canFix = canFixVowelWithDiacriticsForMark()
        bufferLen = savedIdx
        return canFix
    }

    // MARK: - Restore Operations

    func restoreToRawKeys() -> Bool {
        guard rawStateLen > 0 && bufferLen > 0 else { return false }
        var hasTransforms = false
        for ii in 0..<bufferLen where (typingWord[ii] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 {
            hasTransforms = true; break
        }
        guard hasTransforms else { return false }
        actionCode = EngineAction.restore.rawValue
        backspaceCount = bufferLen; newCharCount = rawStateLen
        for i in 0..<rawStateLen {
            typingWord[i] = keyStates[i]
            outputData[rawStateLen - 1 - i] = keyStates[i]
        }
        bufferLen = rawStateLen
        return true
    }

    // MARK: - Quick Consonant

    func checkQuickConsonant() -> Bool {
        guard bufferLen > 1 else { return false }
        let quickStart = config.quickStartConsonant
        let quickEnd = config.quickEndConsonant
        var l = 0
        if bufferLen > 0 {
            if quickStart, let qsc = vnQuickStartConsonant[chr(0)] {
                actionCode = EngineAction.restore.rawValue
                backspaceCount = bufferLen; newCharCount = bufferLen + 1
                if bufferLen < ENGINE_MAX_BUFF - 1 { bufferLen += 1 }
                for i in stride(from: bufferLen - 1, through: 2, by: -1) { typingWord[i] = typingWord[i - 1] }
                typingWord[1] = UInt32(qsc[1]) | ((typingWord[0] & CAPS_MASK) != 0 && (typingWord[2] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                typingWord[0] = UInt32(qsc[0]) | ((typingWord[0] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                l = 1
            }
            if quickEnd && bufferLen - 2 >= 0 && !isConsonant(chr(bufferLen - 2)),
               let qec = vnQuickEndConsonant[chr(bufferLen - 1)] {
                actionCode = EngineAction.restore.rawValue
                if l == 1 { newCharCount += 1 } else { backspaceCount = 1; newCharCount = 2 }
                if bufferLen < ENGINE_MAX_BUFF - 1 { bufferLen += 1 }
                typingWord[bufferLen - 1] = UInt32(qec[1]) | ((typingWord[bufferLen - 2] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                typingWord[bufferLen - 2] = UInt32(qec[0]) | ((typingWord[bufferLen - 2] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                l = 1
            }
            if l == 1 {
                for i in stride(from: bufferLen - 1, through: 0, by: -1) { outputData[bufferLen - 1 - i] = get(typingWord[i]) }
                return true
            }
        }
        return false
    }

    // MARK: - Output Helpers

    private func emitFullBuffer() {
        actionCode = EngineAction.willProcess.rawValue
        backspaceCount = 0
        for ii in stride(from: bufferLen - 1, through: 0, by: -1) {
            backspaceCount += 1
            outputData[bufferLen - 1 - ii] = get(typingWord[ii])
        }
        newCharCount = backspaceCount
    }

    private func applyMarkAt(_ pos: Int, mask: UInt32) {
        typingWord[pos] &= ~MARK_MASK
        typingWord[pos] |= mask
    }

    private func lastTonewIndex() -> Int? {
        for ii in stride(from: bufferLen - 1, through: 0, by: -1) where (typingWord[ii] & TONEW_MASK) != 0 {
            return ii
        }
        return nil
    }

    private func isDoubleUWithLeadingHorn() -> Bool {
        bufferLen >= 2 &&
        chr(bufferLen - 1) == KEY_U &&
        chr(bufferLen - 2) == KEY_U &&
        (typingWord[bufferLen - 2] & TONEW_MASK) != 0 &&
        (typingWord[bufferLen - 1] & TONEW_MASK) == 0
    }

    // MARK: - Main Key Handling

    func handleMainKey(_ data: UInt16, _ isCaps: Bool) {
        if isKeyZ(data)              { handleZKey(data, isCaps);                    return }
        if data == KEY_LEFT_BRACKET  { checkForStandaloneChar(data, isCaps, KEY_O); return }
        if data == KEY_RIGHT_BRACKET { checkForStandaloneChar(data, isCaps, KEY_U); return }
        if isKeyD(data)              { handleDKey(data, isCaps);                    return }
        if isMarkKey(data)           { handleMarkKey(data, isCaps);                 return }
        if shouldAppendRawElongatedVowel(data) { insertKey(data, isCaps);           return }
        handleVowelPatternKey(data, isCaps)
    }

    // MARK: - Main Key Subhandlers

    private func handleZKey(_ data: UInt16, _ isCaps: Bool) {
        removeMark()
        guard !didTransform else { return }

        let hasToneW = (0..<bufferLen).contains { (typingWord[$0] & TONEW_MASK) != 0 }
        guard hasToneW else { insertKey(data, isCaps); return }

        if config.checkSpelling { checkSpelling(forceCheckVowel: true) }
        if spellingOK && spellingVowelOK { return }

        if let pos = lastTonewIndex() {
            typingWord[pos] &= ~MARK_MASK
            emitFullBuffer()
        } else {
            insertKey(data, isCaps)
        }
    }

    private func handleDKey(_ data: UInt16, _ isCaps: Bool) {
        patternMatched = false; didTransform = false
        var k = bufferLen
        for (i, row) in vnConsonantD.enumerated() {
            guard bufferLen >= row.count else { continue }
            patternMatched = true
            checkCorrectVowel(vnConsonantD, i, &k, data)
            let trailingDD = bufferLen >= 2 && chr(bufferLen - 1) == KEY_D && isConsonant(chr(bufferLen - 2))
            if !patternMatched && trailingDD { patternMatched = true }
            if patternMatched { didTransform = true; insertD(data, isCaps); break }
        }
        if !didTransform { insertKey(data, isCaps) }
    }

    private func handleMarkKey(_ data: UInt16, _ isCaps: Bool) {
        guard let mask = markMask(for: data) else { insertKey(data, isCaps); return }

        // Special case: ưu — mark belongs on the ư (first u with TONEW)
        if isDoubleUWithLeadingHorn() {
            applyMarkAt(bufferLen - 2, mask: mask)
            emitFullBuffer()
            return
        }

        if applyMarkViaVowelPattern(data, mask: mask) { return }
        if tryInsertMarkForElongatedTrailingVowel(data) { return }

        if let pos = lastTonewIndex() {
            applyMarkAt(pos, mask: mask)
            emitFullBuffer()
            return
        }

        insertKey(data, isCaps)
    }

    private func applyMarkViaVowelPattern(_ data: UInt16, mask: UInt32) -> Bool {
        for (_, patterns) in vnVowelForMark {
            patternMatched = false; didTransform = false
            var k = bufferLen
            for (l, row) in patterns.enumerated() {
                guard bufferLen >= row.count else { continue }
                patternMatched = true
                checkCorrectVowel(patterns, l, &k, data)
                if patternMatched { didTransform = true; insertMark(mask); break }
            }
            if patternMatched { break }
        }
        return didTransform
    }

    private func handleVowelPatternKey(_ data: UInt16, _ isCaps: Bool) {
        resolveVowelKey(for: data)

        guard let charset = vnVowelPatterns[vowelKey] else {
            insertWOrLiteral(data, isCaps)
            return
        }

        patternMatched = false; didTransform = false
        var k = bufferLen
        for (i, row) in charset.enumerated() {
            guard bufferLen >= row.count else { continue }
            patternMatched = true
            checkCorrectVowel(charset, i, &k, data)
            if patternMatched {
                didTransform = true
                applyMatchedVowelTransform(data, isCaps)
                break
            }
        }

        if !didTransform { insertWOrLiteral(data, isCaps) }
    }

    private func resolveVowelKey(for data: UInt16) {
        guard config.inputType == .vni else { vowelKey = data; return }
        for i in stride(from: bufferLen - 1, through: 0, by: -1) {
            let c = chr(i)
            if c == KEY_O || c == KEY_A || c == KEY_E { vowelEnd = i; break }
        }
        vowelKey = data == KEY_7 || data == KEY_8 ? KEY_W : (data == KEY_6 ? chr(vowelEnd) : data)
    }

    private func applyMatchedVowelTransform(_ data: UInt16, _ isCaps: Bool) {
        if isKeyDouble(data) {
            insertAOE(vowelKey, isCaps)
        } else if isKeyW(data) {
            if config.inputType == .vni {
                for j in stride(from: bufferLen - 1, through: 0, by: -1) {
                    let c = chr(j)
                    if c == KEY_O || c == KEY_U || c == KEY_A || c == KEY_E { vowelEnd = j; break }
                }
                let skipA = data == KEY_7 && chr(vowelEnd) == KEY_A && (vowelEnd > 0 ? chr(vowelEnd - 1) != KEY_U : true)
                let skipOU = data == KEY_8 && (chr(vowelEnd) == KEY_O || chr(vowelEnd) == KEY_U)
                if skipA || skipOU { return }
            }
            insertW(vowelKey, isCaps)
        }
    }

    private func insertWOrLiteral(_ data: UInt16, _ isCaps: Bool) {
        guard data == KEY_W else { insertKey(data, isCaps); return }
        // At word start with wKeyAsLetter OFF: plain 'w'
        guard bufferLen > 0 || config.wKeyAsLetter else { insertKey(data, isCaps); return }

        // Don't convert w → ư when:
        //   • preceding char is KEY_W (ww, www… stay literal)
        //   • last vowel is KEY_E or KEY_I (not w-modifiable)
        let lastChar = bufferLen > 0 ? chr(bufferLen - 1) : 0
        var lastVowel: UInt16 = 0
        for scan in stride(from: bufferLen - 1, through: 0, by: -1) {
            let c = chr(scan)
            if !isConsonant(c) { lastVowel = c; break }
        }
        if lastChar == KEY_W || lastVowel == KEY_E || lastVowel == KEY_I {
            insertKey(data, isCaps)
        } else {
            insertKey(data, isCaps, false)
            reverseLastStandaloneChar(UInt32(KEY_U), isCaps)
        }
    }
}
