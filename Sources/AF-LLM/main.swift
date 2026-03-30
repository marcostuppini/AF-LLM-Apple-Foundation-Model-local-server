import Vapor
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Request and Response Structures

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable, ResponseEncodable {
    let id: String
    let object: String
    let choices: [Choice]
    
    func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let jsonData = try! JSONEncoder().encode(self)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        return request.eventLoop.makeSucceededFuture(
            Response(status: .ok, body: .init(string: jsonString))
        )
    }
}

struct Choice: Codable {
    let index: Int
    let message: ChatMessageResponse
    let finish_reason: String
}

struct ChatMessageResponse: Codable {
    let role: String
    let content: String
}

// MARK: - Application Setup

func routes(_ app: Application) throws {
    app.get { req in
        return "Apple Intelligence Local Coding Backend is running"
    }
    
    app.get("healthz") { _ in
        return Response(status: .ok, body: .init(string: "{\"status\":\"ok\"}"))
    }
    
    app.post("v1", "chat", "completions") { req -> Response in
        do {
            let request = try req.content.decode(ChatCompletionRequest.self)
            
            // Extract system and user messages
            let systemMessages = request.messages.filter { $0.role == "system" }.map { $0.content }
            let userMessages = request.messages.filter { $0.role == "user" }.map { $0.content }
            
            // Format prompt according to specification
            let systemPrompt = systemMessages.joined(separator: "\n\n")
            let userPrompt = userMessages.joined(separator: "\n\n")
            let prompt = """
            \(systemPrompt)


            \(userPrompt)
            """
            
            // Generate response using available model
            let responseText: String
            
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                do {
                    let session = LanguageModelSession()
                    // Use async/await to get the response
                    let response = try await session.respond(to: prompt)
                    
                    // Extract the content from the LanguageModelSession.Response
                    responseText = response.content
                } catch {
                    responseText = "Model not available. Ensure Apple Intelligence is enabled."
                }
            } else {
                responseText = "This backend requires macOS 26.0 or later for Apple Intelligence support."
            }
            #else
            responseText = "FoundationModels framework not available. This backend requires Apple Intelligence-enabled macOS."
            #endif
            
            let trimmedResponse = responseText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            let chatResponse = ChatCompletionResponse(
                id: "chatcmpl-local",
                object: "chat.completion",
                choices: [
                    Choice(
                        index: 0,
                        message: ChatMessageResponse(role: "assistant", content: trimmedResponse),
                        finish_reason: "stop"
                    )
                ]
            )
            
            let jsonData = try JSONEncoder().encode(chatResponse)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            return Response(status: .ok, body: .init(string: jsonString))
            
        } catch {
            let errorResponse = ChatCompletionResponse(
                id: "chatcmpl-local-error",
                object: "chat.completion",
                choices: [
                    Choice(
                        index: 0,
                        message: ChatMessageResponse(role: "assistant", content: "Invalid request format"),
                        finish_reason: "stop"
                    )
                ]
            )
            
            let jsonData = try! JSONEncoder().encode(errorResponse)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            return Response(status: .badRequest, body: .init(string: jsonString))
        }
    }
}

// MARK: - Main

@main
struct App {
    static func main() async throws {
        let app = Application()
        defer { app.shutdown() }
        
        try routes(app)
        try await app.execute()
    }
}
