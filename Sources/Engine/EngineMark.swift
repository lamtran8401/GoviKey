// VietnameseEngine+Mark.swift
// VietKey Engine
//
// Tone mark placement (modern/old style) and mark insertion.

import Foundation

extension VietnameseEngine {

    // MARK: - Modern Mark Placement

    func handleModernMark() {
        let originalVEI = VEI, originalVowelCount = vowelCount
        var adjustedTrailing = false, preferLastRepeat = false
        if vowelCount >= 2 {
            let tailVowel = chr(VEI)
            var tailStart = VEI
            while tailStart > VSI && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
            if VEI - tailStart + 1 >= 2 {
                var runHasDiacritic = false
                for id in tailStart...VEI {
                    if (typingWord[id] & (TONE_MASK | TONEW_MASK)) != 0 { runHasDiacritic = true; break }
                }
                if !runHasDiacritic && tailVowel == KEY_O && tailStart == VSI {
                    preferLastRepeat = true
                } else {
                    VEI = tailStart; vowelCount = 0
                    for id in VSI...VEI where !isConsonant(chr(id)) { vowelCount += 1 }
                    adjustedTrailing = true
                }
            }
        }

        VWSM = VEI; hBPC = idx - VEI

        if vowelCount == 3 && (
            (chr(VSI) == KEY_O && chr(VSI+1) == KEY_A && chr(VSI+2) == KEY_I) ||
            (chr(VSI) == KEY_U && chr(VSI+1) == KEY_Y && chr(VSI+2) == KEY_U) ||
            (chr(VSI) == KEY_O && chr(VSI+1) == KEY_E && chr(VSI+2) == KEY_O) ||
            (chr(VSI) == KEY_U && chr(VSI+1) == KEY_Y && chr(VSI+2) == KEY_A)) {
            VWSM = VSI + 1; hBPC = idx - VWSM
        } else if vowelCount >= 2 && chr(VEI) == KEY_Y {
            if vowelCount == 2 && chr(VSI) == KEY_U && chr(VSI + 1) == KEY_Y {
                VWSM = VEI; hBPC = idx - VWSM
            } else {
                var lastNonY = VEI
                while lastNonY >= VSI && chr(lastNonY) == KEY_Y { lastNonY -= 1 }
                if lastNonY >= VSI { VWSM = lastNonY; hBPC = idx - VWSM }
            }
        } else if (chr(VSI) == KEY_O && chr(VSI+1) == KEY_I) ||
                  (chr(VSI) == KEY_A && chr(VSI+1) == KEY_I) ||
                  (chr(VSI) == KEY_U && chr(VSI+1) == KEY_I) {
            VWSM = VSI; hBPC = idx - VWSM
        } else if VEI - 1 >= VSI && chr(VEI-1) == KEY_A && chr(VEI) == KEY_Y {
            VWSM = VEI - 1; hBPC = (idx - VEI) + 1
        } else if chr(VSI) == KEY_U && chr(VSI+1) == KEY_O {
            VWSM = VSI + 1; hBPC = idx - VWSM
        } else if VSI + 1 <= VEI && (chr(VSI+1) == KEY_O || chr(VSI+1) == KEY_U) {
            VWSM = VEI - 1; hBPC = (idx - VEI) + 1
        } else if chr(VSI) == KEY_O || chr(VSI) == KEY_U {
            VWSM = VEI; hBPC = idx - VEI
        }

        if VSI + 1 <= VEI {
            let tw1 = typingWord[VSI + 1]
            let condition31 =
                (chr(VSI) == KEY_I && (tw1 & (UInt32(KEY_E) | TONE_MASK)) != 0) ||
                (chr(VSI) == KEY_Y && (tw1 & (UInt32(KEY_E) | TONE_MASK)) != 0) ||
                (chr(VSI) == KEY_U && typingWord[VSI + 1] == (UInt32(KEY_O) | TONE_MASK)) ||
                ((typingWord[VSI] == (UInt32(KEY_U) | TONEW_MASK)) && (typingWord[VSI + 1] == (UInt32(KEY_O) | TONEW_MASK)))

            if condition31 {
                var forceSecond = false
                if (chr(VSI) == KEY_I || chr(VSI) == KEY_Y) && chr(VSI + 1) == KEY_E && (tw1 & TONE_MASK) != 0 { forceSecond = true }
                else if chr(VSI) == KEY_U && chr(VSI + 1) == KEY_O && (tw1 & TONE_MASK) != 0 { forceSecond = true }
                else if (typingWord[VSI] & TONEW_MASK) != 0 && (tw1 & TONEW_MASK) != 0 && chr(VSI) == KEY_U && chr(VSI + 1) == KEY_O { forceSecond = true }

                if forceSecond {
                    VWSM = VSI + 1; hBPC = idx - VWSM
                } else if VSI + 2 < idx {
                    let c2 = chr(VSI + 2)
                    if c2 == KEY_P || c2 == KEY_T || c2 == KEY_M || c2 == KEY_N ||
                       c2 == KEY_O || c2 == KEY_U || c2 == KEY_I || c2 == KEY_C {
                        VWSM = VSI + 1; hBPC = idx - VWSM
                    } else {
                        VWSM = VSI; hBPC = idx - VWSM
                    }
                } else {
                    VWSM = VSI; hBPC = idx - VWSM
                }
            }
        }

        if vowelCount == 2 {
            if ((chr(VSI) == KEY_I) && (chr(VSI+1) == KEY_A)) ||
               ((chr(VSI) == KEY_I) && (chr(VSI+1) == KEY_U)) ||
               ((chr(VSI) == KEY_I) && (chr(VSI+1) == KEY_O)) {
                if VSI == 0 || chr(VSI - 1) != KEY_G {
                    VWSM = VSI; hBPC = idx - VWSM
                } else {
                    VWSM = VSI + 1; hBPC = idx - VWSM
                }
            } else if chr(VSI) == KEY_U && chr(VSI+1) == KEY_A {
                if VSI == 0 || chr(VSI - 1) != KEY_Q {
                    if VEI + 1 >= idx || !canHasEndConsonant() {
                        VWSM = VSI; hBPC = idx - VWSM
                    }
                } else {
                    VWSM = VSI + 1; hBPC = idx - VWSM
                }
            } else if chr(VSI) == KEY_O && chr(VSI+1) == KEY_O {
                VWSM = VEI; hBPC = idx - VWSM
            }
        }

        if preferLastRepeat { VWSM = originalVEI; hBPC = idx - VWSM }
        if adjustedTrailing { VEI = originalVEI; vowelCount = originalVowelCount }
    }

    // MARK: - Old Mark Placement

    func handleOldMark() {
        let originalVEI = VEI, originalVowelCount = vowelCount
        var adjustedTrailing = false
        if vowelCount >= 2 {
            let tailVowel = chr(VEI)
            var tailStart = VEI
            while tailStart > VSI && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
            if VEI - tailStart + 1 >= 2 {
                VEI = tailStart; vowelCount = 0
                for id in VSI...VEI where !isConsonant(chr(id)) { vowelCount += 1 }
                adjustedTrailing = true
            }
        }

        if vowelCount == 0 && chr(VEI) == KEY_I { VWSM = VEI } else { VWSM = VSI }
        hBPC = idx - VWSM

        if vowelCount == 3 || (VEI + 1 < idx && isConsonant(chr(VEI + 1)) && canHasEndConsonant()) {
            VWSM = VSI + 1; hBPC = idx - VWSM
        }

        for ii in VSI...VEI {
            if (chr(ii) == KEY_E && (typingWord[ii] & TONE_MASK) != 0) ||
               (chr(ii) == KEY_O && (typingWord[ii] & TONEW_MASK) != 0) {
                VWSM = ii; hBPC = idx - VWSM; break
            }
        }

        hNCC = hBPC
        if adjustedTrailing { VEI = originalVEI; vowelCount = originalVowelCount }
    }

    // MARK: - Insert Mark

    func insertMark(_ markMask: UInt32, canModifyFlag: Bool = true) {
        vowelCount = 0
        if canModifyFlag { hCode = EngineAction.willProcess.rawValue }
        hBPC = 0; hNCC = 0
        findAndCalculateVowel()
        VWSM = 0

        if vowelCount == 1 {
            VWSM = VEI; hBPC = idx - VEI
        } else {
            if !config.useModernOrthography { handleOldMark() } else { handleModernMark() }
            if (typingWord[VEI] & TONE_MASK) != 0 || (typingWord[VEI] & TONEW_MASK) != 0 {
                VWSM = VEI
            }
        }

        let kk0 = idx - 1 - VSI
        var kk = kk0
        if (typingWord[VWSM] & markMask) != 0 {
            typingWord[VWSM] &= ~MARK_MASK
            if canModifyFlag { hCode = EngineAction.restore.rawValue }
            kk = kk0
            for ii in VSI..<idx {
                typingWord[ii] &= ~MARK_MASK
                hData[kk] = get(typingWord[ii])
                kk -= 1
            }
            tempDisableKey = true
        } else {
            typingWord[VWSM] &= ~MARK_MASK
            typingWord[VWSM] |= markMask
            kk = kk0
            for ii in VSI..<idx {
                if ii != VWSM { typingWord[ii] &= ~MARK_MASK }
                hData[kk] = get(typingWord[ii])
                kk -= 1
            }
            hBPC = idx - VSI
        }
        hNCC = hBPC
    }
}
