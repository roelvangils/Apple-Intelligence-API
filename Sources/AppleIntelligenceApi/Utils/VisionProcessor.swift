import Foundation
import Vision
import AppKit

enum VisionError: Error {
    case invalidImageData
    case ocrFailed(String)
    case imageLoadFailed
}

class VisionProcessor {

    /// Performs OCR on image data and returns extracted text
    static func extractText(from imageData: Data) async throws -> String {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImageData
        }

        return try await extractText(from: cgImage)
    }

    /// Performs OCR on a CGImage and returns extracted text
    static func extractText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: VisionError.ocrFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let extractedText = observations
                    .compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    .joined(separator: "\n")

                continuation.resume(returning: extractedText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VisionError.ocrFailed(error.localizedDescription))
            }
        }
    }

    /// Loads image from URL and performs OCR
    static func extractText(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try await extractText(from: data)
    }

    /// Loads image from base64 string and performs OCR
    static func extractText(fromBase64 base64String: String) async throws -> String {
        // Remove data URL prefix if present (e.g., "data:image/png;base64,")
        let cleanedBase64 = base64String
            .replacingOccurrences(of: "data:image/[^;]+;base64,", with: "", options: .regularExpression)

        guard let imageData = Data(base64Encoded: cleanedBase64) else {
            throw VisionError.invalidImageData
        }

        return try await extractText(from: imageData)
    }
}
