// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation
import IOKit

enum DisplayDithering {
    static func enabled(for display: CGDirectDisplayID) -> Bool? {
        withFramebuffer(for: display) { property("enableDither", on: $0) as? Bool }
    }

    static func set(_ enabled: Bool, for display: CGDirectDisplayID) -> Bool {
        withFramebuffer(for: display) { entry in
            guard let previous = property("enableDither", on: entry) as? Bool else { return false }
            if previous == enabled { return true }
            let value = enabled ? kCFBooleanTrue : kCFBooleanFalse
            return IORegistryEntrySetCFProperty(entry, "enableDither" as CFString, value) == KERN_SUCCESS
                && property("enableDither", on: entry) as? Bool == enabled
        } ?? false
    }

    private static func withFramebuffer<T>(for display: CGDirectDisplayID,
                                           _ action: (io_service_t) -> T?) -> T? {
        guard CGDisplayIsActive(display) != 0, CGDisplayIsInMirrorSet(display) == 0 else { return nil }
        let builtIn = CGDisplayIsBuiltin(display) != 0
        let vendor = CGDisplayVendorNumber(display)
        let product = CGDisplayModelNumber(display)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOMobileFramebufferAP"),
                                           &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var matches: [io_service_t] = []
        defer { matches.forEach { IOObjectRelease($0) } }
        while case let entry = IOIteratorNext(iterator), entry != IO_OBJECT_NULL {
            let attributes = property("DisplayAttributes", on: entry) as? [String: Any]
            let info = attributes?["ProductAttributes"] as? [String: Any]
            let external = property("external", on: entry) as? Bool ?? false
            // Built-in panels can expose an extended ProductID. External
            // matches must agree with both CoreGraphics IDs and be unique.
            if external != builtIn, info?["LegacyManufacturerID"] as? UInt32 == vendor,
               builtIn || info?["ProductID"] as? UInt32 == product {
                matches.append(entry)
            } else {
                IOObjectRelease(entry)
            }
        }
        guard matches.count == 1, let entry = matches.first else { return nil }
        return action(entry)
    }

    private static func property(_ key: String, on entry: io_service_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
