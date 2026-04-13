// VietnameseEngine+Spelling.swift
// GoviKey Engine
//
// Spelling validation and grammar normalization.

import Foundation

extension VietnameseEngine {

    // MARK: - Spelling Check

    func checkSpelling(forceCheckVowel: Bool = false) {
        if idx == 0 {
            spellingOK = true; spellingVowelOK = true; tempDisableKey = false; return
        }
        spellingOK = false; spellingVowelOK = true
        spellingEndIndex = idx
        if idx > 0 && chr(idx - 1) == KEY_RIGHT_BRACKET { spellingEndIndex = idx - 1 }

        if spellingEndIndex > 0 {
            let quickStart = config.quickStartConsonant
            let allowZFWJ = config.allowConsonantZFWJ
            let quickEnd = config.quickEndConsonant
            var j = 0
            if isConsonant(chr(0)) {
                var matched = false
                for row in vnConsonantTable {
                    spellingFlag = false
                    if spellingEndIndex < row.count { spellingFlag = true }
                    j = 0
                    while j < row.count {
                        let rc = row[j]
                        let noQuickStart = rc & ~(quickStart ? END_CONSONANT_MASK : 0)
                        let noAllowMask = rc & ~(allowZFWJ ? CONSONANT_ALLOW_MASK : 0)
                        if spellingEndIndex > j && noQuickStart != chr(j) && noAllowMask != chr(j) {
                            spellingFlag = true; break
                        }
                        j += 1
                    }
                    if spellingFlag { continue }
                    matched = true; break
                }
                if !matched { j = spellingEndIndex }
            }

            if j == spellingEndIndex { spellingOK = true }

            var k = j
            VSI = k
            if chr(VSI) == KEY_U && k > 0 && k < spellingEndIndex - 1 && chr(VSI - 1) == KEY_Q {
                k += 1; j = k; VSI = k
            } else if idx >= 2 && chr(0) == KEY_G && chr(1) == KEY_I && isConsonant(chr(2)) {
                VSI = 1; k = 1; j = 1
            }
            var l = 0
            while l < 3 {
                if k < spellingEndIndex && !isConsonant(chr(k)) { k += 1; VEI = k }
                l += 1
            }

            if k > j {
                spellingVowelOK = false
                if k - j > 1 && forceCheckVowel {
                    let vowelSet = vnVowelCombine[chr(j)] ?? []
                    for pattern in vowelSet {
                        spellingFlag = false
                        for pi in 1..<pattern.count {
                            let idx2 = j + pi - 1
                            if idx2 < spellingEndIndex {
                                let expected = pattern[pi]
                                let actual = UInt32(chr(idx2)) | (typingWord[idx2] & TONEW_MASK) | (typingWord[idx2] & TONE_MASK)
                                if expected != actual { spellingFlag = true; break }
                            }
                        }
                        let ii = pattern.count - 1
                        let hasEndConsonant = k < spellingEndIndex && pattern[0] == 0
                        let lastIsConsonant = (j + ii - 1 < spellingEndIndex) && isConsonant(chr(j + ii - 1))
                        if spellingFlag || hasEndConsonant || lastIsConsonant { continue }
                        spellingVowelOK = true; break
                    }
                } else if !isConsonant(chr(j)) {
                    spellingVowelOK = true
                }

                j = 0
                for row in vnEndConsonantTable {
                    spellingFlag = false
                    var jj = 0
                    while jj < row.count {
                        let rc = row[jj]
                        let noQuick = rc & ~(quickEnd ? END_CONSONANT_MASK : 0)
                        if spellingEndIndex > k + jj && noQuick != chr(k + jj) {
                            spellingFlag = true; break
                        }
                        jj += 1
                    }
                    if spellingFlag { continue }
                    if k + jj >= spellingEndIndex { spellingOK = true; break }
                    j = jj
                }

                if spellingOK {
                    if idx >= 3 && chr(idx - 1) == KEY_H && chr(idx - 2) == KEY_C {
                        let tw = typingWord[idx - 3]
                        let okMark = (tw & MARK1_MASK) != 0 || (tw & MARK5_MASK) != 0 || (tw & MARK_MASK) == 0
                        if !okMark { spellingOK = false }
                    } else if idx >= 2 && chr(idx - 1) == KEY_T {
                        let tw = typingWord[idx - 2]
                        let okMark = (tw & MARK1_MASK) != 0 || (tw & MARK5_MASK) != 0 || (tw & MARK_MASK) == 0
                        if !okMark { spellingOK = false }
                    }
                }
            }
        } else {
            spellingOK = true
        }
        tempDisableKey = !(spellingOK && spellingVowelOK)
    }

    // MARK: - Grammar Check

    func checkGrammar(deltaBackSpace: Int) {
        guard idx > 1 && idx < ENGINE_MAX_BUFF else { return }
        findAndCalculateVowel(forGrammar: true)
        guard vowelCount > 0 else { return }
        isCheckedGrammar = false
        let l = VSI

        if idx >= 3 {
            outer: for i in stride(from: idx - 1, through: 0, by: -1) {
                let c = chr(i)
                if c == KEY_N || c == KEY_C || c == KEY_I || c == KEY_M || c == KEY_P || c == KEY_T {
                    if i - 2 >= 0 && chr(i - 1) == KEY_O && chr(i - 2) == KEY_U {
                        let tonewI1 = typingWord[i - 1] & TONEW_MASK
                        let tonewI2 = typingWord[i - 2] & TONEW_MASK
                        if tonewI1 ^ tonewI2 != 0 {
                            typingWord[i - 2] |= TONEW_MASK
                            typingWord[i - 1] |= TONEW_MASK
                            isCheckedGrammar = true
                            break outer
                        }
                    }
                }
            }
        }

        if idx >= 2 {
            for i in l...VEI {
                if (typingWord[i] & MARK_MASK) == 0 { continue }

                if skipGrammarMarkNormalizationOnce &&
                   i < VEI &&
                   (chr(VEI) == KEY_A || chr(VEI) == KEY_E || chr(VEI) == KEY_O) &&
                   (typingWord[VEI] & (TONE_MASK | TONEW_MASK)) != 0 {
                    skipGrammarMarkNormalizationOnce = false
                    break
                }

                let tailStart: Int = {
                    if VEI > VSI {
                        let tailVowel = chr(VEI)
                        var ts = VEI
                        while ts > VSI && chr(ts - 1) == tailVowel { ts -= 1 }
                        return ts
                    }
                    return VEI
                }()
                let tailLen = VEI - tailStart + 1
                if tailLen >= 2 && i <= tailStart { isCheckedGrammar = false; break }

                var isExtendedVowel = false
                if i < VEI && chr(i) == chr(i + 1) {
                    isExtendedVowel = true
                    for ci in (i + 1)...VEI where chr(ci) != chr(i) { isExtendedVowel = false; break }
                }
                if isExtendedVowel { isCheckedGrammar = false; break }

                let mark = typingWord[i] & MARK_MASK
                typingWord[i] &= ~MARK_MASK
                insertMark(mark, canModifyFlag: false)
                if i != VWSM { isCheckedGrammar = true }
                break
            }
        }

        skipGrammarMarkNormalizationOnce = false

        if isCheckedGrammar {
            if hCode == EngineAction.doNothing.rawValue { hCode = EngineAction.willProcess.rawValue }
            hBPC = 0
            for i in stride(from: idx - 1, through: l, by: -1) {
                hBPC += 1
                hData[idx - 1 - i] = get(typingWord[i])
            }
            hNCC = hBPC
            hBPC += deltaBackSpace
            hExt = 4
        }
    }
}
