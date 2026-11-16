// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CryptoKit
import Foundation

enum DisplayScalingOverride {
    enum Profile: String {
        case hiDPI, flexible
    }

    struct Size: Hashable {
        let width: Int
        let height: Int
    }

    struct Model: Hashable {
        let vendor: UInt32
        let product: UInt32

        var vendorDirectory: String { "DisplayVendorID-\(String(vendor, radix: 16))" }
        var productFile: String { "DisplayProductID-\(String(product, radix: 16))" }
    }

    struct Paths {
        static let localRoot = URL(fileURLWithPath: "/Library/Displays/Contents/Resources/Overrides")
        static let systemRoot = URL(fileURLWithPath: "/System/Library/Displays/Contents/Resources/Overrides")

        let model: Model
        let root: URL

        init(model: Model, root: URL = localRoot) {
            self.model = model
            self.root = root
        }
        var directory: URL { root.appendingPathComponent(model.vendorDirectory) }
        var destination: URL { directory.appendingPathComponent(model.productFile) }
        var state: URL { directory.appendingPathComponent(".vorssaint-\(model.productFile)") }


        static func managed() -> [Paths] {
            let files = FileManager.default
            let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
            let vendors = (try? files.contentsOfDirectory(at: localRoot, includingPropertiesForKeys: keys)) ?? []
            return vendors.flatMap { vendorDirectory -> [Paths] in
                let name = vendorDirectory.lastPathComponent
                let prefix = "DisplayVendorID-"
                guard name.hasPrefix(prefix), let vendor = UInt32(name.dropFirst(prefix.count), radix: 16),
                      let values = try? vendorDirectory.resourceValues(forKeys: Set(keys)),
                      values.isDirectory == true, values.isSymbolicLink == false else { return [] }
                let entries = (try? files.contentsOfDirectory(at: vendorDirectory, includingPropertiesForKeys: keys)) ?? []
                return entries.compactMap { entry in
                    let prefix = ".vorssaint-DisplayProductID-"
                    let name = entry.lastPathComponent
                    guard name.hasPrefix(prefix), let product = UInt32(name.dropFirst(prefix.count), radix: 16),
                          let values = try? entry.resourceValues(forKeys: Set(keys)),
                          values.isDirectory == true, values.isSymbolicLink == false else { return nil }
                    let paths = Paths(model: .init(vendor: vendor, product: product))
                    return paths.state.path == entry.path && paths.owner() != nil ? paths : nil
                }
            }.sorted { $0.state.path < $1.state.path }
        }

        func owner() -> UUID? {
            guard let contents = try? String(contentsOf: state.appendingPathComponent("owner"), encoding: .utf8)
            else { return nil }
            return UUID(uuidString: contents.trimmingCharacters(in: .newlines))
        }

        func profile() -> Profile? {
            guard let contents = try? String(contentsOf: state.appendingPathComponent("profile"), encoding: .utf8)
            else { return nil }
            return Profile(rawValue: contents.trimmingCharacters(in: .newlines))
        }
    }

    // macOS's scale-resolutions entries are two big-endian UInt32 backing
    // dimensions. See Crisp HiDPIService.swift and the adjacent MIT notice.
    static func sizes(for panel: Size, profile: Profile) -> [Size] {
        guard (800...8192).contains(panel.width), (600...8192).contains(panel.height) else { return [] }
        let widths: [Int]
        switch profile {
        case .hiDPI:
            widths = [8, 6, 5, 4].map { (panel.width * $0 / 8) & ~1 }
        case .flexible:
            widths = Array(stride(from: panel.width, through: panel.width / 2, by: -16))
        }
        return widths.compactMap { width in
            let height = (width * panel.height + panel.width / 2) / panel.width
            guard width >= 800, height >= 480 else { return nil }
            return Size(width: width, height: height)
        }
    }

    static func includesHiddenSize(_ size: Size, panel: Size, profile: Profile) -> Bool {
        if size == panel { return true }
        guard profile == .flexible,
              size.width >= max(800, panel.width / 2), size.width <= panel.width,
              size.height >= max(480, panel.height / 2), size.height <= panel.height else { return false }
        let expectedHeight = Double(size.width) * Double(panel.height) / Double(panel.width)
        return abs(Double(size.height) - expectedHeight) / expectedHeight < 0.02
    }

    static func sameRefresh(_ lhs: Double, _ rhs: Double) -> Bool {
        // CoreGraphics reports zero for some modes with no fixed rate.
        if lhs == 0 || rhs == 0 { return lhs == rhs }
        return abs(lhs - rhs) < 0.1
    }

    static func mergedPlist(base: Data?, panel: Size, profile: Profile) throws -> Data {
        var plist: [String: Any] = [:]
        if let base {
            guard let original = try PropertyListSerialization.propertyList(from: base, format: nil) as? [String: Any]
            else { throw InvalidOverride() }
            plist = original
        }
        let sizes = sizes(for: panel, profile: profile)
        guard !sizes.isEmpty else { throw InvalidOverride() }
        var entries: [Data] = []
        if let previous = plist["scale-resolutions"] {
            guard let previous = previous as? [Data] else { throw InvalidOverride() }
            entries = previous
        }
        var seen = Set(entries)
        for size in sizes {
            let entry = [UInt32(size.width * 2).bigEndian, UInt32(size.height * 2).bigEndian]
                .withUnsafeBytes { Data($0) }
            if seen.insert(entry).inserted { entries.append(entry) }
        }
        plist["scale-resolutions"] = entries
        // Keep the base64 payload and AppleScript within the OS argument limit.
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        guard data.count <= 48 * 1024 else { throw InvalidOverride() }
        return data
    }

    static func localPlist(at url: URL) throws -> Data? {
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink == false,
                  let size = values.fileSize, size <= 48 * 1024 else { throw InvalidOverride() }
            return try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        }
    }

    static func install(paths: Paths, owner: UUID, profile: Profile, panel: Size) throws -> String {
        let local = try localPlist(at: paths.destination)
        let base = try local ?? localPlist(at: Paths(model: paths.model, root: Paths.systemRoot).destination)
        let plist = try mergedPlist(base: base, panel: panel, profile: profile)
        let precondition: String
        if let local {
            let digest = SHA256.hash(data: local).map { String(format: "%02x", $0) }.joined()
            precondition = #"test "$(/usr/bin/openssl dgst -sha256 -r "$target" | /usr/bin/cut -d ' ' -f 1)" = '\#(digest)'"#
        } else {
            precondition = #"test ! -e "$target""#
        }
        return transaction(paths: paths, createDirectory: true) + "\n" + #"""
        test ! -e "$state"
        \#(precondition)
        /usr/bin/printf '%s\n' '\#(owner.uuidString)' > "$stage/owner"
        /usr/bin/printf '%s\n' '\#(profile.rawValue)' > "$stage/profile"
        /usr/bin/printf '%s' '\#(plist.base64EncodedString())' | /usr/bin/base64 -D > "$stage/installed"
        /usr/bin/plutil -lint -s "$stage/installed"
        /bin/chmod 644 "$stage/installed"
        if test -e "$target"; then /bin/cp -p "$target" "$stage/original"; fi
        /bin/cp -p "$stage/installed" "$stage/replacement"
        /bin/mv -h "$stage" "$state"
        /bin/mv -fh "$state/replacement" "$target"
        """#
    }

    static func restore(paths: Paths, owner: UUID) -> String {
        transaction(paths: paths, createDirectory: false) + "\n" + #"""
        test -d "$state"
        test "$(/bin/cat "$state/owner")" = '\#(owner.uuidString)'
        if test -e "$state/original"; then
            if ! /usr/bin/cmp -s "$target" "$state/original"; then
                /usr/bin/cmp -s "$target" "$state/installed"
                /bin/cp -p "$state/original" "$stage/original"
                /bin/mv -fh "$stage/original" "$target"
            fi
        elif test -e "$target"; then
            /usr/bin/cmp -s "$target" "$state/installed"
            /bin/rm "$target"
        fi
        /bin/mv -h "$state" "$stage/restored"
        """#
    }

    private static func transaction(paths: Paths, createDirectory: Bool) -> String {
        // Only the two application entry points use the fixed /Library root.
        // A separate root lets the same transaction run in isolated tests.
        let directory = paths.directory.path.replacingOccurrences(of: "'", with: "'\\''")
        return #"""
        set -eu
        umask 022
        dir='\#(directory)'
        target="$dir/\#(paths.model.productFile)"
        state="$dir/.vorssaint-\#(paths.model.productFile)"
        lock="$state.lock"
        ensure_directory() {
            parent=$(/usr/bin/dirname "$1")
            if test "$1" != /; then ensure_directory "$parent"; fi
            test ! -L "$1"
            if test ! -d "$1"; then
                test '\#(createDirectory ? "yes" : "no")' = yes
                /bin/mkdir "$1" || test -d "$1"
            fi
            test ! -L "$1"
            test -d "$1"
            test "$(/usr/bin/stat -f '%u' "$1")" = "$(/usr/bin/id -u)"
            mode=$(/usr/bin/stat -f '%Lp' "$1")
            test "$((0$mode & 022))" -eq 0
        }
        \#(paths.root == Paths.localRoot ? #"ensure_directory "$dir""# : #"test -d "$dir""#)
        test ! -L "$lock"
        test ! -e "$lock" || test -f "$lock"
        exec 9>>"$lock"
        /usr/bin/env -i /usr/bin/perl -e 'flock(STDIN, 6) or exit 1' <&9
        test ! -L "$target"
        if test -e "$target"; then
            test -f "$target"
            test "$(/usr/bin/stat -f '%u' "$target")" = "$(/usr/bin/id -u)"
            mode=$(/usr/bin/stat -f '%Lp' "$target")
            test "$((0$mode & 022))" -eq 0
        fi
        test ! -L "$state"
        stage=$(/usr/bin/mktemp -d "$dir/.vorssaint-stage.XXXXXXXX")
        trap '/bin/rm -rf "$stage"' EXIT
        /bin/chmod 755 "$stage"
        """#
    }

    private struct InvalidOverride: Error {}
}
