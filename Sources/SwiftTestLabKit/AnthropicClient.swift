//
//  AnthropicClient.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

/// A direct client for the Anthropic Messages API. Streams the response so the
/// test file appears as it is written rather than after a long silence.
///
/// The API key is passed in per call and held only in a local. It is never stored
/// on this type, never logged, and never placed in an error.
public struct AnthropicClient: TestGenerating {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    private let session: URLSession

    public init(session: URLSession? = nil) {
        self.session = session ?? ServerSentEvents.session()
    }

    public func generateTest(
        for request: GenerationRequest,
        credential: String?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let apiKey = (credential ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw GenerationError.missingCredential(providerName: "Anthropic")
        }

        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": request.model,
            "max_tokens": 32_000,
            "stream": true,
            "thinking": ["type": "adaptive"],
            "system": request.systemPrompt,
            "messages": [["role": "user", "content": request.userMessage]],
        ])

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw GenerationError.transport(error.localizedDescription)
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
        var stopReason: String?
        var refusalCategory: String?
        var textBlockIndices: Set<Int> = []

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        for try await payload in ServerSentEvents.payloads(from: bytes) {
            guard let data = payload.data(using: .utf8),
                  let event = try? decoder.decode(StreamEvent.self, from: data) else { continue }

            switch event.type {
            case "content_block_start":
                // Thinking blocks stream too; only text blocks are the test file.
                if event.contentBlock?.type == "text", let index = event.index {
                    textBlockIndices.insert(index)
                }
            case "content_block_delta":
                guard event.delta?.type == "text_delta",
                      let index = event.index, textBlockIndices.contains(index),
                      let chunk = event.delta?.text else { continue }
                text += chunk
                onDelta(chunk)
            case "message_delta":
                stopReason = event.delta?.stopReason
                refusalCategory = event.delta?.stopDetails?.category
            case "error":
                throw GenerationError.badStatus(
                    code: http.statusCode,
                    message: event.error?.message ?? "stream error"
                )
            default:
                continue
            }
        }

        if stopReason == "refusal" {
            throw GenerationError.refused(refusalCategory ?? "no category given")
        }
        if stopReason == "max_tokens" {
            throw GenerationError.truncated
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GenerationError.emptyResponse
        }
        return text
    }

    // MARK: - Server-sent event shapes

    private struct StreamEvent: Decodable {
        struct Block: Decodable { let type: String? }
        struct StopDetails: Decodable { let category: String? }
        struct Delta: Decodable {
            let type: String?
            let text: String?
            let stopReason: String?
            let stopDetails: StopDetails?
        }
        struct APIError: Decodable { let type: String?; let message: String? }

        let type: String
        let index: Int?
        let contentBlock: Block?
        let delta: Delta?
        let error: APIError?
    }
}
