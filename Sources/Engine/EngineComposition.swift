// VietnameseEngine+Composition.swift
// GoviKey Engine
//
// Character composition: insert D, AOE, W, standalone, elongated vowels,
// quick telex, quick consonant, restore operations, main key handling.

import Foundation

extension VietnameseEngine {

    // MARK: - Insert D

    func insertD(_ data: UInt16, _ isCaps: Bool) {
        hCode = EngineAction.willProcess.rawValue; hBPC = 0
        var ii = idx - 1
        while ii >= 0 {
            hBPC += 1
            if chr(ii) == KEY_D {
                if (typingWord[ii] & TONE_MASK) != 0 {
                    hCode = EngineAction.restore.rawValue
                    typingWord[ii] &= ~TONE_MASK
                    hData[idx - 1 - ii] = get(typingWord[ii])
                    tempDisableKey = true
                } else {
                    typingWord[ii] |= TONE_MASK
                    hData[idx - 1 - ii] = get(typingWord[ii])
                }
                break
            } else {
                hData[idx - 1 - ii] = get(typingWord[ii])
            }
            ii -= 1
        }
        hNCC = hBPC
    }

    // MARK: - Insert AOE

    func insertAOE(_ data: UInt16, _ isCaps: Bool) {
        findAndCalculateVowel()
        let shouldPreserveEarlierMarkedVowelForCycle =
            VEI == idx - 1 &&
            chr(idx - 1) == data &&
            (typingWord[idx - 1] & (MARK_MASK | TONE_MASK | TONEW_MASK)) == 0 &&
            (data == KEY_A || data == KEY_E || data == KEY_O) &&
            (VSI..<(idx - 1)).contains { (typingWord[$0] & MARK_MASK) != 0 }
        for ii in VSI...VEI { typingWord[ii] &= ~TONEW_MASK }
        hCode = EngineAction.willProcess.rawValue; hBPC = 0
        var ii = idx - 1
        while ii >= 0 {
            hBPC += 1
            if chr(ii) == data {
                if (typingWord[ii] & TONE_MASK) != 0 {
                    hCode = EngineAction.restore.rawValue
                    typingWord[ii] &= ~TONE_MASK
                    hData[idx - 1 - ii] = get(typingWord[ii])
                    tempDisableKey = true
                } else {
                    typingWord[ii] |= TONE_MASK
                    if !isKeyD(data) { typingWord[ii] &= ~TONEW_MASK }
                    if shouldPreserveEarlierMarkedVowelForCycle && ii == idx - 1 {
                        skipGrammarMarkNormalizationOnce = true
                    }
                    hData[idx - 1 - ii] = get(typingWord[ii])
                }
                break
            } else {
                hData[idx - 1 - ii] = get(typingWord[ii])
            }
            ii -= 1
        }
        hNCC = hBPC
    }

    // MARK: - Insert W

    func insertW(_ data: UInt16, _ isCaps: Bool) {
        isRestoredW = false
        findAndCalculateVowel()
        for ii in VSI...VEI { typingWord[ii] &= ~TONE_MASK }

        if vowelCount > 1 {
            hBPC = idx - VSI; hNCC = hBPC
            let both = (typingWord[VSI] & TONEW_MASK) != 0 && (typingWord[VSI + 1] & TONEW_MASK) != 0
            let withI = (typingWord[VSI] & TONEW_MASK) != 0 && chr(VSI + 1) == KEY_I
            let withA = (typingWord[VSI] & TONEW_MASK) != 0 && chr(VSI + 1) == KEY_A
            if both || withI || withA {
                hCode = EngineAction.restore.rawValue
                for ii in VSI..<idx {
                    typingWord[ii] &= ~TONEW_MASK
                    hData[idx - 1 - ii] = get(typingWord[ii]) & ~STANDALONE_MASK
                }
                isRestoredW = true; tempDisableKey = true
            } else {
                hCode = EngineAction.willProcess.rawValue
                var shouldRestore = false
                if chr(VSI) == KEY_U && chr(VSI + 1) == KEY_O {
                    let isThu = VSI - 2 >= 0 && typingWord[VSI - 2] == UInt32(KEY_T) && typingWord[VSI - 1] == UInt32(KEY_H)
                    let isQuo = VSI - 1 >= 0 && typingWord[VSI - 1] == UInt32(KEY_Q)
                    if isThu {
                        if (typingWord[VSI + 1] & TONEW_MASK) != 0 { shouldRestore = true }
                        else {
                            typingWord[VSI + 1] |= TONEW_MASK
                            if VSI + 2 < idx && chr(VSI + 2) == KEY_N { typingWord[VSI] |= TONEW_MASK }
                        }
                    } else if isQuo {
                        if (typingWord[VSI + 1] & TONEW_MASK) != 0 { shouldRestore = true }
                        else { typingWord[VSI + 1] |= TONEW_MASK }
                    } else {
                        if (typingWord[VSI] & TONEW_MASK) != 0 && (typingWord[VSI + 1] & TONEW_MASK) == 0 {
                            typingWord[VSI + 1] |= TONEW_MASK
                        } else if (typingWord[VSI] & TONEW_MASK) != 0 || (typingWord[VSI + 1] & TONEW_MASK) != 0 {
                            shouldRestore = true
                        } else {
                            typingWord[VSI] |= TONEW_MASK; typingWord[VSI + 1] |= TONEW_MASK
                        }
                    }
                } else if (chr(VSI) == KEY_U && chr(VSI + 1) == KEY_A) ||
                          (chr(VSI) == KEY_U && chr(VSI + 1) == KEY_I) ||
                          (chr(VSI) == KEY_U && chr(VSI + 1) == KEY_U) ||
                          (chr(VSI) == KEY_O && chr(VSI + 1) == KEY_I) {
                    if (typingWord[VSI] & TONEW_MASK) != 0 { shouldRestore = true }
                    else { typingWord[VSI] |= TONEW_MASK }
                } else if (chr(VSI) == KEY_I && chr(VSI + 1) == KEY_O) ||
                          (chr(VSI) == KEY_O && chr(VSI + 1) == KEY_A) {
                    if (typingWord[VSI + 1] & TONEW_MASK) != 0 { shouldRestore = true }
                    else { typingWord[VSI + 1] |= TONEW_MASK }
                } else {
                    tempDisableKey = true; isChanged = false; hCode = EngineAction.doNothing.rawValue
                }
                if shouldRestore {
                    hCode = EngineAction.restore.rawValue
                    for ii in VSI..<idx {
                        typingWord[ii] &= ~TONEW_MASK
                        hData[idx - 1 - ii] = get(typingWord[ii]) & ~STANDALONE_MASK
                    }
                    isRestoredW = true; tempDisableKey = true
                } else if hCode == EngineAction.willProcess.rawValue {
                    for ii in VSI..<idx { hData[idx - 1 - ii] = get(typingWord[ii]) }
                }
            }
            return
        }

        hCode = EngineAction.willProcess.rawValue; hBPC = 0
        var ii = idx - 1
        while ii >= 0 {
            if ii < VSI { break }
            hBPC += 1
            switch chr(ii) {
            case KEY_A, KEY_U, KEY_O:
                if (typingWord[ii] & TONEW_MASK) != 0 {
                    if (typingWord[ii] & STANDALONE_MASK) != 0 {
                        hCode = EngineAction.willProcess.rawValue
                        if chr(ii) == KEY_U {
                            typingWord[ii] = UInt32(KEY_W) | ((typingWord[ii] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                        } else if chr(ii) == KEY_O {
                            hCode = EngineAction.restore.rawValue
                            typingWord[ii] = UInt32(KEY_O) | ((typingWord[ii] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                            isRestoredW = true
                        }
                        hData[idx - 1 - ii] = get(typingWord[ii])
                    } else {
                        hCode = EngineAction.restore.rawValue
                        typingWord[ii] &= ~TONEW_MASK
                        hData[idx - 1 - ii] = get(typingWord[ii])
                        isRestoredW = true
                    }
                    tempDisableKey = true
                } else {
                    typingWord[ii] |= TONEW_MASK; typingWord[ii] &= ~TONE_MASK
                    hData[idx - 1 - ii] = get(typingWord[ii])
                }
            default:
                hData[idx - 1 - ii] = get(typingWord[ii])
            }
            ii -= 1
        }
        hNCC = hBPC
    }

    // MARK: - Standalone and Caps

    func reverseLastStandaloneChar(_ keyCode: UInt32, _ isCaps: Bool) {
        hCode = EngineAction.willProcess.rawValue
        hBPC = 0; hNCC = 1; hExt = 4
        typingWord[idx - 1] = keyCode | TONEW_MASK | STANDALONE_MASK | (isCaps ? CAPS_MASK : 0)
        hData[0] = get(typingWord[idx - 1])
    }

    func checkForStandaloneChar(_ data: UInt16, _ isCaps: Bool, _ keyWillReverse: UInt16) {
        if idx > 0 && chr(idx - 1) == keyWillReverse && (typingWord[idx - 1] & TONEW_MASK) != 0 {
            hCode = EngineAction.willProcess.rawValue
            hBPC = 1; hNCC = 1
            typingWord[idx - 1] = UInt32(data) | (isCaps ? CAPS_MASK : 0)
            hData[0] = get(typingWord[idx - 1])
            return
        }
        if idx > 0 && chr(idx - 1) == KEY_U && keyWillReverse == KEY_O {
            insertKey(keyWillReverse, isCaps)
            reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
            return
        }
        if idx == 0 {
            insertKey(data, isCaps, false)
            reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
            return
        } else if idx == 1 {
            if vnStandaloneWBad.contains(chr(0)) {
                insertKey(data, isCaps)
                return
            }
            insertKey(data, isCaps, false)
            reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
            return
        } else if idx == 2 {
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
        guard idx > 0, !isConsonant(data), chr(idx - 1) == data else { return false }

        var runStart = idx - 1
        while runStart > 0 && chr(runStart - 1) == data { runStart -= 1 }
        let runLength = idx - runStart
        let trailing = typingWord[idx - 1]

        // A single toned A/E vowel (with any diacritic or not) should cycle via insertAOE,
        // not be raw-appended as elongation. Let the AOE handler manage cycling.
        if (data == KEY_A || data == KEY_E) &&
           runLength == 1 &&
           (trailing & MARK_MASK) != 0 {
            return false
        }

        for ii in runStart..<idx {
            guard (typingWord[ii] & MARK_MASK) != 0 else { continue }
            if data == KEY_O { return runLength >= 2 }
            if data == KEY_A || data == KEY_E { return true }
        }
        return false
    }

    func tryExpandMarkedAOEElongation(_ data: UInt16, _ isCaps: Bool) -> Bool {
        guard (data == KEY_A || data == KEY_E), idx > 0, chr(idx - 1) == data else { return false }

        var runStart = idx - 1
        while runStart > 0 && chr(runStart - 1) == data { runStart -= 1 }
        guard idx - runStart == 1 else { return false }

        let trailing = typingWord[idx - 1]
        guard (trailing & MARK_MASK) != 0 else { return false }
        guard (trailing & TONE_MASK) != 0, (trailing & TONEW_MASK) == 0 else { return false }
        guard idx + 1 < ENGINE_MAX_BUFF else { return false }

        findAndCalculateVowel()
        let vowelStart = VSI
        let oldIdx = idx

        typingWord[idx - 1] &= ~TONE_MASK
        setKeyData(idx, data, isCaps)
        idx += 1
        setKeyData(idx, data, isCaps)
        idx += 1

        hCode = EngineAction.willProcess.rawValue
        hExt = 0
        hBPC = oldIdx - vowelStart
        hNCC = idx - vowelStart

        var outIndex = 0
        for ii in stride(from: idx - 1, through: vowelStart, by: -1) {
            hData[outIndex] = get(typingWord[ii])
            outIndex += 1
        }

        isChanged = true
        return true
    }

    func tryInsertMarkForElongatedTrailingVowel(_ data: UInt16) -> Bool {
        guard let markMask = markMask(for: data), idx >= 3 else { return false }

        let tailVowel = chr(idx - 1)
        guard !isConsonant(tailVowel) else { return false }

        var tailStart = idx - 1
        while tailStart > 0 && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
        guard idx - tailStart >= 2, tailStart > 0 else { return false }

        var hasExistingMark = false
        for ii in 0..<idx where (typingWord[ii] & MARK_MASK) != 0 {
            hasExistingMark = true
            break
        }
        guard !hasExistingMark else { return false }

        let savedTypingWord = typingWord
        let savedIdx = idx
        let savedHCode = hCode
        let savedExt = hExt
        let savedBPC = hBPC
        let savedNCC = hNCC
        let savedHData = hData
        let savedIsChanged = isChanged
        let savedTempDisable = tempDisableKey
        let savedVowelCount = vowelCount
        let savedVSI = VSI
        let savedVEI = VEI
        let savedVWSM = VWSM

        idx = tailStart + 1
        insertMark(markMask, canModifyFlag: false)

        var applied = false
        for ii in 0..<idx where (typingWord[ii] & MARK_MASK) == markMask {
            applied = true
            break
        }

        if !applied {
            typingWord = savedTypingWord
            idx = savedIdx
            hCode = savedHCode
            hExt = savedExt
            hBPC = savedBPC
            hNCC = savedNCC
            hData = savedHData
            isChanged = savedIsChanged
            tempDisableKey = savedTempDisable
            vowelCount = savedVowelCount
            VSI = savedVSI
            VEI = savedVEI
            VWSM = savedVWSM
            return false
        }

        idx = savedIdx
        hCode = EngineAction.willProcess.rawValue
        hExt = 0
        hBPC = savedIdx
        hNCC = savedIdx
        for ii in stride(from: savedIdx - 1, through: 0, by: -1) {
            hData[savedIdx - 1 - ii] = get(typingWord[ii])
        }
        isChanged = true
        tempDisableKey = savedTempDisable
        return true
    }

    func canFixVowelWithDiacriticsForElongatedMark(_ data: UInt16) -> Bool {
        guard markMask(for: data) != nil, idx >= 3 else { return false }

        let tailVowel = chr(idx - 1)
        guard !isConsonant(tailVowel) else { return false }

        var tailStart = idx - 1
        while tailStart > 0 && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
        guard idx - tailStart >= 2, tailStart > 0 else { return false }

        for ii in 0..<idx where (typingWord[ii] & MARK_MASK) != 0 {
            return false
        }

        let savedIdx = idx
        idx = tailStart + 1
        let canFix = canFixVowelWithDiacriticsForMark()
        idx = savedIdx
        return canFix
    }

    // MARK: - Restore Operations

    func restoreToRawKeys() -> Bool {
        guard stateIdx > 0 && idx > 0 else { return false }
        var hasTransforms = false
        for ii in 0..<idx where (typingWord[ii] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 {
            hasTransforms = true; break
        }
        guard hasTransforms else { return false }
        hCode = EngineAction.restore.rawValue
        hBPC = idx; hNCC = stateIdx
        for i in 0..<stateIdx {
            typingWord[i] = keyStates[i]
            hData[stateIdx - 1 - i] = keyStates[i]
        }
        idx = stateIdx
        return true
    }

    // MARK: - Quick Consonant

    func checkQuickConsonant() -> Bool {
        guard idx > 1 else { return false }
        let quickStart = config.quickStartConsonant
        let quickEnd = config.quickEndConsonant
        var l = 0
        if idx > 0 {
            if quickStart, let qsc = vnQuickStartConsonant[chr(0)] {
                hCode = EngineAction.restore.rawValue
                hBPC = idx; hNCC = idx + 1
                if idx < ENGINE_MAX_BUFF - 1 { idx += 1 }
                for i in stride(from: idx - 1, through: 2, by: -1) { typingWord[i] = typingWord[i - 1] }
                typingWord[1] = UInt32(qsc[1]) | ((typingWord[0] & CAPS_MASK) != 0 && (typingWord[2] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                typingWord[0] = UInt32(qsc[0]) | ((typingWord[0] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                l = 1
            }
            if quickEnd && idx - 2 >= 0 && !isConsonant(chr(idx - 2)),
               let qec = vnQuickEndConsonant[chr(idx - 1)] {
                hCode = EngineAction.restore.rawValue
                if l == 1 { hNCC += 1 } else { hBPC = 1; hNCC = 2 }
                if idx < ENGINE_MAX_BUFF - 1 { idx += 1 }
                typingWord[idx - 1] = UInt32(qec[1]) | ((typingWord[idx - 2] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                typingWord[idx - 2] = UInt32(qec[0]) | ((typingWord[idx - 2] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                l = 1
            }
            if l == 1 {
                for i in stride(from: idx - 1, through: 0, by: -1) { hData[idx - 1 - i] = get(typingWord[i]) }
                return true
            }
        }
        return false
    }

    // MARK: - Main Key Handling

    func handleMainKey(_ data: UInt16, _ isCaps: Bool) {
        if isKeyZ(data) {
            removeMark()
            if !isChanged {
                var hasToneW = false
                for ii in 0..<idx where (typingWord[ii] & TONEW_MASK) != 0 { hasToneW = true; break }
                if hasToneW {
                    if config.checkSpelling { checkSpelling(forceCheckVowel: true) }
                    if spellingOK && spellingVowelOK {
                        if isKeyS(data) { insertMark(MARK1_MASK) }
                        else if isKeyF(data) { insertMark(MARK2_MASK) }
                        else if isKeyR(data) { insertMark(MARK3_MASK) }
                        else if isKeyX(data) { insertMark(MARK4_MASK) }
                        else if isKeyJ(data) { insertMark(MARK5_MASK) }
                        return
                    }
                    var markIndex = -1
                    for ii in stride(from: idx - 1, through: 0, by: -1) where (typingWord[ii] & TONEW_MASK) != 0 {
                        markIndex = ii; break
                    }
                    if markIndex >= 0 {
                        typingWord[markIndex] &= ~MARK_MASK
                        if isKeyS(data) { typingWord[markIndex] |= MARK1_MASK }
                        else if isKeyF(data) { typingWord[markIndex] |= MARK2_MASK }
                        else if isKeyR(data) { typingWord[markIndex] |= MARK3_MASK }
                        else if isKeyX(data) { typingWord[markIndex] |= MARK4_MASK }
                        else if isKeyJ(data) { typingWord[markIndex] |= MARK5_MASK }
                        hCode = EngineAction.willProcess.rawValue; hBPC = 0
                        for ii in stride(from: idx - 1, through: 0, by: -1) { hBPC += 1; hData[idx - 1 - ii] = get(typingWord[ii]) }
                        hNCC = hBPC; return
                    }
                }
                insertKey(data, isCaps)
            }
            return
        }

        if data == KEY_LEFT_BRACKET { checkForStandaloneChar(data, isCaps, KEY_O); return }
        if data == KEY_RIGHT_BRACKET { checkForStandaloneChar(data, isCaps, KEY_U); return }

        if isKeyD(data) {
            isCorect = false; isChanged = false
            var k = idx
            for (i, row) in vnConsonantD.enumerated() {
                if idx < row.count { continue }
                isCorect = true
                checkCorrectVowel(vnConsonantD, i, &k, data)
                if !isCorect && idx - 2 >= 0 && chr(idx - 1) == KEY_D && isConsonant(chr(idx - 2)) { isCorect = true }
                if isCorect { isChanged = true; insertD(data, isCaps); break }
            }
            if !isChanged { insertKey(data, isCaps) }
            return
        }

        if isMarkKey(data) {
            if idx >= 2 && chr(idx - 1) == KEY_U && chr(idx - 2) == KEY_U &&
               (typingWord[idx - 2] & TONEW_MASK) != 0 && (typingWord[idx - 1] & TONEW_MASK) == 0 {
                typingWord[idx - 2] &= ~MARK_MASK
                if isKeyS(data) { typingWord[idx - 2] |= MARK1_MASK }
                else if isKeyF(data) { typingWord[idx - 2] |= MARK2_MASK }
                else if isKeyR(data) { typingWord[idx - 2] |= MARK3_MASK }
                else if isKeyX(data) { typingWord[idx - 2] |= MARK4_MASK }
                else if isKeyJ(data) { typingWord[idx - 2] |= MARK5_MASK }
                hCode = EngineAction.willProcess.rawValue; hBPC = 0
                for ii in stride(from: idx - 1, through: 0, by: -1) { hBPC += 1; hData[idx - 1 - ii] = get(typingWord[ii]) }
                hNCC = hBPC; return
            }
            for (_, patterns) in vnVowelForMark {
                isCorect = false; isChanged = false
                var k = idx
                for (l, row) in patterns.enumerated() {
                    if idx < row.count { continue }
                    isCorect = true
                    checkCorrectVowel(patterns, l, &k, data)
                    if isCorect {
                        isChanged = true
                        if isKeyS(data) { insertMark(MARK1_MASK) }
                        else if isKeyF(data) { insertMark(MARK2_MASK) }
                        else if isKeyR(data) { insertMark(MARK3_MASK) }
                        else if isKeyX(data) { insertMark(MARK4_MASK) }
                        else if isKeyJ(data) { insertMark(MARK5_MASK) }
                        break
                    }
                }
                if isCorect { break }
            }
            if !isChanged {
                if tryInsertMarkForElongatedTrailingVowel(data) { return }
                var markIndex = -1
                for ii in stride(from: idx - 1, through: 0, by: -1) where (typingWord[ii] & TONEW_MASK) != 0 {
                    markIndex = ii; break
                }
                if markIndex >= 0 {
                    typingWord[markIndex] &= ~MARK_MASK
                    if isKeyS(data) { typingWord[markIndex] |= MARK1_MASK }
                    else if isKeyF(data) { typingWord[markIndex] |= MARK2_MASK }
                    else if isKeyR(data) { typingWord[markIndex] |= MARK3_MASK }
                    else if isKeyX(data) { typingWord[markIndex] |= MARK4_MASK }
                    else if isKeyJ(data) { typingWord[markIndex] |= MARK5_MASK }
                    hCode = EngineAction.willProcess.rawValue; hBPC = 0
                    for ii in stride(from: idx - 1, through: 0, by: -1) { hBPC += 1; hData[idx - 1 - ii] = get(typingWord[ii]) }
                    hNCC = hBPC
                } else {
                    insertKey(data, isCaps)
                }
            }
            return
        }

        if shouldAppendRawElongatedVowel(data) {
            insertKey(data, isCaps)
            return
        }

        if config.inputType == .vni {
            for i in stride(from: idx - 1, through: 0, by: -1) {
                let c = chr(i)
                if c == KEY_O || c == KEY_A || c == KEY_E { VEI = i; break }
            }
        }

        keyForAEO = config.inputType != .vni ? data :
            (data == KEY_7 || data == KEY_8 ? KEY_W : (data == KEY_6 ? chr(VEI) : data))

        guard let charset = vnVowelPatterns[keyForAEO] else {
            if data == KEY_W {
                if idx == 0 && !config.wKeyAsLetter {
                    insertKey(data, isCaps)
                } else {
                    insertKey(data, isCaps, false)
                    reverseLastStandaloneChar(UInt32(KEY_U), isCaps)
                }
            } else {
                insertKey(data, isCaps)
            }
            return
        }

        isCorect = false; isChanged = false
        var k = idx
        for (i, row) in charset.enumerated() {
            if idx < row.count { continue }
            isCorect = true
            checkCorrectVowel(charset, i, &k, data)
            if isCorect {
                isChanged = true
                if isKeyDouble(data) {
                    insertAOE(keyForAEO, isCaps)
                } else         if isKeyW(data) {
            if config.inputType == .vni {
                for j in stride(from: idx - 1, through: 0, by: -1) {
                    let c = chr(j)
                    if c == KEY_O || c == KEY_U || c == KEY_A || c == KEY_E { VEI = j; break }
                }
                let cond7 = data == KEY_7 && chr(VEI) == KEY_A && (VEI - 1 >= 0 ? chr(VEI - 1) != KEY_U : true)
                let cond8 = data == KEY_8 && (chr(VEI) == KEY_O || chr(VEI) == KEY_U)
                if cond7 || cond8 { break }
            }
            // Vowel-modifier path (ow→ơ, aw→ă, uw→ư) is always active
            // regardless of wKeyAsLetter.
            insertW(keyForAEO, isCaps)
        }
                break
            }
        }
        if !isChanged {
            if data == KEY_W {
                if idx == 0 && !config.wKeyAsLetter {
                    // Feature OFF + truly at start of word: plain 'w'.
                    insertKey(data, isCaps)
                } else {
                    // After consonant (any idx>0), OR feature ON: always ư.
                    insertKey(data, isCaps, false)
                    reverseLastStandaloneChar(UInt32(KEY_U), isCaps)
                }
            } else {
                insertKey(data, isCaps)
            }
        }
    }
}
