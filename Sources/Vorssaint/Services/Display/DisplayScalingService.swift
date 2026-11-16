// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import IOKit.graphics

extension Notification.Name {
    static let displayModeWillChange = Notification.Name("VorssaintDisplayModeWillChange")
}

@MainActor
final class DisplayScalingService: ObservableObject {
    struct Choice {
        let ioDisplayModeID: Int32
        let width: Int
        let height: Int
        let refreshRate: Double
        let pixelWidth: Int
        let pixelHeight: Int
        let publicMode: CGDisplayMode?

        init(_ mode: CGDisplayMode) {
            ioDisplayModeID = mode.ioDisplayModeID
            width = mode.width
            height = mode.height
            refreshRate = mode.refreshRate
            pixelWidth = mode.pixelWidth
            pixelHeight = mode.pixelHeight
            publicMode = mode
        }

        init(_ mode: DisplayScalingHiddenModes.Mode) {
            ioDisplayModeID = mode.id
            width = mode.width
            height = mode.height
            refreshRate = mode.refresh
            pixelWidth = mode.width * 2
            pixelHeight = mode.height * 2
            publicMode = nil
        }

        func matches(_ mode: CGDisplayMode) -> Bool {
            ioDisplayModeID == mode.ioDisplayModeID && sameGeometry(mode)
        }

        func sameGeometry(_ mode: CGDisplayMode) -> Bool {
            mode.width == width && mode.height == height
                && mode.pixelWidth == pixelWidth && mode.pixelHeight == pixelHeight
                && DisplayScalingOverride.sameRefresh(mode.refreshRate, refreshRate)
        }
    }

    struct Monitor: Identifiable {
        let id: UUID
        let displayID: CGDirectDisplayID
        let name: String
        let isBuiltIn: Bool
        let paths: DisplayScalingOverride.Paths
        let sharedModel: Bool
        let panel: DisplayScalingOverride.Size?
        let current: CGDisplayMode?
        let choices: [Choice]
        let refreshChoices: [Choice]
        let proMotionModeID: Int32?

        var isHiDPI: Bool {
            guard let current else { return false }
            return current.pixelWidth == current.width * 2 && current.pixelHeight == current.height * 2
        }

        var owner: UUID? { isBuiltIn ? nil : paths.owner() }
        var profile: DisplayScalingOverride.Profile? { owner == id ? paths.profile() : nil }
    }

    enum Notice: Equatable {
        case reconnect, overrideFailed, modeFailed
    }

    static let shared = DisplayScalingService()
    @Published private(set) var monitors: [Monitor] = []
    @Published private(set) var offline: [DisplayScalingOverride.Paths] = []
    @Published private(set) var offlineNotice: Notice?
    @Published private(set) var busy = false
    @Published private(set) var pending: UUID?
    @Published private(set) var notices: [UUID: Notice] = [:]
    private var lastHiDPISizes: [UUID: DisplayScalingOverride.Size] = [:]
    private var revertTask: Task<Void, Never>?
    private var previewModes: (original: CGDisplayMode, trial: Choice)?

    private init() {}

    func refresh() {
        let managed = DisplayScalingOverride.Paths.managed()
        offline = managed
        guard let online = Self.onlineDisplays() else {
            monitors = []
            return
        }
        let modelCounts = Dictionary(grouping: online, by: Self.model).mapValues(\.count)
        monitors = NSScreen.screens.compactMap { screen in
            guard let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
                  online.contains(displayID),
                  let id = Self.uuid(displayID) else { return nil }
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            let model = Self.model(displayID)
            guard isBuiltIn || (model.vendor != 0 && model.product != 0) else { return nil }
            let paths = DisplayScalingOverride.Paths(model: model)
            let standalone = CGDisplayIsInMirrorSet(displayID) == 0
            let rawModes = standalone ? Self.modes(displayID) : []
            let current = CGDisplayCopyDisplayMode(displayID)
            let panel = Self.panelSize(rawModes, rotation: CGDisplayRotation(displayID))
            let shared = modelCounts[model, default: 0] > 1
            let choices: [Choice]
            let refreshChoices: [Choice]
            if !shared, standalone, let current {
                let publicChoices = rawModes.map(Choice.init)
                let resolutions: [Choice]
                let rateCandidates: [Choice]
                if !isBuiltIn, paths.owner() == id, let profile = paths.profile() {
                    let scaled = Self.scalingChoices(displayID, publicModes: rawModes, panel: panel, profile: profile)
                    resolutions = scaled
                    rateCandidates = current.pixelWidth == current.width * 2 ? scaled : publicChoices
                } else {
                    // Keep the display's scaling factor when choosing a size
                    // without an installed HiDPI profile.
                    resolutions = publicChoices.filter {
                        $0.pixelWidth * current.width == current.pixelWidth * $0.width
                    }
                    rateCandidates = publicChoices
                }
                choices = Self.sortedChoices(resolutions.filter {
                    DisplayScalingOverride.sameRefresh($0.refreshRate, current.refreshRate)
                }, current: current)
                refreshChoices = Self.availableRefreshRates(rateCandidates, current: current)
            } else {
                choices = []
                refreshChoices = []
            }
            return Monitor(id: id, displayID: displayID, name: screen.localizedName, isBuiltIn: isBuiltIn,
                           paths: paths, sharedModel: shared, panel: panel, current: current, choices: choices,
                           refreshChoices: refreshChoices,
                           proMotionModeID: isBuiltIn ? Self.proMotionModeID(rawModes, current: current) : nil)
        }
        let visible = Set(monitors.map { $0.paths.model })
        offline = managed.filter { !visible.contains($0.model) }
    }

    func install(_ profile: DisplayScalingOverride.Profile, for id: UUID, prompt: String,
                 activateAfterInstall: Bool = false) {
        guard !busy, pending == nil else { return }
        refresh()
        guard let monitor = monitors.first(where: { $0.id == id }),
              !monitor.isBuiltIn, monitor.owner == nil, !monitor.sharedModel, let panel = monitor.panel else { return }
        do {
            let command = try DisplayScalingOverride.install(paths: monitor.paths, owner: id,
                                                             profile: profile, panel: panel)
            authorize(command, for: id, prompt: prompt, activateAfterInstall: activateAfterInstall)
        } catch {
            notices[id] = .overrideFailed
        }
    }

    func restore(_ paths: DisplayScalingOverride.Paths, for id: UUID?, prompt: String) {
        guard !busy, pending == nil, let owner = paths.owner() else { return }
        // The user may need to recover an override after moving the panel to
        // another port, even if macOS has assigned that panel a new UUID.
        authorize(DisplayScalingOverride.restore(paths: paths, owner: owner), for: id, prompt: prompt)
    }

    private func authorize(_ command: String, for id: UUID?, prompt: String,
                           activateAfterInstall: Bool = false) {
        busy = true
        AdminShell.run(command, prompt: prompt) { success in
            DispatchQueue.main.async {
                let notice: Notice = success ? .reconnect : .overrideFailed
                if let id {
                    self.notices[id] = notice
                } else {
                    self.offlineNotice = notice
                }
                self.busy = false
                self.refresh()
                if success, activateAfterInstall, let id,
                   self.monitors.first(where: { $0.id == id })?.choices.isEmpty == false {
                    self.setHiDPI(true, for: id)
                }
            }
        }
    }

    /// Switch the current session between 1× and 2× using the installed profile.
    /// The model override stays on disk and can be restored separately.
    func setHiDPI(_ enabled: Bool, for id: UUID) {
        guard !busy, pending == nil else { return }
        refresh()
        guard let monitor = monitors.first(where: { $0.id == id }), let current = monitor.current,
              monitor.profile != nil, !monitor.sharedModel,
              CGDisplayIsInMirrorSet(monitor.displayID) == 0, monitor.isHiDPI != enabled else { return }
        let size = DisplayScalingOverride.Size(width: current.width, height: current.height)
        let target: Choice?
        if enabled {
            let preferred = lastHiDPISizes[id] ?? size
            target = monitor.choices.min {
                Self.distance($0.width, $0.height, from: preferred) < Self.distance($1.width, $1.height, from: preferred)
            }
        } else {
            let modes = Self.modes(monitor.displayID).filter {
                $0.width == $0.pixelWidth && $0.height == $0.pixelHeight
                    && DisplayScalingOverride.sameRefresh($0.refreshRate, current.refreshRate)
            }
            let unscaled = modes.min {
                Self.distance($0.width, $0.height, from: size) < Self.distance($1.width, $1.height, from: size)
            }
            target = unscaled.map(Choice.init)
        }

        guard let target, Self.apply(target, to: monitor.displayID) else {
            notices[id] = .modeFailed
            return
        }
        if !enabled { lastHiDPISizes[id] = size }
        notices[id] = nil
        refresh()
    }

    private static func distance(_ width: Int, _ height: Int, from size: DisplayScalingOverride.Size) -> Int {
        abs(width - size.width) + abs(height - size.height)
    }

    func preview(_ choice: Choice, for id: UUID) {
        guard !busy, pending == nil else { return }
        refresh()
        guard let monitor = monitors.first(where: { $0.id == id }), let original = monitor.current,
              let mode = (monitor.choices + monitor.refreshChoices).first(where: {
                  $0.ioDisplayModeID == choice.ioDisplayModeID && $0.width == choice.width && $0.height == choice.height
                      && $0.pixelWidth == choice.pixelWidth && $0.pixelHeight == choice.pixelHeight
                      && DisplayScalingOverride.sameRefresh($0.refreshRate, choice.refreshRate)
              }),
              !mode.matches(original) else { return }
        guard Self.apply(mode, to: monitor.displayID) else {
            notices[id] = .modeFailed
            return
        }
        notices[id] = nil
        previewModes = (original, mode)
        pending = id
        refresh()
        revertTask = Task {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            revert()
        }
    }

    func keep() {
        revertTask?.cancel()
        revertTask = nil
        pending = nil
        previewModes = nil
    }

    func revert() {
        guard let id = pending, let previewModes else { return }
        keep()
        defer { refresh() }
        guard let target = Self.onlineDisplays()?.first(where: { Self.uuid($0) == id }),
              CGDisplayIsInMirrorSet(target) == 0,
              let current = CGDisplayCopyDisplayMode(target) else {
            notices[id] = .modeFailed
            return
        }
        // A change made outside this preview takes precedence. Reconnection
        // can assign new mode IDs, so check the visible mode attributes here.
        guard previewModes.trial.sameGeometry(current) else { return }
        let publicModes = Self.modes(target)
        let candidates = publicModes.filter { Self.sameGeometryAndRefresh($0, previewModes.original) }
        let original = candidates.first(where: { Self.matches($0, previewModes.original) })
            ?? (candidates.count == 1 ? candidates.first : nil)
        if let original, Self.apply(Choice(original), to: target) { return }
        // Once a scaled mode stops being current, CoreGraphics can hide it
        // again. Revalidate the original mode ID against the live mode table.
        if let hidden = DisplayScalingHiddenModes.modes(target, publicModes: publicModes).first(where: {
            $0.usable && $0.scale == 2 && $0.refresh > 0 && Choice($0).matches(previewModes.original)
        }), Self.apply(Choice(hidden), to: target) { return }
        notices[id] = .modeFailed
    }

    private static func apply(_ mode: Choice, to display: CGDirectDisplayID) -> Bool {
        configure { config in
            if let publicMode = mode.publicMode {
                return CGConfigureDisplayWithDisplayMode(config, display, publicMode, nil) == .success
            }
            return DisplayScalingHiddenModes.configure(config, display: display, mode: mode.ioDisplayModeID)
        }
    }

    private static func configure(_ setMode: (CGDisplayConfigRef) -> Bool) -> Bool {
        var configuration: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&configuration) == .success,
              let configuration else { return false }
        guard setMode(configuration) else {
            CGCancelDisplayConfiguration(configuration)
            return false
        }
        NotificationCenter.default.post(name: .displayModeWillChange, object: nil)
        return CGCompleteDisplayConfiguration(configuration, .forSession) == .success
    }

    private static func onlineDisplays() -> [CGDirectDisplayID]? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        return Array(ids.prefix(Int(count)))
    }

    private static func uuid(_ display: CGDirectDisplayID) -> UUID? {
        guard let value = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, value) as String? else { return nil }
        return UUID(uuidString: string)
    }

    private static func model(_ display: CGDirectDisplayID) -> DisplayScalingOverride.Model {
        .init(vendor: CGDisplayVendorNumber(display), product: CGDisplayModelNumber(display))
    }

    private static func modes(_ display: CGDirectDisplayID) -> [CGDisplayMode] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        let modes = CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode] ?? []
        return modes.filter {
            $0.isUsableForDesktopGUI() && $0.ioFlags & UInt32(kDisplayModeInterlacedFlag) == 0
        }
    }

    private static func panelSize(_ modes: [CGDisplayMode], rotation: Double) -> DisplayScalingOverride.Size? {
        let unscaled = modes.filter { $0.width == $0.pixelWidth && $0.height == $0.pixelHeight }
        let native = unscaled.filter { $0.ioFlags & UInt32(kDisplayModeNativeFlag) != 0 }
        guard let mode = (native.isEmpty ? unscaled : native).max(by: {
            $0.width * $0.height < $1.width * $1.height
        }) else { return nil }
        if abs(rotation.truncatingRemainder(dividingBy: 180)) == 90 {
            return .init(width: mode.height, height: mode.width)
        }
        return .init(width: mode.width, height: mode.height)
    }

    private static func scalingChoices(_ display: CGDirectDisplayID, publicModes: [CGDisplayMode],
                                       panel: DisplayScalingOverride.Size?,
                                       profile: DisplayScalingOverride.Profile) -> [Choice] {
        let visible = publicModes.filter {
            $0.pixelWidth == $0.width * 2 && $0.pixelHeight == $0.height * 2
        }.map(Choice.init)
        var hidden: [Choice] = []
        if let panel, CGDisplayRotation(display) == 0, !publicModes.isEmpty {
            hidden = DisplayScalingHiddenModes.modes(display, publicModes: publicModes).filter {
                $0.usable && $0.scale == 2 && $0.refresh > 0
                    && DisplayScalingOverride.includesHiddenSize(.init(width: $0.width, height: $0.height),
                                                                 panel: panel, profile: profile)
            }.map(Choice.init)
        }
        return visible + hidden
    }

    /// Apple silicon MacBook panels expose ProMotion as their default 120 Hz
    /// timing. The same ID remains in the table when a fixed rate is active.
    /// Do not infer ProMotion for external displays or ambiguous 120 Hz modes.
    private static func proMotionModeID(_ modes: [CGDisplayMode], current: CGDisplayMode?) -> Int32? {
        #if arch(arm64)
        guard let current, modes.contains(where: {
            $0.refreshRate == 120 && $0.ioFlags & UInt32(kDisplayModeDefaultFlag) != 0
        }) else { return nil }
        let sameSize = modes.filter {
            $0.width == current.width && $0.height == current.height
                && $0.pixelWidth == current.pixelWidth && $0.pixelHeight == current.pixelHeight
        }
        let fastModes = Set(sameSize.filter { $0.refreshRate == 120 }.map(\.ioDisplayModeID))
        guard fastModes.count == 1, sameSize.contains(where: { $0.refreshRate == 60 }) else { return nil }
        return fastModes.first
        #else
        return nil
        #endif
    }

    private static func availableRefreshRates(_ choices: [Choice], current: CGDisplayMode) -> [Choice] {
        let sameSize = choices.filter {
            $0.width == current.width && $0.height == current.height
                && $0.pixelWidth == current.pixelWidth && $0.pixelHeight == current.pixelHeight
                && $0.refreshRate > 0
        }
        let publicRates = sameSize.compactMap { $0.publicMode?.refreshRate }
        var seen = Set<Double>()
        return ([Choice(current)] + sameSize).filter { choice in
            guard choice.refreshRate > 0 else { return false }
            // Private records round rates to integer Hz. Prefer the exact
            // public rate when it describes the same nominal timing.
            if choice.publicMode == nil,
               publicRates.contains(where: { DisplayScalingOverride.sameRefresh($0, choice.refreshRate) }) {
                return false
            }
            return seen.insert(choice.refreshRate).inserted
        }.sorted { $0.refreshRate < $1.refreshRate }
    }

    private static func sortedChoices(_ choices: [Choice], current: CGDisplayMode?) -> [Choice] {
        var sizes = Set<DisplayScalingOverride.Size>()
        let currentChoice = choices.first { choice in current.map(choice.matches) == true }
        let preferred = currentChoice.map { [$0] + choices } ?? choices
        return preferred.filter {
            sizes.insert(.init(width: $0.width, height: $0.height)).inserted
        }.sorted {
            ($0.width, $0.height, $0.ioDisplayModeID) < ($1.width, $1.height, $1.ioDisplayModeID)
        }
    }

    static func matches(_ lhs: CGDisplayMode, _ rhs: CGDisplayMode) -> Bool {
        lhs.ioDisplayModeID == rhs.ioDisplayModeID && sameGeometryAndRefresh(lhs, rhs)
    }

    private static func sameGeometryAndRefresh(_ lhs: CGDisplayMode, _ rhs: CGDisplayMode) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height
            && lhs.pixelWidth == rhs.pixelWidth && lhs.pixelHeight == rhs.pixelHeight
            && DisplayScalingOverride.sameRefresh(lhs.refreshRate, rhs.refreshRate)
    }
}
