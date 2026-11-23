// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Darwin

enum DisplaySignalFormat {
    fileprivate enum Encoding: UInt32 {
        case rgb = 0
        case yCbCr444 = 1
        case yCbCr422 = 2
        case yCbCr420 = 3

        var label: String {
            switch self {
            case .rgb: return "RGB"
            case .yCbCr444: return "YCbCr 4:4:4"
            case .yCbCr422: return "YCbCr 4:2:2"
            case .yCbCr420: return "YCbCr 4:2:0"
            }
        }
    }

    struct Format: Hashable {
        fileprivate let bitDepth: UInt32
        fileprivate let fullRange: UInt32
        fileprivate let transfer: UInt32
        fileprivate let encoding: Encoding

        fileprivate init?(words: ArraySlice<UInt32>) {
            var fields = words.makeIterator()
            guard let bitDepth = fields.next(), [8, 10, 12, 16].contains(bitDepth),
                  let fullRange = fields.next(), fullRange <= 1,
                  let transfer = fields.next(), transfer == 0,
                  let encodingTag = fields.next(), let encoding = Encoding(rawValue: encodingTag) else {
                return nil
            }
            self.bitDepth = bitDepth
            self.fullRange = fullRange
            self.transfer = transfer
            self.encoding = encoding
        }

        var label: String {
            let range = fullRange == 1 ? "Full" : "Limited"
            return "\(encoding.label) · \(bitDepth)-bit SDR · \(range)"
        }
    }

    struct State {
        let active: Format
        let choices: [Format]
    }

    private typealias CurrentMode = @convention(c) (UInt32, UnsafeMutablePointer<Int32>) -> Int32
    private typealias Count = @convention(c) (UInt32, Int32, UnsafeMutablePointer<Int32>) -> Int32
    private typealias Describe = @convention(c) (
        UInt32, Int32, UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>
    ) -> Int32
    private typealias Configure = @convention(c) (CGDisplayConfigRef, UInt32, UInt64, UInt64) -> Int32

    private struct API {
        let currentMode: CurrentMode
        let count: Count
        let describe: Describe
        let configure: Configure
    }

    private static let api: API? = {
        #if arch(arm64)
        guard let framework = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let currentMode = dlsym(framework, "SLSGetCurrentDisplayMode"),
              let count = dlsym(framework, "SLSGetDisplayOutputModeCount"),
              let describe = dlsym(framework, "SLSGetDisplayOutputModeLinkDescriptions"),
              let configure = dlsym(framework, "SLSConfigureDisplayOutputMode") else { return nil }
        return API(currentMode: unsafeBitCast(currentMode, to: CurrentMode.self),
                   count: unsafeBitCast(count, to: Count.self),
                   describe: unsafeBitCast(describe, to: Describe.self),
                   configure: unsafeBitCast(configure, to: Configure.self))
        #else
        return nil
        #endif
    }()

    static func state(for display: CGDirectDisplayID, mode: CGDisplayMode) -> State? {
        guard let records = records(for: display, mode: mode), let active = records.formats[records.selected]
        else { return nil }
        let formats = records.formats.compactMap { $0 }
        let choices = formats.filter { format in formats.filter { $0 == format }.count == 1 }
        guard choices.contains(active) else { return nil }
        return State(active: active, choices: choices)
    }

    static func configure(
        _ configuration: CGDisplayConfigRef, display: CGDirectDisplayID, mode: CGDisplayMode, format: Format
    ) -> Bool {
        guard let api, let state = state(for: display, mode: mode), state.choices.contains(format) else {
            return false
        }
        // The arm64 ABI carries the 16-byte SLSLinkDescription by value in two 64-bit registers.
        let first = UInt64(format.bitDepth) | (UInt64(format.fullRange) << 32)
        let second = UInt64(format.transfer) | (UInt64(format.encoding.rawValue) << 32)
        return api.configure(configuration, display, first, second) == 0
    }

    private static func records(for display: CGDirectDisplayID, mode: CGDisplayMode)
        -> (formats: [Format?], selected: Int)? {
        guard let api,
              let liveMode = CGDisplayCopyDisplayMode(display),
              liveMode.ioDisplayModeID == mode.ioDisplayModeID,
              liveMode.width == mode.width, liveMode.height == mode.height,
              liveMode.pixelWidth == mode.pixelWidth, liveMode.pixelHeight == mode.pixelHeight,
              liveMode.refreshRate == mode.refreshRate else { return nil }
        var modeIndex: Int32 = -1
        var count: Int32 = 0
        guard api.currentMode(display, &modeIndex) == 0, modeIndex >= 0, modeIndex == mode.ioDisplayModeID,
              api.count(display, modeIndex, &count) == 0, (1...64).contains(count) else { return nil }

        // SkyLight writes four native-endian UInt32 words for each output format.
        let wordsPerFormat = 4
        var words = [UInt32](repeating: UInt32.max, count: Int(count) * wordsPerFormat)
        var actualCount = count
        var selected: Int32 = -1
        let result = words.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else { return Int32(-1) }
            return api.describe(display, modeIndex, base, &actualCount, &selected)
        }
        var finalModeIndex: Int32 = -1
        guard result == 0, actualCount == count, (0..<count).contains(selected),
              api.currentMode(display, &finalModeIndex) == 0, finalModeIndex == modeIndex else { return nil }
        let formats = (0..<Int(count)).map { index in
            let start = index * wordsPerFormat
            return Format(words: words[start..<(start + wordsPerFormat)])
        }
        return (formats, Int(selected))
    }
}
