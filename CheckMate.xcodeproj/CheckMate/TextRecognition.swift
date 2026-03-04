import Vision
import UIKit

struct RecognizedTextRegion: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
}

struct TextRecognition {
    static func recognizeText(in image: UIImage, completion: @escaping ([RecognizedTextRegion]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion([])
                return
            }

            let recognizedRegions = observations.compactMap { observation -> RecognizedTextRegion? in
                guard let candidate = observation.topCandidates(1).first else { return nil }

                let boundingBox = observation.boundingBox  
                return RecognizedTextRegion(text: candidate.string, boundingBox: boundingBox)
            }

            completion(recognizedRegions)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion([])
            }
        }
    }
}

