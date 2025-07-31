// FILE: ZSImageClassification.swift

import CoreML
import UIKit
import Combine

/// shared tokenizer for all model types
private let tokenizer = AsyncFactory {
    CLIPTokenizer()
}

// [FIXED] ZSImageClassification is now a class marked with @MainActor.
// This achieves both thread safety for its properties (like ciContext) and
// compatibility with ObservableObject for SwiftUI.
@MainActor
class ZSImageClassification: ObservableObject {

    // By being inside a @MainActor class, this property is guaranteed
    // to be accessed only on the main thread, preventing race conditions.
    private let ciContext = CIContext()
    private var model: any CLIPEncoder

    // The initializer remains the same.
    public init(model: any CLIPEncoder) {
        self.model = model
    }

    // All methods are now isolated to the MainActor because the class is.
    // Calls from background threads will be automatically marshaled to the main thread.
    func load() async {
        async let t = tokenizer.get()
        async let m: () = model.load()
        _ = await (t, m)
    }

    public func setModel(_ model: ModelConfiguration) {
        self.model = model.factory()
    }
    
    func computeTextEmbeddings(promptArr: [String]) async -> [MLMultiArray] {
        var textEmbeddings: [MLMultiArray] = []
        do {
            for singlePrompt in promptArr {
                let inputIds = await tokenizer.get().encode_full(text: singlePrompt)
                let inputArray = try MLMultiArray(shape: [1, 77], dataType: .int32)
                for (index, element) in inputIds.enumerated() {
                    inputArray[index] = NSNumber(value: element)
                }
                let output = try await model.encode(text: inputArray)
                textEmbeddings.append(output)
            }
        } catch {
            print("Error during text embedding: \(error.localizedDescription)")
        }
        return textEmbeddings
    }
    
    func computeImageEmbeddings(frame: CVPixelBuffer) async -> (
        embedding: MLMultiArray, interval: CFTimeInterval
    )? {
        var image: CIImage? = CIImage(cvPixelBuffer: frame)
        image = image?.cropToSquare()
        image = image?.resize(size: model.targetImageSize)

        guard let image else { return nil }

        let extent = image.extent
        let pixelFormat = kCVPixelFormatType_32ARGB
        var output: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(extent.width), Int(extent.height), pixelFormat, nil, &output)

        guard let output else {
            print("failed to create output CVPixelBuffer")
            return nil
        }
        
        ciContext.render(image, to: output)

        do {
            let startTimer = CACurrentMediaTime()
            let output = try await model.encode(image: output)
            let endTimer = CACurrentMediaTime()
            let interval = endTimer - startTimer
            return (embedding: output, interval: interval)
        } catch {
            print("Error during image embedding: \(error.localizedDescription)")
            return nil
        }
    }
    
    // This function can remain nonisolated as it doesn't access any class properties.
    nonisolated func cosineSimilarity(_ embedding1: MLMultiArray, _ embedding2: MLMultiArray) -> Float {
        let e1 = embedding1.withUnsafeBufferPointer(ofType: Float.self) { Array($0) }
        let e2 = embedding2.withUnsafeBufferPointer(ofType: Float.self) { Array($0) }
        let dotProduct: Float = zip(e1, e2).reduce(0.0) { $0 + $1.0 * $1.1 }
        let magnitude1: Float = sqrt(e1.reduce(0) { $0 + pow($1, 2) })
        let magnitude2: Float = sqrt(e2.reduce(0) { $0 + pow($1, 2) })
        let similarity = dotProduct / (magnitude1 * magnitude2)
        return similarity
    }
    
    public func findBestContext(for frame: CVPixelBuffer, from contexts: [String]) async -> (context: String, score: Float)? {
        // This function calls other async methods of the class, which is fine.
        // The @MainActor ensures all of this happens on the main thread.
        guard let imageEmbeddingResult = await computeImageEmbeddings(frame: frame) else {
            return nil
        }
        let imageEmbedding = imageEmbeddingResult.embedding
        
        var bestMatch: (context: String, score: Float)? = nil

        for context in contexts {
            let prompt = "A photo of a scene in a \(context)"
            
            let inputIds = await tokenizer.get().encode_full(text: prompt)
            
            guard let inputArray = try? MLMultiArray(shape: [1, 77], dataType: .int32) else {
                continue
            }
            
            for (index, element) in inputIds.enumerated() {
                inputArray[index] = NSNumber(value: element)
            }

            do {
                let textEmbedding = try await model.encode(text: inputArray)
                let similarity = cosineSimilarity(imageEmbedding, textEmbedding)
                
                print("Testing context '\(context)' -> Score: \(similarity)")
                
                if bestMatch == nil || similarity > bestMatch!.score {
                    bestMatch = (context: context, score: similarity)
                }
            } catch {
                print("Error encoding text for context '\(context)': \(error)")
                continue
            }
        }
        
        return bestMatch
    }
}
