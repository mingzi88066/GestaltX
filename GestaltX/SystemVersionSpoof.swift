// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 huamidev
import Foundation

/// CacheExtra keys that libMobileGestalt answers version queries from.
/// Keys cross-checked against Gester and the KAMUI preset list.
enum SystemVersionKey {
    static let productVersion = "qNNddlUK+B/YlooNoymwgA"
    static let buildVersion = "mZfUC7qo4pURNhyMHZ62RQ"
    static let humanReadableVersion = "ToLFRidm+eJGWnpw6W4Wwg"
    static let cachedVersionText = "P5Go9WVVA604m7rKhbVndw"
    static let all = [productVersion, buildVersion, humanReadableVersion, cachedVersionText]
}

enum VersionSpoofChoice: Int, CaseIterable, Identifiable {
    case keep, custom, restoreOriginal, removeAdded
    var id: Int { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .keep: "Keep Current"
        case .custom: "Custom Version"
        case .restoreOriginal: "Restore Original"
        case .removeAdded: "Remove Added Fields"
        }
    }
}

/// Staged marketing-version / build spoof. Values are written during the normal
/// review-and-apply flow, so the existing backup, diff and verification steps
/// also cover these keys.
struct SystemVersionSpoof: Equatable {
    var choice: VersionSpoofChoice = .keep
    var productVersion = ""
    var buildVersion = ""

    static func current(in document: GestaltDocument?) -> (version: String, build: String) {
        let version = document?.extra[SystemVersionKey.productVersion] as? String ?? ""
        let build = document?.extra[SystemVersionKey.buildVersion] as? String ?? ""
        return (version, build)
    }

    var trimmedVersion: String { productVersion.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedBuild: String { buildVersion.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasInput: Bool { !trimmedVersion.isEmpty || !trimmedBuild.isEmpty }

    /// Empty fields keep whatever the document already holds, so a build-only
    /// spoof does not silently invent a marketing version.
    func validated() throws -> (version: String?, build: String?) {
        guard hasInput else { throw GestaltFailure("Enter a version, a build, or both before applying.") }
        if !trimmedVersion.isEmpty, !Self.isValidVersion(trimmedVersion) {
            throw GestaltFailure("Enter a version such as 27.2. Use up to three numeric components.")
        }
        if !trimmedBuild.isEmpty, !Self.isValidBuild(trimmedBuild) {
            throw GestaltFailure("Enter a build such as 24C101: two digits, a letter, then the build number.")
        }
        return (trimmedVersion.isEmpty ? nil : trimmedVersion, trimmedBuild.isEmpty ? nil : trimmedBuild)
    }

    var validationError: String? {
        guard choice == .custom, hasInput else { return nil }
        do { _ = try validated(); return nil } catch { return error.localizedDescription }
    }

    static func isValidVersion(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return false }
        // Marketing versions are 1–2 digits per component: 17, 18.1, 27.2.1.
        return parts.allSatisfy { part in
            (1...2).contains(part.count) && part.allSatisfy(\.isNumber)
        }
    }

    static func isValidBuild(_ text: String) -> Bool {
        text.range(of: #"^[0-9]{2}[A-Z][0-9]{2,4}[a-z]?$"#, options: .regularExpression) != nil
    }

    func apply(to document: inout GestaltDocument, restoringFrom snapshot: DocumentSnapshot) {
        switch choice {
        case .keep:
            return
        case .custom:
            guard let values = try? validated() else { return }
            if let version = values.version {
                document.set(version, for: SystemVersionKey.productVersion)
                document.set(version, for: SystemVersionKey.humanReadableVersion)
            }
            if let build = values.build { document.set(build, for: SystemVersionKey.buildVersion) }
            // A cached human-readable string would otherwise disagree with the
            // spoofed pair; system components rebuild it from these keys.
            document.set(nil, for: SystemVersionKey.cachedVersionText)
        case .restoreOriginal:
            for key in SystemVersionKey.all { document.set(snapshot.originalValue(for: key), for: key) }
        case .removeAdded:
            for key in SystemVersionKey.all where snapshot.originalValue(for: key) == nil { document.set(nil, for: key) }
        }
    }
}
