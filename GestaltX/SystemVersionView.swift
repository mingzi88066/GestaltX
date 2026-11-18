// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 huamidev
import SwiftUI

/// Marketing-version / build spoofing. Edits are staged like every other
/// preset, so backup, review and verification run through the normal flow.
struct SystemVersionView: View {
    @EnvironmentObject private var model: GestaltManager

    /// The running build is not exposed by UIDevice. CacheVersion carries the
    /// same build string that MobileGestalt recorded at boot.
    private var deviceBuild: String {
        if let cacheVersion = model.working?.root["CacheVersion"] as? String, !cacheVersion.isEmpty { return cacheVersion }
        let description = ProcessInfo.processInfo.operatingSystemVersionString
        guard let start = description.range(of: "Build "),
              let end = description.range(of: ")", range: start.upperBound..<description.endIndex) else { return "" }
        return String(description[start.upperBound..<end.lowerBound])
    }
    private var stagedText: String {
        let version = model.versionSpoof.trimmedVersion
        let build = model.versionSpoof.trimmedBuild
        switch (version.isEmpty, build.isEmpty) {
        case (true, true): return L("Not present")
        case (false, true): return version
        case (true, false): return build
        case (false, false): return "\(version) (\(build))"
        }
    }

    var body: some View {
        Form {
            Section(L("Current")) {
                LabeledContent(L("Device"), value: "\(UIDevice.current.systemVersion) (\(VersionSupport.label))")
                LabeledContent("MobileGestalt", value: model.storedSystemVersionText)
            }
            Section {
                Picker(L("Version Spoof"), selection: $model.versionSpoof.choice) {
                    ForEach(VersionSpoofChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: model.versionSpoof.choice) { _, choice in
                    // Start from what the device reports so the user edits a
                    // complete pair instead of inventing a matching build.
                    guard choice == .custom, !model.versionSpoof.hasInput else { return }
                    model.versionSpoof.productVersion = UIDevice.current.systemVersion
                    model.versionSpoof.buildVersion = deviceBuild
                }
                if model.versionSpoof.choice == .custom {
                    TextField(L("Version"), text: $model.versionSpoof.productVersion)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(L("Build"), text: $model.versionSpoof.buildVersion)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button(L("Use Current Values")) {
                        model.versionSpoof.productVersion = UIDevice.current.systemVersion
                        model.versionSpoof.buildVersion = deviceBuild
                    }
                    .font(.footnote)
                    LabeledContent(L("Staged"), value: stagedText)
                }
                HStack(alignment: .firstTextBaseline) {
                    Spacer(minLength: 8)
                    Button(L("Revert")) { Task { await model.restoreSystemVersion() } }
                        .font(.caption).buttonStyle(.borderless)
                        .disabled(!model.canRestoreSystemVersion)
                }
            } header: {
                Text(L("Presets"))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Enter a marketing version such as 27.2 and a build such as 24C101. An empty field keeps its current value."))
                    Text(L("A spoofed pair that no build ever reported can confuse OTA updates, App Store compatibility checks and system services."))
                }
            }
            if let error = model.versionSpoofError {
                Section { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            Section {
                ForEach(SystemVersionKey.all, id: \.self) { key in
                    Text(key).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }
            } header: {
                Text("CacheExtra")
            } footer: {
                Text(L("libMobileGestalt answers version queries from these keys. A restart is required before other processes read the new values."))
            }
            if model.changeCount > 0 {
                Section { NavigationLink(L("Review Changes")) { ChangeReviewView(isSheet: false) } }
            }
        }
        .navigationTitle(L("System Version"))
        .disabled(model.isBusy)
    }
}
