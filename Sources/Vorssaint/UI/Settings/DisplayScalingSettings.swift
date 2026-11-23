// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct DisplayScalingSettings: View {
    @ObservedObject private var service = DisplayScalingService.shared
    @ObservedObject private var l10n = L10n.shared

    private var strings: DisplayScalingStrings { DisplayScalingStrings(l10n.language) }
    private var externalMonitors: [DisplayScalingService.Monitor] {
        service.monitors.filter { !$0.isBuiltIn }
    }

    var body: some View {
        SettingsCard {
            Label(strings[.title], systemImage: "display").font(.headline)
            caption(strings[.modelScope])
            if externalMonitors.isEmpty { caption(strings[.connect]) }
            ForEach(externalMonitors) { monitor in
                Divider()
                MonitorScalingSettings(monitor: monitor, service: service, strings: strings, compact: false)
            }
            offlineControls
        }
        .onAppear { service.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            service.refresh()
        }
    }

    @ViewBuilder private var offlineControls: some View {
        ForEach(service.offline, id: \.model) { paths in
            Divider()
            HStack {
                Text(strings[.disconnected])
                Text("\(String(paths.model.vendor, radix: 16)):\(String(paths.model.product, radix: 16))")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(strings[.restore]) {
                    service.restore(paths, for: nil, prompt: strings[.prompt])
                }
                .disabled(service.busy || service.pending != nil)
            }
        }
        if service.offlineNotice == .overrideFailed {
            caption(strings[.restoreFailed])
        }
    }
}

struct MonitorScalingSettings: View {
    let monitor: DisplayScalingService.Monitor
    @ObservedObject var service: DisplayScalingService
    let strings: DisplayScalingStrings
    let compact: Bool
    @State private var selection = 0
    @State private var isDragging = false
    @State private var requestedSelection: Int?
    @State private var selectedProfile: DisplayScalingOverride.Profile = .hiDPI

    private var profile: DisplayScalingOverride.Profile? { monitor.profile }
    private var buttonLayout: AnyLayout {
        compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !compact { Text(monitor.name).font(.subheadline.weight(.semibold)) }
            if monitor.isBuiltIn {
                modeControls
            } else if monitor.sharedModel {
                caption(strings[.collision])
            } else if monitor.owner == nil {
                if canEnable {
                    if compact {
                        Picker(strings[.title], selection: $selectedProfile) {
                            Text("HiDPI").tag(DisplayScalingOverride.Profile.hiDPI)
                            Text(strings[.flexibleProfile]).tag(DisplayScalingOverride.Profile.flexible)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .disabled(service.busy || service.pending != nil)
                    } else {
                        buttonLayout {
                            Button(strings[.enable]) {
                                service.install(.hiDPI, for: monitor.id, prompt: strings[.prompt])
                            }
                            Button(strings[.enableFlexible]) {
                                service.install(.flexible, for: monitor.id, prompt: strings[.prompt])
                            }
                        }
                        .disabled(service.busy || service.pending != nil)
                    }
                } else {
                    caption(strings[.directConnection])
                }
                if compact && !monitor.choices.isEmpty { modeControls }
            } else if let profile {
                if !compact || profile != .flexible {
                    Text(strings[profile == .flexible ? .flexibleInstalled : .hiDPIInstalled])
                        .font(.caption)
                }
                modeControls
            } else {
                caption(strings[.differentIdentity])
            }

            if monitor.refreshChoices.count > 1 {
                let selection = Binding(
                    get: { monitor.current?.refreshRate ?? 0 },
                    set: { rate in
                        if let mode = monitor.refreshChoices.first(where: { $0.refreshRate == rate }) {
                            service.preview(mode, for: monitor.id)
                        }
                    }
                )
                displayControlRow(strings[.refreshRate]) {
                    Picker(strings[.refreshRate], selection: selection) {
                        if monitor.current?.refreshRate == 0 { Text("—").tag(0.0) }
                        ForEach(monitor.refreshChoices, id: \.refreshRate) { mode in
                            Text(mode.ioDisplayModeID == monitor.proMotionModeID
                                 ? "ProMotion"
                                 : "\(mode.refreshRate.formatted(.number.precision(.fractionLength(0...2)))) Hz")
                                .tag(mode.refreshRate)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(service.busy || service.pending != nil)
                }
            }

            if let signal = monitor.signal {
                if signal.choices.count > 1 {
                    Picker(strings.colorSignalFormat, selection: Binding(
                        get: { signal.active },
                        set: { service.previewSignal($0, for: monitor.id) }
                    )) {
                        ForEach(signal.choices, id: \.self) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(service.busy || service.pending != nil)
                } else {
                    LabeledContent(strings.colorSignalFormat, value: signal.active.label)
                }
            }

            if compact && !monitor.isBuiltIn && !monitor.sharedModel && (profile != nil || canEnable) {
                displaySwitch("HiDPI", isOn: Binding(
                    get: { profile != nil && monitor.isHiDPI },
                    set: { enabled in
                        if profile != nil {
                            service.setHiDPI(enabled, for: monitor.id)
                        } else if enabled {
                            service.install(selectedProfile, for: monitor.id, prompt: strings[.prompt],
                                            activateAfterInstall: true)
                        }
                    }
                ))
            }

            if let dithering = monitor.gpuDithering {
                displaySwitch(strings.gpuDithering, isOn: Binding(
                    get: { dithering },
                    set: { service.setGPUDithering($0, for: monitor.id) }
                ))
            }

            if monitor.owner != nil, !compact || profile == nil {
                Button(strings[.restore]) {
                    service.restore(monitor.paths, for: monitor.id, prompt: strings[.prompt])
                }
                .disabled(service.busy || service.pending != nil)
            }

            if service.pending == monitor.id {
                caption(strings[.revertTimer])
                buttonLayout {
                    Button(strings[.keep]) { service.keep() }
                    Button(strings[.revert]) { service.revert() }
                }
            }
            switch service.notices[monitor.id] {
            case .reconnect:
                caption(strings[.reconnect])
            case .overrideFailed:
                caption(strings[.overrideFailed])
            case .modeFailed:
                caption(strings[.modeFailed])
            case .signalFailed:
                caption(strings.signalFailed)
            case nil:
                EmptyView()
            }
        }
        .onAppear(perform: resetSelection)
        .onChange(of: monitor.choices.map(\.ioDisplayModeID)) { _, _ in resetSelection() }
        .onChange(of: monitor.current?.ioDisplayModeID) { _, _ in resetSelection() }
    }

    private func displaySwitch(_ title: String, isOn: Binding<Bool>) -> some View {
        displayControlRow(title) {
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(compact ? .mini : .small)
                .disabled(service.busy || service.pending != nil)
        }
    }

    @ViewBuilder private func displayControlRow<Control: View>(_ title: String,
                                                               @ViewBuilder control: () -> Control) -> some View {
        if compact {
            HStack(spacing: 8) {
                Text(title).accessibilityHidden(true)
                Spacer(minLength: 0)
                control().labelsHidden()
            }
        } else {
            control()
        }
    }

    private var canEnable: Bool {
        guard !monitor.isBuiltIn, !monitor.sharedModel, monitor.owner == nil, let panel = monitor.panel else { return false }
        return !DisplayScalingOverride.sizes(for: panel, profile: .hiDPI).isEmpty
    }

    @ViewBuilder private var modeControls: some View {
        if monitor.choices.isEmpty {
            caption(strings[.noModes])
        } else if monitor.choices.indices.contains(selection) {
            let mode = monitor.choices[selection]
            VStack(alignment: .leading, spacing: 12) {
                let rate = mode.refreshRate > 0
                    ? " · \(mode.refreshRate.formatted(.number.precision(.fractionLength(0...2)))) Hz"
                    : ""
                let label = "\(mode.width) × \(mode.height)\(rate)"
                if monitor.choices.count > 1 {
                    let slider = Slider(value: Binding(
                        get: { Double(selection) },
                        set: { value in
                            selection = Int(value)
                            if !isDragging { requestedSelection = selection }
                        }
                    ), in: 0...Double(monitor.choices.count - 1), step: 1) {
                        Text(strings[.displayResolution])
                    } onEditingChanged: { editing in
                        isDragging = editing
                        requestedSelection = editing ? nil : selection
                    }
                    if compact {
                        MonitorSliderLayout(title: strings[.displayResolution], value: label, symbol: "arrow.up.left.and.arrow.down.right") {
                            slider.labelsHidden().accessibilityValue(label)
                        }
                    } else {
                        slider
                        Text(label).monospacedDigit()
                    }
                } else {
                    Button(label) { service.preview(mode, for: monitor.id) }
                        .monospacedDigit()
                        .disabled(monitor.current.map { mode.matches($0) } == true)
                }
            }
            .task(id: requestedSelection) {
                guard let requestedSelection else { return }
                // Coalesce key repeats and accessibility edits. A drag submits
                // once, after the user releases the slider.
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
                guard !Task.isCancelled, monitor.choices.indices.contains(requestedSelection) else { return }
                self.requestedSelection = nil
                service.preview(monitor.choices[requestedSelection], for: monitor.id)
            }
            .disabled(service.busy || service.pending != nil)
        }
    }

    private func resetSelection() {
        requestedSelection = nil
        selection = monitor.choices.firstIndex(where: { mode in
            guard let current = monitor.current else { return false }
            return current.width == mode.width && current.height == mode.height
        }) ?? 0
    }
}

private func caption(_ text: String) -> some View {
    Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
}
