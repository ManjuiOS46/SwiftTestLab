import Testing
@testable import SwiftTestLab

@Suite struct AppModelTests {
    
    @Test func initializesWithDefaultValues() {
        let model = AppModel()
        
        #expect(model.providerKind == .anthropic)
        #expect(model.anthropicModel == ProviderConfiguration.anthropicDefault.model)
        #expect(model.openBaseURL == ProviderConfiguration.openModelDefault.baseURL)
        #expect(model.openModel == "")
        #expect(model.availableOpenModels == [])
        #expect(model.connection == .unknown)
        #expect(model.hasAnthropicKey == false)
        #expect(model.hasOpenModelKey == false)
    }
    
    @Test func persistsProviderKind() {
        let model = AppModel()
        
        // Simulate persistence by directly accessing UserDefaults
        let defaults = UserDefaults.standard
        defaults.set("anthropic", forKey: "providerKind")
        
        // Reinitialize to verify persisted value
        let reinitModel = AppModel()
        #expect(reinitModel.providerKind == .anthropic)
    }
    
    @Test func configurationReturnsCorrectProviderConfigurationForAnthropic() {
        let model = AppModel()
        model.providerKind = .anthropic
        model.anthropicModel = "claude-3-opus"
        
        let config = model.configuration
        
        #expect(config.kind == .anthropic)
        #expect(config.model == "claude-3-opus")
        #expect(config.baseURL == "")
    }
    
    @Test func configurationReturnsCorrectProviderConfigurationForOpenAICompatible() {
        let model = AppModel()
        model.providerKind = .openAICompatible
        model.openBaseURL = "https://api.openai.com/v1"
        model.openModel = "gpt-4"
        
        let config = model.configuration
        
        #expect(config.kind == .openAICompatible)
        #expect(config.baseURL == "https://api.openai.com/v1")
        #expect(config.model == "gpt-4")
    }
    
    @Test func blockingReasonReturnsNilWhenReady() {
        let model = AppModel()
        model.providerKind = .anthropic
        model.hasAnthropicKey = true
        
        // Mocking this with a fake implementation to avoid dependency on actual KeychainStore
        let fakeKeychainStore = FakeKeychainStore(hasKey: true)
        KeychainStore.mockStore = fakeKeychainStore
        
        #expect(model.blockingReason == nil)
    }
    
    @Test func blockingReasonReturnsMissingApiKeyMessage() {
        let model = AppModel()
        model.providerKind = .anthropic
        model.hasAnthropicKey = false
        
        #expect(model.blockingReason == "No API key set for Anthropic.")
    }
    
    @Test func blockingReasonReturnsNoModelChosenForAnthropic() {
        let model = AppModel()
        model.providerKind = .anthropic
        model.hasAnthropicKey = true
        model.anthropicModel = ""
        
        #expect(model.blockingReason == "No model chosen.")
    }
    
    @Test func blockingReasonReturnsNoModelChosenForOpenAICompatible() {
        let model = AppModel()
        model.providerKind = .openAICompatible
        model.hasOpenModelKey = true
        model.openModel = ""
        
        #expect(model.blockingReason == "No model chosen — pick one from the endpoint in Settings.")
    }
    
    @Test func blockingReasonReturnsUnusableEndpoint() {
        let model = AppModel()
        model.providerKind = .openAICompatible
        model.hasOpenModelKey = true
        model.openModel = "gpt-4"
        model.openBaseURL = "" // Invalid URL
        
        #expect(model.blockingReason == "https:// isn't a usable endpoint.")
    }
    
    @Test func canGenerateReturnsTrueWhenSubjectExistsAndNoBlockingReason() {
        let model = AppModel()
        model.workspace = .file(StandaloneFile(url: URL(fileURLWithPath: "/test.swift")))
        
        #expect(model.canGenerate == true)
    }
    
    @Test func canGenerateReturnsFalseWhenIsRunning() {
        let model = AppModel()
        model.phase = .generating
        model.workspace = .file(StandaloneFile(url: URL(fileURLWithPath: "/test.swift")))
        
        #expect(model.canGenerate == false)
    }
    
    @Test func canAcceptReturnsTrueWhenPhaseIsFinishedAndReportExists() {
        let model = AppModel()
        model.phase = .finished
        model.report = VerificationReport(compiled: true, errors: [])
        
        #expect(model.canAccept == true)
    }
    
    @Test func canAcceptReturnsFalseWhenPhaseIsNotFinished() {
        let model = AppModel()
        model.phase = .generating
        
        #expect(model.canAccept == false)
    }
    
    @Test func canAcceptReturnsFalseWhenReportDoesNotExist() {
        let model = AppModel()
        model.phase = .finished
        model.report = nil
        
        #expect(model.canAccept == false)
    }
    
    @Test func canAcceptReturnsFalseWhenReportIsNotCompiled() {
        let model = AppModel()
        model.phase = .finished
        model.report = VerificationReport(compiled: false, errors: [])
        
        #expect(model.canAccept == false)
    }
    
    @Test func resetRunSetsCorrectPhaseWhenWorkspaceIsNil() {
        let model = AppModel()
        model.phase = .generating
        
        model.resetRun()
        
        #expect(model.phase == .start)
    }
    
    @Test func resetRunSetsCorrectPhaseWhenWorkspaceExists() {
        let model = AppModel()
        model.workspace = .file(StandaloneFile(url: URL(fileURLWithPath: "/test.swift")))
        model.phase = .generating
        
        model.resetRun()
        
        #expect(model.phase == .ready)
    }
}

private final class FakeKeychainStore: KeychainStoreType {
    let hasKey: Bool
    
    init(hasKey: Bool) {
        self.hasKey = hasKey
    }
    
    func hasKey() -> Bool {
        return hasKey
    }
    
    func save(_ value: String) throws {
        // Stub implementation
    }
    
    func read() throws -> String? {
        return "fake-key"
    }
    
    func delete() throws {
        // Stub implementation
    }
}
