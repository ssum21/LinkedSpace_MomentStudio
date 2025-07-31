import Foundation

// --- 최종 앨범 구조 ---
struct TripAlbum: Codable, Identifiable {
    let id: UUID
    var albumTitle: String
    var days: [Day]
    
    init(albumTitle: String = "새로운 여행", days: [Day] = []) {
        self.id = UUID()
        self.albumTitle = albumTitle
        self.days = days
    }
}

// --- 하루 단위 ---
struct Day: Codable, Identifiable, Equatable {
    let id: UUID
    let date: String
    var coverImage: String
    var summary: String
    var moments: [Moment]
    
    // Equatable conformance: two Day objects are equal if their IDs are the same.
    static func == (lhs: Day, rhs: Day) -> Bool {
        lhs.id == rhs.id
    }
    
    init(date: String, coverImage: String, summary: String, moments: [Moment]) {
        self.id = UUID()
        self.date = date
        self.coverImage = coverImage
        self.summary = summary
        self.moments = moments
    }
}

struct POICandidate: Codable, Identifiable, Hashable {
    let id: String // Google Place ID
    let name: String
    let score: Float
    let latitude: Double
    let longitude: Double
}


// FILE: AlbumModels.swift

// --- 장소/이벤트 단위 (Level 2) ---
// FILE: AlbumModels.swift

// --- 장소/이벤트 단위 (Level 2) ---
// ▼▼▼ [FIX] Let the compiler synthesize Codable conformance automatically. ▼▼▼
// This is safer and requires less maintenance.
struct Moment: Codable, Identifiable {
    let id: UUID
    var name: String
    let time: String
    var representativeAssetId: String
    var highlights: [Highlight]
    var optionalAssetIds: [String]
    var poiCandidates: [POICandidate] // Must be 'var' to be mutable
    var voiceMemoPath: String?
    var caption: String?

    var allAssetIds: [String] {
        highlights.flatMap { $0.assetIds } + optionalAssetIds
    }
    
    // The default memberwise initializer is sufficient.
    // The custom init(from:) and encode(to:) methods have been removed.
    init(id: UUID = UUID(), name: String, time: String, representativeAssetId: String, highlights: [Highlight], optionalAssetIds: [String], poiCandidates: [POICandidate],  voiceMemoPath: String? = nil, caption: String? = nil) {
        self.id = id
        self.name = name
        self.time = time
        self.representativeAssetId = representativeAssetId
        self.highlights = highlights
        self.optionalAssetIds = optionalAssetIds
        self.poiCandidates = poiCandidates
        self.voiceMemoPath = voiceMemoPath
        self.caption = caption
    }
}
// ▲▲▲ ▲▲▲
// --- 유사 사진 단위 (Level 3) ---
struct Highlight: Codable, Identifiable {
    let id: UUID
    var representativeAssetId: String // 대표 사진이 바뀔 수 있으므로 var로 변경
    var assetIds: [String]
    
    init(id: UUID = UUID(), representativeAssetId: String, assetIds: [String]) {
        self.id = id
        self.representativeAssetId = representativeAssetId
        self.assetIds = assetIds
    }
}

// MARK: - Mock Data for Previews
// This extension provides sample data for UI development and previewing.


extension Moment {
    /// Provides an array of sample `Moment` objects for UI testing and previews.
    static var mockData: [Moment] {
        // ▼▼▼ [FIX] Add latitude and longitude to each mock POICandidate. ▼▼▼
        let mockPOICandidates = [
            POICandidate(id: "1", name: "Central Park", score: 0.95, latitude: 40.785091, longitude: -73.968285),
            POICandidate(id: "2", name: "The Metropolitan Museum of Art", score: 0.88, latitude: 40.779437, longitude: -73.963244),
            POICandidate(id: "3", name: "Central Park Zoo", score: 0.75, latitude: 40.7678, longitude: -73.9718),
            POICandidate(id: "4", name: "A Nice Cafe Nearby", score: 0.60, latitude: 40.7831, longitude: -73.9712)
        ]
        // ▲▲▲ ▲▲▲
        
        return [
            Moment(
                name: "Central Park", // The initial name
                time: "9:30 AM - 9:32 AM",
                representativeAssetId: "",
                highlights: [],
                optionalAssetIds: [],
                // The moment will now have candidates with location data for the map.
                poiCandidates: mockPOICandidates,
                caption: "A morning walk in the park."
            ),
            Moment(
                name: "Brooklyn Bridge",
                time: "2:00 PM - 2:05 PM",
                representativeAssetId: "",
                highlights: [],
                optionalAssetIds: [],
                poiCandidates: [
                    POICandidate(id: "5", name: "Brooklyn Bridge", score: 0.98, latitude: 40.706086, longitude: -73.996864),
                    POICandidate(id: "6", name: "Dumbo", score: 0.85, latitude: 40.7033, longitude: -73.9905)
                ],
                voiceMemoPath: "some_path"
            )
        ]
    }
}

extension TripAlbum {
    /// Provides a sample `TripAlbum` object for UI testing and previews.
    static var mock: TripAlbum {
        // 'Moment.mockData'를 재사용하여 일관성 있는 테스트 데이터를 만듭니다.
        let moments = Moment.mockData
        // PhotoAssetView가 유효한 이미지를 찾을 수 있도록, 실제 프로젝트에 있는
        // 에셋의 ID를 여기에 넣으면 Preview에서 실제 이미지를 볼 수 있습니다.
        // 지금은 비워둡니다.
        let day1 = Day(date: "2025-07-28", coverImage: "", summary: "A great day in NYC", moments: moments)
        let day2 = Day(date: "2025-07-29", coverImage: "", summary: "Exploring Brooklyn", moments: [])
        return TripAlbum(albumTitle: "New York Adventure", days: [day1, day2])
    }
}
