//
//  OpenAICompatibleClient.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

/// Talks to anything that speaks OpenAI's chat-completions shape: Ollama, LM Studio,
/// llama.cpp's server, vLLM, and the hosted gateways.
///
/// Local endpoints need no credential and cost nothing to run, which is the point
/// of having this alongside the hosted path.
public struct OpenAICompatibleClient: TestGenerating {
    private let baseURL: String
    private let session: URLSession

    public init(baseURL: String, session: URLSession? = nil) {
        self.baseURL = ProviderConfiguration.normalize(baseURL)
        // Local models can be slow to first token on a cold load.
        self.session = session ?? ServerSentEvents.session(timeout: 600)
    }

    public func generateTest(
        for request: GenerationRequest,
        credential: String?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard let url = URL(string: baseURL + "/chat/completions") else {
            throw GenerationError.transport("\(baseURL) isn't a usable URL.")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        if let credential, !credential.isEmpty {
            urlRequest.setValue("Bearer \(credential)", forHTTPHeaderField: "authorization")
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": request.model,
            "stream": true,
            "messages": [
                ["role": "system", "content": request.systemPrompt],
                ["role": "user", "content": request.userMessage],
            ],
        ])

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Self.connectionError(error, endpoint: url.absoluteString, baseURL: baseURL)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GenerationError.transport("Unexpected response type.")
        }
        guard http.statusCode == 200 else {
            throw GenerationError.badStatus(
                code: http.statusCode,
                message: await ServerSentEvents.errorMessage(from: bytes)
            )
        }

        var text = ""
        var finishReason: String?
        let decoder = JSONDecoder()

        for try await payload in ServerSentEvents.payloads(from: bytes) {
            guard let data = payload.data(using: .utf8),
                  let chunk = try? decoder.decode(Chunk.self, from: data),
                  let choice = chunk.choices.first else { continue }

            if let content = choice.delta?.content, !content.isEmpty {
                text += content
                onDelta(content)
            }
            // Reasoning models put their scratchpad in a separate field; it is
            // deliberately not part of the file.
            if let reason = choice.finish_reason { finishReason = reason }
        }

        if finishReason == "length" {
            throw GenerationError.truncated
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GenerationError.emptyResponse
        }
        return text
    }

    /// Asks the endpoint what it has loaded, so the model picker isn't a text field.
    public func availableModels(credential: String?) async throws -> [String] {
        guard let url = URL(string: baseURL + "/models") else {
            throw GenerationError.transport("\(baseURL) isn't a usable URL.")
        }
        var urlRequest = URLRequest(url: url)
        if let credential, !credential.isEmpty {
            urlRequest.setValue("Bearer \(credential)", forHTTPHeaderField: "authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw Self.connectionError(error, endpoint: url.absoluteString, baseURL: baseURL)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GenerationError.badStatus(code: code, message: "couldn't list models")
        }
        let list = try JSONDecoder().decode(ModelList.self, from: data)
        return list.data.map(\.id).sorted()
    }

    private static func connectionError(
        _ error: Error,
        endpoint: String,
        baseURL: String
    ) -> GenerationError {
        let code = (error as? URLError)?.code
        guard code == .cannotConnectToHost || code == .cannotFindHost
                || code == .networkConnectionLost || code == .timedOut else {
            return .transport(error.localizedDescription)
        }
        let hint = LocalRuntime.named(matching: baseURL)?.startHint
            ?? "Check that the server is running and that the base URL is right."
        return .serverUnreachable(endpoint: endpoint, hint: hint)
    }

    // MARK: - Wire shapes

    private struct Chunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta?
            let finish_reason: String?
        }
        let choices: [Choice]
    }

    private struct ModelList: Decodable {
        struct Entry: Decodable { let id: String }
        let data: [Entry]
    }
}
