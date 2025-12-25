import Vapor
import Foundation

func routes(_ app: Application) throws {
    app.group("api", "v1") { api in
        // Chat completions endpoint
        api.post("chat", "completions") { req async throws -> Response in
            if req.headers.contentType == nil {
                req.headers.contentType = .json
            }

            let requestContent = try req.content.decode(RequestContent.self)
            let responseSession = try ResponseSession(from: requestContent)
            let responseGenerator = createResponseGenerator(from: responseSession)
            return try await responseGenerator.generateResponse()
        }

        // Models list endpoint
        api.get("models") { req async throws -> ModelsResponse in
            let models = [
                Model(id: "base"),
                Model(id: "permissive"),
                Model(id: "vision-base"),
                Model(id: "vision-permissive"),
            ]
            return ModelsResponse(data: models)
        }

        // Vision: OCR-only endpoint (just extract text)
        api.post("vision", "ocr") { req async throws -> OCRResponse in
            let visionRequest = try req.content.decode(VisionRequestContent.self)

            let extractedText: String
            if let base64Image = visionRequest.image {
                extractedText = try await VisionProcessor.extractText(fromBase64: base64Image)
            } else if let imageUrlString = visionRequest.image_url,
                      let imageUrl = URL(string: imageUrlString) {
                extractedText = try await VisionProcessor.extractText(from: imageUrl)
            } else {
                throw Abort(.badRequest, reason: "Either 'image' (base64) or 'image_url' must be provided")
            }

            return OCRResponse(
                id: "ocr-\(UUID().uuidString)",
                created: Int(Date().timeIntervalSince1970),
                text: extractedText
            )
        }

        // Vision: Analyze endpoint (OCR + LLM analysis)
        api.post("vision", "analyze") { req async throws -> Response in
            if req.headers.contentType == nil {
                req.headers.contentType = .json
            }

            let visionRequest = try req.content.decode(VisionRequestContent.self)

            // Step 1: Extract text from image using Vision framework
            let extractedText: String
            if let base64Image = visionRequest.image {
                extractedText = try await VisionProcessor.extractText(fromBase64: base64Image)
            } else if let imageUrlString = visionRequest.image_url,
                      let imageUrl = URL(string: imageUrlString) {
                extractedText = try await VisionProcessor.extractText(from: imageUrl)
            } else {
                throw Abort(.badRequest, reason: "Either 'image' (base64) or 'image_url' must be provided")
            }

            // Step 2: If no prompt provided, return just the OCR result
            guard let userPrompt = visionRequest.prompt, !userPrompt.isEmpty else {
                let response = VisionResponse(
                    id: "vision-\(UUID().uuidString)",
                    created: Int(Date().timeIntervalSince1970),
                    model: visionRequest.model ?? "base",
                    extracted_text: extractedText,
                    analysis: nil,
                    choices: [
                        VisionChoice(
                            message: VisionMessage(content: extractedText),
                            finish_reason: "stop"
                        )
                    ]
                )
                return try await response.encodeResponse(for: req)
            }

            // Step 3: Combine OCR text with user prompt and send to LLM
            let combinedPrompt = """
            The following text was extracted from an image using OCR:

            ---
            \(extractedText)
            ---

            User request: \(userPrompt)
            """

            // Create a chat request to the LLM
            let chatRequest = RequestContent(
                messages: [Message(role: "user", content: combinedPrompt)],
                model: visionRequest.model,
                stream: visionRequest.stream,
                max_tokens: visionRequest.max_tokens,
                temperature: visionRequest.temperature
            )

            let responseSession = try ResponseSession(from: chatRequest)
            let responseGenerator = createResponseGenerator(from: responseSession)
            return try await responseGenerator.generateResponse()
        }
    }
}
