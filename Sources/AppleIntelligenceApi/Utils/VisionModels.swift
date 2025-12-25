import Vapor

/// Request content for vision analysis endpoint
struct VisionRequestContent: Content {
    /// Base64-encoded image data (with or without data URL prefix)
    var image: String?

    /// URL to fetch image from
    var image_url: String?

    /// Optional prompt to analyze the extracted text
    /// If not provided, returns raw OCR text
    var prompt: String?

    /// Model to use for text analysis (base or permissive)
    var model: String?

    /// Enable streaming response
    var stream: Bool?

    /// Generation options
    var max_tokens: Int?
    var temperature: Double?
}

/// Response for vision analysis
struct VisionResponse: Content {
    var id: String
    var object: String = "vision.analysis"
    var created: Int
    var model: String
    var extracted_text: String
    var analysis: String?
    var choices: [VisionChoice]?
}

struct VisionChoice: Content {
    var index: Int = 0
    var message: VisionMessage
    var finish_reason: String
}

struct VisionMessage: Content {
    var role: String = "assistant"
    var content: String
}

/// Simple OCR-only response
struct OCRResponse: Content {
    var id: String
    var object: String = "vision.ocr"
    var created: Int
    var text: String
}
