//
//  Models.swift
//  MomentStudio
//
//  Created by SSUM on 7/28/25.
//
//  PURPOSE: Defines the protocol for CLIP models and configures the specific
//           S2 model used throughout the application in a crash-safe way.
//

import CoreML
import Foundation
import UIKit // For CGSize

// MARK: - CLIPEncoder Protocol

/// An abstract protocol that all CLIP model encoders must conform to.
protocol CLIPEncoder {
    /// The target image size that the model expects (e.g., 256x256).
    var targetImageSize: CGSize { get }

    /// Asynchronously loads the Core ML models into memory.
    func load() async

    /// Encodes a pixel buffer into a feature vector (embedding).
    func encode(image: CVPixelBuffer) async throws -> MLMultiArray

    /// Encodes a tokenized text array into a feature vector (embedding).
    func encode(text: MLMultiArray) async throws -> MLMultiArray
}

// MARK: - ModelConfiguration

/// A struct to hold the configuration for a specific CLIP model.
public struct ModelConfiguration: Identifiable, Hashable {
    public let name: String
    let factory: () -> CLIPEncoder
    public var id: String { name }

    public static func == (lhs: ModelConfiguration, rhs: ModelConfiguration) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}


// MARK: - S2 Model Implementation (The Only Model Used)

/// The single, default model configuration for the entire app, using MobileCLIP-S2.
public let defaultModel = ModelConfiguration(name: "MobileCLIP-S2", factory: { S2Model() })

/// A custom error type for model-related failures.
enum ModelError: Error {
    case notLoaded(String)
}

/// Implements the CLIPEncoder protocol for the MobileCLIP-S2 model.
public struct S2Model: CLIPEncoder {

    // MARK: - Properties
    
    // Models are stored as optionals to handle initialization failures gracefully.
    private let imageEncoder: mobileclip_s2_image?
    private let textEncoder: mobileclip_s2_text?
    
    // MARK: - Initialization
    
    init() {
        // Attempt to load the models during initialization.
        // If loading fails, print an error instead of crashing the app.
        do {
            self.imageEncoder = try mobileclip_s2_image()
        } catch {
            print("‼️ MODEL LOAD FAILED: Could not initialize mobileclip_s2_image model. Error: \(error)")
            self.imageEncoder = nil
        }
        
        do {
            self.textEncoder = try mobileclip_s2_text()
        } catch {
            print("‼️ MODEL LOAD FAILED: Could not initialize mobileclip_s2_text model. Error: \(error)")
            self.textEncoder = nil
        }
    }

    // MARK: - CLIPEncoder Conformance

    /// This function is kept for protocol conformance but the main loading
    /// is now handled in the initializer.
    func load() async {
        // The models are already loaded or failed to load in init().
        // This function can be used for any additional async setup if needed in the future.
    }

    /// The required input image size for the S2 model.
    let targetImageSize = CGSize(width: 256, height: 256)

    /// Generates an embedding from a CVPixelBuffer using the image model.
    func encode(image: CVPixelBuffer) async throws -> MLMultiArray {
        // Safely unwrap the optional model. If it's nil, throw a specific error.
        guard let imageEncoder = self.imageEncoder else {
            throw ModelError.notLoaded("Image Encoder is not available. Check the logs for initialization errors.")
        }
        return try imageEncoder.prediction(image: image).final_emb_1
    }

    /// Generates an embedding from an MLMultiArray of text tokens using the text model.
    func encode(text: MLMultiArray) async throws -> MLMultiArray {
        // Safely unwrap the optional model. If it's nil, throw a specific error.
        guard let textEncoder = self.textEncoder else {
            throw ModelError.notLoaded("Text Encoder is not available. Check the logs for initialization errors.")
        }
        return try textEncoder.prediction(text: text).final_emb_1
    }
}
