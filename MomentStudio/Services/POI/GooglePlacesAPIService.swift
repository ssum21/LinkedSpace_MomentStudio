import Foundation
import CoreLocation

// MARK: - 1. Data Models for Google Places API Response
// 이 부분은 그대로 유지합니다.
struct GooglePlacesResponse: Codable {
    let results: [Place]
}

struct Place: Codable, Identifiable {
    let id = UUID()
    let placeId: String
    let name: String
    let types: [String]
    let geometry: Geometry
    
    var location: Location {
        return geometry.location
    }
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name, types, geometry
    }
}

struct Geometry: Codable {
    let location: Location
}

struct Location: Codable {
    let lat: Double
    let lng: Double
}


// MARK: - 2. Google Places API Service Class
// [수정됨] 이 파일에서 CategoryMapper 구조체 정의를 완전히 삭제했습니다.
// 이제 이 클래스는 프로젝트의 다른 곳에 있는 'CategoryMapper.swift' 파일을 참조하여 작동합니다.


// MARK: - API 서비스 클래스 (하이브리드 검색 로직 구현)
class GooglePlacesAPIService {

    private var apiKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String, !key.isEmpty else {
            fatalError("Google API Key not found or is empty in Info.plist.")
        }
        return key
    }

    /// **[메인 실행 함수]** 하이브리드 전략으로 주변 장소를 검색하고 지능적으로 분류합니다.
    func fetchAndCategorizePlaces(for location: CLLocationCoordinate2D) async throws -> [(place: Place, categories: [AppCategory])] {
        
        // 1. 하이브리드 검색으로 풍부한 장소 목록을 확보합니다.
        let uniquePlaces = try await fetchNearbyPlacesHybrid(for: location)
        print("📍 Google Places API: Found \(uniquePlaces.count) places.") // <--- 로그 추가
        
        // 2. 각 장소를 분류합니다.
        let categorizedPlaces = uniquePlaces.map { place in
            let categories = CategoryMapper.map(googleTypes: place.types)
            return (place: place, categories: categories)
        }
        return categorizedPlaces
    }
    
    /// **하이브리드 검색**: 광역(랜드마크) 검색과 근접(주변) 검색을 동시에 수행하여 결과를 병합합니다.
    private func fetchNearbyPlacesHybrid(for location: CLLocationCoordinate2D) async throws -> [Place] {
        // --- 1. 두 가지 검색 파라미터 정의 ---
        let landmarkSearchRadius = 1200 // 광역 탐색 (중요 랜드마크)
        let proximitySearchRadius = 75   // 근접 탐색 (바로 주변)

        // --- 2. 'withThrowingTaskGroup'으로 두 API 호출을 동시에 실행 ---
        return try await withThrowingTaskGroup(of: [Place].self) { group -> [Place] in
            
            // 작업 A: 광역(랜드마크) 검색 추가
            group.addTask {
                try await self.performNearbySearch(for: location, radius: landmarkSearchRadius)
            }
            
            // 작업 B: 근접(주변) 검색 추가
            group.addTask {
                try await self.performNearbySearch(for: location, radius: proximitySearchRadius)
            }
            
            var allPlaces: [Place] = []
            // 두 작업이 끝나는 대로 결과를 수집
            for try await places in group {
                allPlaces.append(contentsOf: places)
            }
            
            // --- 3. 결과 병합 및 중복 제거 ---
            var uniquePlaces: [Place] = []
            var seenPlaceIDs = Set<String>()
            for place in allPlaces {
                if !seenPlaceIDs.contains(place.placeId) {
                    uniquePlaces.append(place)
                    seenPlaceIDs.insert(place.placeId)
                }
            }
            
            return uniquePlaces
        }
    }

    /// 단일 Nearby Search API 호출을 수행하는 헬퍼 함수입니다.
    private func performNearbySearch(for location: CLLocationCoordinate2D, radius: Int) async throws -> [Place] {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/nearbysearch/json")!
        
        components.queryItems = [
            URLQueryItem(name: "location", value: "\(location.latitude),\(location.longitude)"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(GooglePlacesResponse.self, from: data).results
    }
}
