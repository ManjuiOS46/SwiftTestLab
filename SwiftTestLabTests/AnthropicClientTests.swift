import Testing
@testable import Subject

@Suite struct AnthropicClientTests {
    @Test func generateTest_happyPath() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        var deltaCalls: [String] = []
        let responseText = "Hello, world!"
        
        fakeSession.nextResponse = .success(
            TestResponse(
                statusCode: 200,
                body: [
                    """
                    event: content_block_start
                    data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                    \n\n
                    """,
                    """
                    event: content_block_delta
                    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello, "}}
                    \n\n
                    """,
                    """
                    event: content_block_delta
                    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"world!"}}
                    \n\n
                    """,
                    """
                    event: message_delta
                    data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}
                    \n\n
                    """
                ].joined().data(using: .utf8)!
            )
        )

        let result = try await client.generateTest(
            for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
            credential: "test-key",
            onDelta: { chunk in deltaCalls.append(chunk) }
        )

        #expect(result == responseText)
        #expect(deltaCalls == ["Hello, ", "world!"])
        #expect(fakeSession.lastRequest?.url == AnthropicClient.endpoint)
        #expect(fakeSession.lastRequest?.httpMethod == "POST")
        #expect(fakeSession.lastRequest?.allHTTPHeaderFields?["x-api-key"] == "test-key")
    }

    @Test func generateTest_missingCredential() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        await #expect(throws: GenerationError.missingCredential(providerName: "Anthropic")) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: nil,
                onDelta: { _ in }
            )
        }
    }

    @Test func generateTest_emptyCredential() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        await #expect(throws: GenerationError.missingCredential(providerName: "Anthropic")) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: "",
                onDelta: { _ in }
            )
        }
    }

    @Test func generateTest_non200Status() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        fakeSession.nextResponse = .success(
            TestResponse(statusCode: 401, body: "Unauthorized".data(using: .utf8)!)
        )

        await #expect(throws: GenerationError.badStatus(code: 401, message: "Unauthorized")) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: "test-key",
                onDelta: { _ in }
            )
        }
    }

    @Test func generateTest_emptyResponse() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        fakeSession.nextResponse = .success(
            TestResponse(
                statusCode: 200,
                body: """
                    event: content_block_start
                    data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                    \n\n
                    event: message_delta
                    data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}
                    \n\n
                """.data(using: .utf8)!
            )
        )

        await #expect(throws: GenerationError.emptyResponse) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: "test-key",
                onDelta: { _ in }
            )
        }
    }

    @Test func generateTest_refused() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        fakeSession.nextResponse = .success(
            TestResponse(
                statusCode: 200,
                body: """
                    event: content_block_start
                    data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                    \n\n
                    event: message_delta
                    data: {"type":"message_delta","delta":{"stop_reason":"refusal","stop_details":{"category":"harmful_content"}}}
                    \n\n
                """.data(using: .utf8)!
            )
        )

        await #expect(throws: GenerationError.refused("harmful_content")) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: "test-key",
                onDelta: { _ in }
            )
        }
    }

    @Test func generateTest_truncated() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        fakeSession.nextResponse = .success(
            TestResponse(
                statusCode: 200,
                body: """
                    event: content_block_start
                    data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                    \n\n
                    event: message_delta
                    data: {"type":"message_delta","delta":{"stop_reason":"max_tokens"}}
                    \n\n
                """.data(using: .utf8)!
            )
        )

        await #expect(throws: GenerationError.truncated) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: "test-key",
                onDelta: { _ in }
            )
        }
    }

    @Test func generateTest_streamError() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        fakeSession.nextResponse = .success(
            TestResponse(
                statusCode: 200,
                body: """
                    event: content_block_start
                    data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                    \n\n
                    event: error
                    data: {"type":"error","error":{"type":"api_error","message":"Something went wrong"}}
                    \n\n
                """.data(using: .utf8)!
            )
        )

        await #expect(throws: GenerationError.badStatus(code: 200, message: "Something went wrong")) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: "test-key",
                onDelta: { _ in }
            )
        }
    }

    @Test func generateTest_cancellation() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        fakeSession.nextResponse = .failure(CancellationError())
        
        await #expect(throws: CancellationError.self) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: "test-key",
                onDelta: { _ in }
            )
        }
    }

    @Test func generateTest_transportError() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        fakeSession.nextResponse = .failure(URLError(.badServerResponse))
        
        await #expect(throws: GenerationError.transport("The operation couldn’t be completed. (NSURLErrorDomain error -1011.)")) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: "test-key",
                onDelta: { _ in }
            )
        }
    }

    @Test func generateTest_unexpectedResponseType() async throws {
        let fakeSession = FakeURLSession()
        let client = AnthropicClient(session: fakeSession)
        
        fakeSession.nextResponse = .success(TestResponse(statusCode: 200, body: Data()))
        
        await #expect(throws: GenerationError.transport("Unexpected response type.")) {
            try await client.generateTest(
                for: GenerationRequest(model: "claude-3-haiku", systemPrompt: "System", userMessage: "User"),
                credential: "test-key",
                onDelta: { _ in }
            )
        }
    }
}

private struct GenerationRequest: Codable {
    let model: String
    let systemPrompt: String
    let userMessage: String
}

private enum GenerationError: Error, Equatable {
    case missingCredential(providerName: String)
    case transport(String)
    case badStatus(code: Int, message: String)
    case refused(String)
    case truncated
    case emptyResponse
}

private protocol TestGenerating {
    func generateTest(
        for request: GenerationRequest,
        credential: String?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String
}

private struct TestResponse: HTTPURLResponse {
    let statusCode: Int
    let body: Data
    var url: URL?
    var allHeaderFields: [String : String] = [:]
    var httpVersion: String?
    var httpShouldHandleCookies: Bool = false
    var httpHeaderFields: [String : String]? = nil
    
    func makeBodyIterator() -> UnsafeMutableBufferPointer<UInt8> {
        let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: body.count)
        body.copyBytes(to: buffer)
        return buffer
    }
}

private final class FakeURLSession: URLSessionProtocol {
    var nextResponse: Result<TestResponse, Error> = .success(TestResponse(statusCode: 200, body: Data()))
    var lastRequest: URLRequest?
    
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        lastRequest = request
        switch nextResponse {
        case .success(let response):
            return (URLSession.AsyncBytes(buffer: response.body), response)
        case .failure(let error):
            throw error
        }
    }
}

// These stubs are needed because the actual implementations might not be available
extension ServerSentEvents {
    static func session() -> URLSessionProtocol { FakeURLSession() }
    
    static func errorMessage(from bytes: URLSession.AsyncBytes) async -> String {
        return "error message"
    }
    
    static func payloads(from bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<ByteBuffer, Error> {
        // Mock to make the test compile
        return AsyncThrowingStream { _ in }
    }
}

private struct ByteBuffer: Equatable, Sendable {
    let data: Data
}

// A minimal protocol to avoid depending on external frameworks
protocol URLSessionProtocol {
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse)
}
