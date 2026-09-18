//
//  ProviderTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct ProviderTests {
    @Test(arguments: [
        "http://localhost:11434/v1",
        "http://127.0.0.1:1234/v1",
        "http://mac-studio.local:8080/v1",
    ])
    func localEndpointsNeedNoKey(baseURL: String) {
        let configuration = ProviderConfiguration(
            kind: .openAICompatible,
            baseURL: baseURL,
            model: "qwen2.5-coder"
        )
        #expect(configuration.isLocal)
        #expect(!configuration.requiresCredential)
    }

    @Test func remoteOpenEndpointsStillNeedAKey() {
        let configuration = ProviderConfiguration(
            kind: .openAICompatible,
            baseURL: "https://openrouter.ai/api/v1",
            model: "qwen/qwen-2.5-coder-32b"
        )
        #expect(!configuration.isLocal)
        #expect(configuration.requiresCredential)
    }

    @Test func anthropicAlwaysNeedsAKey() {
        #expect(ProviderConfiguration.anthropicDefault.requiresCredential)
        #expect(!ProviderConfiguration.anthropicDefault.isLocal)
    }

    @Test func trailingSlashesDoNotProduceDoubledPaths() {
        let configuration = ProviderConfiguration(
            kind: .openAICompatible,
            baseURL: "http://localhost:11434/v1/",
            model: "x"
        )
        #expect(configuration.endpointDescription == "http://localhost:11434/v1/chat/completions")
    }

    @Test func aMissingModelStopsTheRunBeforeItStarts() {
        var configuration = ProviderConfiguration.openModelDefault
        #expect(!configuration.isReadyToSend)
        configuration.model = "qwen2.5-coder"
        #expect(configuration.isReadyToSend)
    }

    @Test func nonsenseEndpointsAreNotReadyToSend() {
        let configuration = ProviderConfiguration(
            kind: .openAICompatible,
            baseURL: "not a url",
            model: "x"
        )
        #expect(!configuration.isReadyToSend)
    }

    @Test func knownRuntimesAreRecognisedByURL() {
        #expect(LocalRuntime.named(matching: "http://localhost:11434/v1")?.name == "Ollama")
        #expect(LocalRuntime.named(matching: "http://localhost:1234/v1/")?.name == "LM Studio")
        #expect(LocalRuntime.named(matching: "https://example.com/v1") == nil)
    }

    @Test func aCodingModelIsPreferredOverWhateverIsListedFirst() {
        #expect(
            ProviderConfiguration.preferredModel(
                among: ["llama3.2:latest", "qwen2.5-coder:7b", "mistral:latest"]
            ) == "qwen2.5-coder:7b"
        )
    }

    @Test func fallsBackToTheFirstModelWhenNoneLookLikeCodingModels() {
        #expect(ProviderConfiguration.preferredModel(among: ["llama3.2", "mistral"]) == "llama3.2")
        #expect(ProviderConfiguration.preferredModel(among: []) == nil)
    }
}
