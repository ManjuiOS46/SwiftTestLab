//
//  AppModel.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import AppKit
import Foundation
import Observation
import SwiftTestLabKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case start
        case ready
        case generating
        case verifying
        case finished
        case failed
        case accepted
    }

    enum Workspace {
        case package(SwiftPackage)
        case file(StandaloneFile)
    }

    enum ConnectionStatus: Equatable {
        case unknown
        case checking
        case reachable(modelCount: Int)
        case unreachable(String)
    }

    // MARK: - Provider

    var providerKind: ProviderKind = .anthropic { didSet { persist(); onProviderChanged() } }
    var anthropicModel: String = ProviderConfiguration.anthropicDefault.model { didSet { persist() } }
    var openBaseURL: String = ProviderConfiguration.openModelDefault.baseURL { didSet { persist() } }
    var openModel: String = "" { didSet { persist() } }

    private(set) var availableOpenModels: [String] = []
    private(set) var connection: ConnectionStatus = .unknown
    private(set) var hasAnthropicKey = false
    private(set) var hasOpenModelKey = false

    var configuration: ProviderConfiguration {
        switch providerKind {
        case .anthropic:
            ProviderConfiguration(kind: .anthropic, baseURL: "", model: anthropicModel)
        case .openAICompatible:
            ProviderConfiguration(kind: .openAICompatible, baseURL: openBaseURL, model: openModel)
        }
    }

    /// True when a local server is up with models loaded — which makes "no API key"
    /// a one-click problem rather than a dead end.
    var canOfferLocalModel: Bool {
        guard case .reachable(let count) = connection, count > 0 else { return false }
        return !availableOpenModels.isEmpty
    }

    var localRuntimeName: String {
        LocalRuntime.named(matching: openBaseURL)?.name ?? "a local model"
    }

    func switchToLocalModel() {
        if openModel.isEmpty {
            openModel = ProviderConfiguration.preferredModel(among: availableOpenModels) ?? ""
        }
        providerKind = .openAICompatible
    }

    var hasCredentialForCurrentProvider: Bool {
        switch providerKind {
        case .anthropic: hasAnthropicKey
        case .openAICompatible: hasOpenModelKey
        }
    }

    /// What's stopping a run, in a sentence, or nil when nothing is.
    var blockingReason: String? {
        if configuration.requiresCredential && !hasCredentialForCurrentProvider {
            return "No API key set for \(configuration.providerName)."
        }
        if configuration.model.trimmingCharacters(in: .whitespaces).isEmpty {
            return providerKind == .anthropic
                ? "No model chosen."
                : "No model chosen — pick one from the endpoint in Settings."
        }
        if !configuration.isReadyToSend {
            return "\(openBaseURL) isn't a usable endpoint."
        }
        return nil
    }

    // MARK: - Workspace

    private(set) var workspace: Workspace?
    var fileFilter = ""
    var selectedFile: SourceFile? {
        didSet {
            // Only a real change of file resets the run. A List rebuilding its
            // selection briefly sets this to nil, and treating that as a change
            // threw away finished results in front of the user.
            guard let selectedFile, selectedFile != oldValue else { return }
            resetRun()
        }
    }

    var subject: TestSubject? {
        switch workspace {
        case .package(let package):
            guard let selectedFile else { return nil }
            return .inPackage(package: package, file: selectedFile)
        case .file(let file):
            return .standalone(file)
        case nil:
            return nil
        }
    }

    var subjectWarnings: [String] {
        guard let subject, let source = try? subject.source() else { return [] }
        return SubjectAdvisory.warnings(for: subject, source: source)
    }

    var visibleFiles: [SourceFile] {
        guard case .package(let package) = workspace else { return [] }
        let query = fileFilter.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return package.sourceFiles }
        return package.sourceFiles.filter { $0.relativePath.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Run

    private(set) var phase: Phase = .start
    private(set) var pendingRequest: GenerationRequest?
    private(set) var modelOutput = ""
    private(set) var buildLog = ""
    private(set) var generatedTest: GeneratedTest?
    private(set) var report: VerificationReport?
    private(set) var stage: VerificationStage?
    private(set) var acceptedURL: URL?
    /// Where verification happened, kept for display: people reasonably want to
    /// know where the thing they just watched being built actually lives.
    private(set) var scratchPath: String?
    /// Where the generated file was saved, always, as soon as it existed.
    private(set) var savedURL: URL?
    /// Kept beside the output rather than thrown in an alert, so a failed run
    /// leaves everything it produced on screen instead of wiping it.
    private(set) var runError: String?
    /// Reading a manifest means running SwiftPM, which isn't instant.
    private(set) var isInspecting = false

    var showingPromptPreview = false
    var showingDiff = false
    var errorMessage: String?

    var isRunning: Bool { phase == .generating || phase == .verifying }
    var canGenerate: Bool { subject != nil && blockingReason == nil && !isRunning }

    var showsRunView: Bool {
        switch phase {
        case .generating, .verifying, .finished, .failed, .accepted: true
        case .start, .ready: false
        }
    }

    var canAccept: Bool {
        guard phase == .finished, let report else { return false }
        return report.compiled
    }

    var destinationDescription: String? {
        guard let subject, let test = generatedTest else { return nil }
        return subject.destinationDescription(forTestFileNamed: test.fileName)
    }

    /// The absolute path the file would land at, or nil when you'd be asked.
    var destinationPath: String? {
        guard let subject, let test = generatedTest else { return nil }
        return subject.destination(forTestFileNamed: test.fileName)?
            .path(percentEncoded: false)
    }

    func copyTestToClipboard() {
        guard let test = generatedTest else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(test.source, forType: .string)
    }

    var diffLines: [DiffLine] {
        guard let destinationDescription, let test = generatedTest else { return [] }
        return diffRenderer.diff(test: test, destinationRelativePath: destinationDescription)
    }

    // MARK: - Collaborators

    @ObservationIgnored private let inspector = PackageInspector()
    @ObservationIgnored private let promptBuilder = PromptBuilder()
    @ObservationIgnored private let extractor = TestCodeExtractor()
    @ObservationIgnored private let sandboxBuilder = SandboxBuilder()
    @ObservationIgnored private let verifier = TestVerifier()
    @ObservationIgnored private let writer = TestFileWriter()
    @ObservationIgnored private let archive = GeneratedTestArchive()
    @ObservationIgnored private let diffRenderer = DiffRenderer()
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private var probeTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        providerKind = defaults.string(forKey: "providerKind").flatMap(ProviderKind.init) ?? .anthropic
        anthropicModel = defaults.string(forKey: "anthropicModel")
            ?? ProviderConfiguration.anthropicDefault.model
        openBaseURL = defaults.string(forKey: "openBaseURL")
            ?? ProviderConfiguration.openModelDefault.baseURL
        openModel = defaults.string(forKey: "openModel") ?? ""
        refreshCredentialStatus()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(providerKind.rawValue, forKey: "providerKind")
        defaults.set(anthropicModel, forKey: "anthropicModel")
        defaults.set(openBaseURL, forKey: "openBaseURL")
        defaults.set(openModel, forKey: "openModel")
    }

    private func onProviderChanged() {
        if providerKind == .openAICompatible { probeOpenEndpoint() }
    }

    // MARK: - Credentials

    func refreshCredentialStatus() {
        hasAnthropicKey = KeychainStore.store(for: .anthropic).hasKey()
        hasOpenModelKey = KeychainStore.store(for: .openAICompatible).hasKey()
    }

    func saveCredential(_ value: String, for kind: ProviderKind) {
        do {
            try KeychainStore.store(for: kind)
                .save(value.trimmingCharacters(in: .whitespacesAndNewlines))
            refreshCredentialStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeCredential(for kind: ProviderKind) {
        do {
            try KeychainStore.store(for: kind).delete()
            refreshCredentialStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Open-model endpoint

    func useRuntime(_ runtime: LocalRuntime) {
        openBaseURL = runtime.baseURL
        probeOpenEndpoint()
    }

    /// Asks the endpoint what it has loaded. Also doubles as the "is it running" check.
    func probeOpenEndpoint() {
        probeTask?.cancel()
        let configuration = ProviderConfiguration(
            kind: .openAICompatible,
            baseURL: openBaseURL,
            model: openModel
        )
        connection = .checking
        probeTask = Task { [self] in
            let credential = try? KeychainStore.store(for: .openAICompatible).read()
            do {
                let client = OpenAICompatibleClient(baseURL: configuration.normalizedBaseURL)
                let models = try await client.availableModels(credential: credential)
                guard !Task.isCancelled else { return }
                availableOpenModels = models
                connection = .reachable(modelCount: models.count)
                if openModel.isEmpty || !models.contains(openModel) {
                    openModel = ProviderConfiguration.preferredModel(among: models) ?? ""
                }
            } catch {
                guard !Task.isCancelled else { return }
                availableOpenModels = []
                connection = .unreachable(error.localizedDescription)
            }
        }
    }

    // MARK: - Opening a subject

    func choosePackage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Package"
        panel.message = "Choose a folder with a Package.swift at its root."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isInspecting = true
        Task { [self] in
            defer { isInspecting = false }
            do {
                let package = try await inspector.inspect(folder: url)
                workspace = .package(package)
                selectedFile = nil
                fileFilter = ""
                errorMessage = nil
                resetRun()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.swiftSource]
        panel.prompt = "Open File"
        panel.message = "Choose a Swift file. It will be built on its own, in a throwaway package."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            workspace = .file(try StandaloneFile(url: url))
            selectedFile = nil
            errorMessage = nil
            resetRun()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Opens a package given on the command line. Makes the app scriptable enough
    /// to reproduce a layout problem without someone clicking through it.
    func openFromCommandLine() {
        let candidates = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
        guard let path = candidates.first else { return }
        let url = URL(filePath: path)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }

        isInspecting = true
        Task { [self] in
            defer { isInspecting = false }
            do {
                let package = try await inspector.inspect(folder: url)
                workspace = .package(package)
                resetRun()
                if CommandLine.arguments.contains("--select-first") {
                    selectedFile = package.sourceFiles.first
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func closeWorkspace() {
        guard !isRunning else { return }
        workspace = nil
        selectedFile = nil
        resetRun()
    }

    // MARK: - Generating

    /// Assembles the request and shows it. Nothing is sent until the user confirms.
    func reviewPrompt() {
        guard let subject else { return }
        do {
            pendingRequest = try promptBuilder.build(configuration: configuration, subject: subject)
            showingPromptPreview = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendPendingRequest() {
        guard let subject, let request = pendingRequest else { return }
        showingPromptPreview = false
        modelOutput = ""
        buildLog = ""
        report = nil
        stage = nil
        generatedTest = nil
        acceptedURL = nil
        errorMessage = nil
        runError = nil
        phase = .generating

        let configuration = configuration
        runTask = Task { [self] in
            await performRun(subject: subject, request: request, configuration: configuration)
        }
    }

    func cancel() { runTask?.cancel() }

    private func performRun(
        subject: TestSubject,
        request: GenerationRequest,
        configuration: ProviderConfiguration
    ) async {
        var sandbox: Sandbox?
        do {
            let credential = try KeychainStore.store(for: configuration.kind).read()
            if configuration.requiresCredential, (credential ?? "").isEmpty {
                throw GenerationError.missingCredential(providerName: configuration.providerName)
            }

            let generator = GeneratorFactory.make(for: configuration)
            let reply = try await generator.generateTest(
                for: request,
                credential: credential
            ) { chunk in
                Task { @MainActor [self] in modelOutput += chunk }
            }
            try Task.checkCancellation()

            modelOutput = reply

            // On disk before anything is allowed to reject it. A reply that can't be
            // parsed is still kept, as text, rather than thrown away.
            let test: GeneratedTest
            do {
                test = try extractor.extract(from: reply, subjectBaseName: request.subjectBaseName)
            } catch {
                savedURL = try? archive.saveUnusable(reply, for: subject, reason: .unparsed)
                throw error
            }

            generatedTest = test
            modelOutput = test.source
            do {
                savedURL = try archive.save(test, for: subject)
            } catch {
                runError = "Generated the test but couldn't save it: \(error.localizedDescription)"
            }

            // Checked before building, not after: verifying against a sandbox where
            // a human's test had been shadowed would be a meaningless green tick.
            if let destination = subject.destination(forTestFileNamed: test.fileName),
               writer.exists(at: destination) {
                throw WriteError.destinationExists(
                    path: subject.destinationDescription(forTestFileNamed: test.fileName)
                )
            }

            phase = .verifying

            let scratch = try sandboxBuilder.make(for: subject, generatedTest: test)
            sandbox = scratch
            scratchPath = scratch.packageRoot.path(percentEncoded: false)
            buildLog = "Scratch copy at \(scratch.packageRoot.path(percentEncoded: false))\n\n"

            report = try await verifier.verify(
                sandbox: scratch,
                test: test,
                onStage: { next in Task { @MainActor [self] in stage = next } },
                onOutput: { chunk in Task { @MainActor [self] in buildLog += chunk } }
            )
            phase = .finished
        } catch is CancellationError {
            buildLog += "\n— cancelled —\n"
            keepWhateverArrived(for: subject)
            runError = "Cancelled. Anything already generated is saved; nothing was added to your test target."
            phase = .failed
        } catch {
            // Stays on screen next to whatever was generated, which is usually the
            // most useful thing to look at when something goes wrong.
            keepWhateverArrived(for: subject)
            runError = error.localizedDescription
            phase = .failed
        }

        stage = nil
        if let sandbox { sandboxBuilder.destroy(sandbox) }
        runTask = nil
    }

    /// A run that stopped early still produced something. Keep it.
    private func keepWhateverArrived(for subject: TestSubject) {
        guard savedURL == nil else { return }
        let text = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        savedURL = try? archive.saveUnusable(modelOutput, for: subject, reason: .partial)
    }

    // MARK: - Accepting

    func acceptTest() {
        guard let subject, let test = generatedTest else { return }
        showingDiff = false

        switch subject.destination(forTestFileNamed: test.fileName) {
        case .some(let destination):
            // Package mode picks the path itself, so it must never clobber.
            do {
                try writer.write(test, to: destination)
                acceptedURL = destination
                phase = .accepted
            } catch {
                errorMessage = error.localizedDescription
            }
        case nil:
            // Standalone mode: the user names the path, so the save panel's own
            // replace confirmation is the decision.
            guard case .file(let file) = workspace else { return }
            let panel = NSSavePanel()
            panel.nameFieldStringValue = test.fileName
            panel.directoryURL = file.directory
            panel.allowedContentTypes = [.swiftSource]
            panel.message = "Save the generated test."
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                try test.source.write(to: url, atomically: true, encoding: .utf8)
                acceptedURL = url
                phase = .accepted
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func revealAcceptedFile() {
        guard let url = acceptedURL ?? savedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revealSavedFile() {
        guard let savedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([savedURL])
    }

    // MARK: - Reset

    func resetRun() {
        guard !isRunning else { return }
        modelOutput = ""
        buildLog = ""
        report = nil
        stage = nil
        generatedTest = nil
        pendingRequest = nil
        acceptedURL = nil
        runError = nil
        savedURL = nil
        scratchPath = nil
        phase = workspace == nil ? .start : .ready
    }
}
