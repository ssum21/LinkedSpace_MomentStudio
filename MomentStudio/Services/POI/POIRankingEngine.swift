// FILE: POIRankingEngine.swift

import Foundation
import CoreLocation
import CoreML

struct RankedPOICandidate: Identifiable {
    let id = UUID()
    let place: Place
    var distance: CLLocationDistance
    var clipScore: Float = 0.0
    var finalScore: Float = 0.0
}

class POIRankingEngine {
    
    private let clipWeight: Float = 0.3
    private let distanceWeight: Float = 0.7
    private let genericTagsBlacklist: Set<String> = ["point_of_interest", "establishment", "store"]

    private let mobileCLIPClassifier: ZSImageClassification
    
    init(classifier: ZSImageClassification) {
        self.mobileCLIPClassifier = classifier
    }
    
    // [VERIFIED FIX] This function correctly uses 'await' for ALL calls to the actor.
    func rankPlaces(places: [Place], imagePixelBuffer: CVPixelBuffer, photoLocation: CLLocationCoordinate2D) async -> [RankedPOICandidate] {
        
        var candidates: [RankedPOICandidate] = places.map { place in
            let placeLocation = CLLocation(latitude: place.location.lat, longitude: place.location.lng)
            let photoCLLocation = CLLocation(latitude: photoLocation.latitude, longitude: photoLocation.longitude)
            let distance = photoCLLocation.distance(from: placeLocation)
            return RankedPOICandidate(place: place, distance: distance)
        }

        // --- Image Embedding ---
        // [AWAIT REQUIRED] Call to an actor's method must be awaited.
        guard let imageEmbeddingResult = await mobileCLIPClassifier.computeImageEmbeddings(frame: imagePixelBuffer) else {
            return []
        }
        let imageEmbedding = imageEmbeddingResult.embedding

        // --- Text Embeddings ---
        var allHighQualityTags: Set<String> = []
        for candidate in candidates {
            let tags = extractHighQualityTags(from: candidate.place.types)
            for tag in tags { allHighQualityTags.insert(tag) }
        }
        
        // [AWAIT REQUIRED] This is the line causing the error. An actor's method must be awaited.
        let textEmbeddings = await mobileCLIPClassifier.computeTextEmbeddings(promptArr: Array(allHighQualityTags))
        let tagEmbeddingMap = Dictionary(uniqueKeysWithValues: zip(allHighQualityTags, textEmbeddings))

        // --- Scoring ---
        // The rest of this function does not call actor-isolated methods.
        for i in 0..<candidates.count {
            let tags = extractHighQualityTags(from: candidates[i].place.types)
            var maxScore: Float = 0.0
            for tagName in tags {
                if let textEmbedding = tagEmbeddingMap[tagName] {
                    // 'cosineSimilarity' is 'nonisolated', so it doesn't need 'await'.
                    let similarity = mobileCLIPClassifier.cosineSimilarity(imageEmbedding, textEmbedding)
                    if similarity > maxScore { maxScore = similarity }
                }
            }
            candidates[i].clipScore = maxScore
        }

        // --- Final Score Calculation ---
        for i in 0..<candidates.count {
            let candidate = candidates[i]
            let distanceScore = exp(-Float(candidate.distance) / 100.0)
            
            let priorityBonus = getPriorityBonus(for: candidate.place.types)
            let proximityBonus = getProximityBonus(for: candidate.distance, types: candidate.place.types)
            
            let finalScore = (candidate.clipScore * clipWeight) + (distanceScore * distanceWeight) + priorityBonus + proximityBonus
            candidates[i].finalScore = finalScore
        }
        
        // ▼▼▼ [FIX] Add a fallback mechanism to prevent returning an empty array. ▼▼▼
        var sortedCandidates = candidates.sorted { $0.finalScore > $1.finalScore }
        
        // If all scores are zero (or very low), it means the ranking failed.
        // In this case, fall back to sorting by distance as a last resort.
        if sortedCandidates.first?.finalScore == 0.0 {
            print("⚠️ Ranking scores were all zero. Falling back to distance-based sorting.")
            sortedCandidates = candidates.sorted { $0.distance < $1.distance }
        }
        
        // Ensure we always return the original candidates if sorting fails for some reason.
        return sortedCandidates.isEmpty ? candidates : sortedCandidates
    }
    
    private func extractHighQualityTags(from types: [String]) -> [String] {
        return types.filter { !genericTagsBlacklist.contains($0) }.map { $0.replacingOccurrences(of: "_", with: " ") }
    }
    
    private func getPriorityBonus(for types: [String]) -> Float {
        let placeTypes = Set(types)
        
        let level1: Set<String> = ["airport", "university", "stadium", "amusement_park", "national_park", "train_station", "subway_station", "transit_station"]
        if !placeTypes.isDisjoint(with: level1) { return 0.12 }
        
        let level2: Set<String> = ["tourist_attraction", "historical_landmark", "resort", "golf_course", "shopping_mall", "museum", "art_gallery", "zoo", "aquarium"]
        if !placeTypes.isDisjoint(with: level2) { return 0.09 }
        
        let level3: Set<String> = ["restaurant", "park", "hotel", "market", "cafe", "bar"]
        if !placeTypes.isDisjoint(with: level3) { return 0.06 }
        
        let level4: Set<String> = ["bakery", "ice_cream_shop", "department_store", "clothing_store", "book_store", "car_rental", "movie_theater", "spa"]
        if !placeTypes.isDisjoint(with: level4) { return 0.03 }
        
        return 0.0
    }
    
    private func getProximityBonus(for distance: CLLocationDistance, types: [String]) -> Float {
        if types.contains("hotel") || types.contains("resort") {
            if distance < 80 { return 0.25 }
        }
        if distance < 40 { return 0.20 }
        return 0.0
    }
}
