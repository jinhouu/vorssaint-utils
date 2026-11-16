// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Darwin

/// SkyLight's mode record layout follows Crisp's MIT-licensed implementation.
enum DisplayScalingHiddenModes {
    struct Mode {
        let id: Int32
        let width: Int
        let height: Int
        let refresh: Double
        let scale: Float
        let usable: Bool
    }

    private typealias Count = @convention(c) (UInt32, UnsafeMutablePointer<Int32>) -> Int32
    private typealias Describe = @convention(c) (UInt32, Int32, UnsafeMutableRawPointer, Int32) -> Int32
    private typealias Configure = @convention(c) (CGDisplayConfigRef, UInt32, Int32) -> Int32

    private static let api: (Count, Describe, Configure)? = {
        guard let framework = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let count = dlsym(framework, "CGSGetNumberOfDisplayModes"),
              let describe = dlsym(framework, "CGSGetDisplayModeDescriptionOfLength"),
              let configure = dlsym(framework, "CGSConfigureDisplayMode") else { return nil }
        return (unsafeBitCast(count, to: Count.self), unsafeBitCast(describe, to: Describe.self),
                unsafeBitCast(configure, to: Configure.self))
    }()

    static func modes(_ display: CGDirectDisplayID, publicModes: [CGDisplayMode]) -> [Mode] {
        guard let (countModes, describe, _) = api else { return [] }
        var count: Int32 = 0
        guard countModes(display, &count) == 0, (1...4096).contains(count) else { return [] }
        let records: [Mode] = (0..<count).compactMap { index in
            // Aligned, zero-initialized 212-byte mode description.
            var words = [UInt32](repeating: 0, count: 53)
            return words.withUnsafeMutableBytes { bytes in
                guard let base = bytes.baseAddress, describe(display, index, base, 212) == 0 else { return nil }
                return Mode(id: bytes.load(as: Int32.self),
                            width: Int(bytes.load(fromByteOffset: 8, as: UInt32.self)),
                            height: Int(bytes.load(fromByteOffset: 12, as: UInt32.self)),
                            refresh: Double(bytes.load(fromByteOffset: 190, as: UInt16.self)),
                            scale: bytes.load(fromByteOffset: 208, as: Float.self),
                            usable: bytes.load(fromByteOffset: 4, as: UInt32.self) & 0x40000000 == 0)
            }
        }
        // Disable the fallback if the private layout no longer agrees with
        // at least one known public mode's ID, size, scale and fixed rate.
        guard publicModes.contains(where: { mode in
            mode.refreshRate > 0 && records.contains {
                $0.id == mode.ioDisplayModeID && $0.width == mode.width && $0.height == mode.height
                    && Double($0.scale) * Double(mode.width) == Double(mode.pixelWidth)
                    && abs($0.refresh - mode.refreshRate) < 0.5
            }
        }) else { return [] }
        return records
    }

    static func configure(_ config: CGDisplayConfigRef, display: CGDirectDisplayID, mode: Int32) -> Bool {
        api?.2(config, display, mode) == 0
    }
}
