import AppKit
import Foundation
import Observation
import ReplierCore

@MainActor
@Observable
final class OnboardingModel {
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    static let dataControlsConfirmedKey = "dataControlsConfirmed"

    var accessibilityGranted = false

    var codexCheckInProgress = false
    var codexExecutableFound = false
    var codexAccountStatus: CodexAccountStatus?
    var codexCheckError: String?

    var codexModel: String {
        didSet { UserDefaults.standard.set(codexModel, forKey: CodexSettings.modelDefaultsKey) }
    }
    var codexReasoningEffort: String {
        didSet { UserDefaults.standard.set(codexReasoningEffort, forKey: CodexSettings.reasoningEffortDefaultsKey) }
    }

    var dataControlsConfirmed: Bool {
        didSet { UserDefaults.standard.set(dataControlsConfirmed, forKey: Self.dataControlsConfirmedKey) }
    }

    var newSampleText = ""
    var styleSamples: [StyleSample] = []
    var styleErrorMessage: String?

    private let styleProfileStore: StyleProfileStore

    init(styleProfileStore: StyleProfileStore) {
        self.styleProfileStore = styleProfileStore
        self.dataControlsConfirmed = UserDefaults.standard.bool(forKey: Self.dataControlsConfirmedKey)
        self.codexModel = CodexSettings.currentModel()
        self.codexReasoningEffort = CodexSettings.currentReasoningEffort()
    }

    func refreshAccessibilityStatus() {
        accessibilityGranted = SelectionReader.hasAccessibilityPermission(prompt: false)
    }

    func requestAccessibilityPermission() {
        _ = SelectionReader.hasAccessibilityPermission(prompt: true)
        refreshAccessibilityStatus()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }

    func recheckCodex() async {
        codexCheckInProgress = true
        codexCheckError = nil
        codexAccountStatus = nil
        defer { codexCheckInProgress = false }

        guard let executableURL = CodexAppServerClient.locateExecutable() else {
            codexExecutableFound = false
            return
        }
        codexExecutableFound = true

        let client = CodexAppServerClient(executableURL: executableURL)
        do {
            try await client.start()
            codexAccountStatus = try await client.accountStatus()
        } catch {
            codexCheckError = String(describing: error)
        }
        await client.shutdown()
    }

    func loadStyleSamples() {
        Task {
            styleSamples = (try? await styleProfileStore.samples()) ?? []
        }
    }

    func addStyleSample() {
        let text = newSampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            do {
                _ = try await styleProfileStore.add(text)
                newSampleText = ""
                styleSamples = try await styleProfileStore.samples()
            } catch {
                styleErrorMessage = String(describing: error)
            }
        }
    }

    func removeStyleSample(id: UUID) {
        Task {
            do {
                try await styleProfileStore.remove(id: id)
                styleSamples = try await styleProfileStore.samples()
            } catch {
                styleErrorMessage = String(describing: error)
            }
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
    }
}
