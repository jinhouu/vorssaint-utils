// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum DisplayScalingOverrideTests {
    static func run(_ suite: TestSuite) {
        do {
            try exercise(suite)
        } catch {
            suite.expect(false, "display override fixtures failed: \(error)")
        }
    }

    private static func exercise(_ suite: TestSuite) throws {
        typealias Override = DisplayScalingOverride
        let fhd = Override.Size(width: 1920, height: 1080)
        let qhd = Override.Size(width: 2560, height: 1440)
        for width in [1600, 1280] {
            let size = Override.Size(width: width, height: width * 9 / 16)
            suite.expect(Override.includesHiddenSize(size, panel: fhd, profile: .flexible),
                         "Flexible Scaling includes hidden FHD aspect-ratio modes")
            suite.expect(!Override.includesHiddenSize(size, panel: fhd, profile: .hiDPI),
                         "the basic profile keeps the hidden-mode fallback at native size")
        }
        suite.expect(Override.includesHiddenSize(fhd, panel: fhd, profile: .hiDPI),
                     "native-size FHD HiDPI remains available")
        suite.expect(!Override.includesHiddenSize(.init(width: 1280, height: 800), panel: fhd, profile: .flexible)
                     && !Override.includesHiddenSize(.init(width: 2048, height: 1152), panel: fhd, profile: .flexible),
                     "Flexible Scaling excludes hidden modes with a different aspect or larger than the panel")
        let standard = Override.sizes(for: fhd, profile: .hiDPI)
        suite.expect(standard.map(\.width) == [1920, 1440, 1200, 960], "FHD standard sizes use the panel aspect and minimum height")
        let flexible = Override.sizes(for: qhd, profile: .flexible)
        suite.expect(flexible.count == 81 && flexible.last == .init(width: 1280, height: 720),
                     "QHD flexible sizes span the native to half-native range in 16-point steps")
        suite.expect(Override.sizes(for: .init(width: 0, height: 0), profile: .flexible).isEmpty,
                     "invalid dimensions never produce modes")

        suite.expect(Override.sameRefresh(59.94, 60) && !Override.sameRefresh(60, 120),
                     "preserve the refresh family and avoid switching to another fixed rate")
        suite.expect(Override.sameRefresh(0, 0) && !Override.sameRefresh(0, 60),
                     "unknown refresh rates match only other unknown rates")
        for language in AppLanguage.allCases {
            let strings = DisplayScalingStrings(language)
            suite.expect(DisplayScalingStrings.Key.allCases.allSatisfy { !strings[$0].isEmpty },
                         "every HiDPI label is present for \(language.rawValue)")
        }

        let originalMode = Data([0, 0, 15, 0, 0, 0, 8, 112])
        let original = try PropertyListSerialization.data(fromPropertyList: [
            "DisplayProductName": "Fixture",
            "scale-resolutions": [originalMode]
        ], format: .binary, options: 0)
        let merged = try Override.mergedPlist(base: original, panel: fhd, profile: .hiDPI)
        let plist = try PropertyListSerialization.propertyList(from: merged, format: nil) as? [String: Any]
        let scales = plist?["scale-resolutions"] as? [Data]
        suite.expect(plist?["DisplayProductName"] as? String == "Fixture", "existing metadata survives installation")
        suite.expect(scales?.count == 4 && scales?.first == originalMode,
                     "backing dimensions are big-endian and existing modes are deduplicated")

        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("vorssaint-scale-\(UUID())")
        let paths = Override.Paths(model: .init(vendor: 0x1234, product: 0xabcd), root: root)
        try files.createDirectory(at: paths.directory, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }
        let owner = UUID()
        let firstInstall = try Override.install(paths: paths, owner: owner, profile: .hiDPI, panel: fhd)
        suite.expect(execute(firstInstall), "initial install succeeds when no override exists")
        suite.expect(paths.owner() == owner && paths.profile() == .hiDPI, "opt-in is stored against the monitor UUID")
        suite.expect(!execute(firstInstall), "an existing model override cannot be claimed twice")
        suite.expect(!execute(Override.restore(paths: paths, owner: UUID())), "another UUID cannot restore this override")
        suite.expect(execute(Override.restore(paths: paths, owner: owner)), "restore removes the override added by Vorssaint")
        suite.expect(!files.fileExists(atPath: paths.destination.path) && paths.owner() == nil, "restore removes only managed state")

        try original.write(to: paths.destination)
        let install = try Override.install(paths: paths, owner: owner, profile: .flexible, panel: qhd)
        let foreign = Data("changed by another tool".utf8)
        try foreign.write(to: paths.destination)
        suite.expect(!execute(install) && paths.owner() == nil, "install detects changes made during authorization")
        try original.write(to: paths.destination)
        suite.expect(execute(install), "install merges and backs up an existing override")
        let installed = try Data(contentsOf: paths.destination)
        try foreign.write(to: paths.destination)
        let restore = Override.restore(paths: paths, owner: owner)
        suite.expect(!execute(restore) && paths.owner() == owner, "restore preserves a newer third-party override and the backup")
        try installed.write(to: paths.destination)
        suite.expect(execute(restore), "restore replaces the unchanged installed override")
        let restored = try Data(contentsOf: paths.destination)
        suite.expect(restored == original, "the previous override is restored byte for byte")

        try files.removeItem(at: paths.destination)
        let outside = root.appendingPathComponent("outside")
        try original.write(to: outside)
        try files.createSymbolicLink(at: paths.destination, withDestinationURL: outside)
        suite.expect(!execute(firstInstall), "a symbolic-link destination is rejected")
        let untouched = try Data(contentsOf: outside)
        suite.expect(untouched == original, "the symbolic-link target remains unchanged")
    }

    private static func execute(_ command: String) -> Bool {
        Shell.run("/bin/sh", ["-c", command]).status == 0
    }
}
