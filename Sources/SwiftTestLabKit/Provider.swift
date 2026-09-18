//
//  Provider.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

public enum GenerationError: LocalizedError, Sendable {
    case missingCredential(providerName: String)
    case serverUnreachable(endpoint: String, hint: String)
    case badStatus(code: Int, message: String)
    case refused(String)
    case truncated
    case emptyResponse
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .missingCredential(let providerName):
            "No API key set for \(providerName). Add one in Settings before generating."
        case .serverUnreachable(let endpoint, let hint):
            "Nothing is answering at \(endpoint). \(hint)"
        case .badStatus(let code, let message):
            "The server returned HTTP \(code): \(message)"
        case .refused(let category):
            "The model declined to answer (\(category))."
        case .truncated:
            "The response hit the output limit before the test file was complete. Try a smaller source file, or a model with more room."
        case .emptyResponse:
            "The server returned no text."
        case .transport(let reason):
            "Couldn't reach the server: \(reason)"
        }
    }
}

/// Where the test comes from. Open models are a first-class choice, not a fallback:
/// anything that speaks the OpenAI chat-completions shape works, which covers
/// Ollama, LM Studio, llama.cpp, vLLM and the hosted gateways.
public enum ProviderKind: String, Sendable, CaseIterable, Identifiable, Codable {
    case anthropic
    case openAICompatible

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openAICompatible: "Open model"
        }
    }

    public var subtitle: String {
        switch self {
        case .anthropic: "Claude, over the Messages API"
        case .openAICompatible: "Ollama, LM Studio, llama.cpp, vLLM, or any OpenAI-compatible endpoint"
        }
    }

    public var symbolName: String {
        switch self {
        case .anthropic: "cloud"
        case .openAICompatible: "desktopcomputer"
        }
    }
}

/// Endpoints worth offering by name, so nobody has to remember a port number.
public struct LocalRuntime: Sendable, Identifiable, Hashable {
    public let name: String
    public let baseURL: String
    public let startHint: String

    public var id: String { baseURL }

    public static let all: [LocalRuntime] = [
        LocalRuntime(
            name: "Ollama",
            baseURL: "http://localhost:11434/v1",
            startHint: "Start it with `ollama serve`, then pull a coding model such as qwen2.5-coder."
        ),
        LocalRuntime(
            name: "LM Studio",
            baseURL: "http://localhost:1234/v1",
            startHint: "Open LM Studio and start the local server from the Developer tab."
        ),
        LocalRuntime(
            name: "llama.cpp",
            baseURL: "http://localhost:8080/v1",
            startHint: "Start it with `llama-server -m <model.gguf>`."
        ),
        LocalRuntime(
            name: "vLLM",
            baseURL: "http://localhost:8000/v1",
            startHint: "Start it with `vllm serve <model>`."
        ),
    ]

    public static func named(matching baseURL: String) -> LocalRuntime? {
        let normalized = ProviderConfiguration.normalize(baseURL)
        return all.first { normalize($0.baseURL) == normalized }
    }

    private static func normalize(_ url: String) -> String {
        ProviderConfiguration.normalize(url)
    }
}

public struct ProviderConfiguration: Sendable, Equatable {
    public var kind: ProviderKind
    /// Only meaningful for `openAICompatible`.
    public var baseURL: String
    public var model: String

    public init(kind: ProviderKind, baseURL: String, model: String) {
        self.kind = kind
        self.baseURL = baseURL
        self.model = model
    }

    public static let anthropicDefault = ProviderConfiguration(
        kind: .anthropic,
        baseURL: "",
        model: "claude-sonnet-5"
    )

    public static let openModelDefault = ProviderConfiguration(
        kind: .openAICompatible,
        baseURL: "http://localhost:11434/v1",
        model: ""
    )

    public static let anthropicModels = ["claude-sonnet-5", "claude-opus-5", "claude-haiku-4-5"]

    public var normalizedBaseURL: String { Self.normalize(baseURL) }

    /// A local endpoint needs no key and costs nothing, which changes what the UI
    /// should be asking for.
    public var isLocal: Bool {
        guard kind == .openAICompatible, let host = URL(string: normalizedBaseURL)?.host() else {
            return false
        }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".local")
    }

    public var requiresCredential: Bool {
        switch kind {
        case .anthropic: true
        case .openAICompatible: !isLocal
        }
    }

    public var providerName: String {
        switch kind {
        case .anthropic: "Anthropic"
        case .openAICompatible: LocalRuntime.named(matching: baseURL)?.name ?? "this endpoint"
        }
    }

    public var endpointDescription: String {
        switch kind {
        case .anthropic: "https://api.anthropic.com/v1/messages"
        case .openAICompatible: normalizedBaseURL + "/chat/completions"
        }
    }

    public var isReadyToSend: Bool {
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch kind {
        case .anthropic: return true
        case .openAICompatible: return URL(string: normalizedBaseURL)?.host() != nil
        }
    }

    /// Writing Swift is a coding task, so a coding-tuned model is a better first
    /// guess than whatever happens to be listed first.
    public static func preferredModel(among models: [String]) -> String? {
        let hints = ["coder", "codestral", "devstral", "starcoder", "code", "qwen"]
        for hint in hints {
            if let match = models.first(where: { $0.localizedCaseInsensitiveContains(hint) }) {
                return match
            }
        }
        return models.first
    }

    static func normalize(_ url: String) -> String {
        var trimmed = url.trimmingCharacters(in: .whitespaces)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed
    }
}

/// Anything that can turn a prompt into a test file.
public protocol TestGenerating: Sendable {
    func generateTest(
        for request: GenerationRequest,
        credential: String?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String
}

public enum GeneratorFactory {
    public static func make(for configuration: ProviderConfiguration) -> TestGenerating {
        switch configuration.kind {
        case .anthropic:
            AnthropicClient()
        case .openAICompatible:
            OpenAICompatibleClient(baseURL: configuration.normalizedBaseURL)
        }
    }
}

// MARK: - Shared server-sent event reading

enum ServerSentEvents {
    /// Yields the payload of each `data:` line, skipping keep-alives and `[DONE]`.
    static func payloads(
        from bytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst("data:".count)
                            .trimmingCharacters(in: .whitespaces)
                        guard !payload.isEmpty, payload != "[DONE]" else { continue }
                        continuation.yield(payload)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Reads an error body. Never touches request headers, so a key can't leak here.
    static func errorMessage(from bytes: URLSession.AsyncBytes) async -> String {
        var collected: [String] = []
        do {
            for try await line in bytes.lines { collected.append(line) }
        } catch {
            // Whatever arrived is enough; the status code carries the meaning.
        }
        let body = collected.joined(separator: "\n")
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return body.isEmpty ? "no details returned" : String(body.prefix(500))
        }
        if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        if let message = object["error"] as? String { return message }
        return String(body.prefix(500))
    }

    static func session(timeout: TimeInterval = 300) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = 1_800
        return URLSession(configuration: configuration)
    }
}
