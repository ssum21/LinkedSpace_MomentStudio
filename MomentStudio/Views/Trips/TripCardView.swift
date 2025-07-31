//
//  TripCardView.swift
//  MomentStudio
//
//  Created by SSUM on 7/29/25.
//
//  PURPOSE: A reusable view component that displays a summary of a single TripAlbum.
//           This view matches the card design from the Figma UI.
//

import SwiftUI

struct TripCardView: View {
    // MARK: - PROPERTIES
    
    let trip: TripAlbum
    
    /// Calculates the date range string for the trip.
    private var dateRangeString: String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d" // e.g., "Jul 29"
        
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        // Safely unwrap dates
        guard let firstDayStr = trip.days.first?.date,
              let lastDayStr = trip.days.last?.date,
              let firstDate = inputFormatter.date(from: firstDayStr),
              let lastDate = inputFormatter.date(from: lastDayStr) else {
            return "Unknown Dates"
        }
        
        if firstDayStr == lastDayStr {
            return outputFormatter.string(from: firstDate)
        } else {
            return "\(outputFormatter.string(from: firstDate)) - \(outputFormatter.string(from: lastDate))"
        }
    }
    
    /// The total number of moments (places) in the trip.
    private var placeCount: Int {
        trip.days.reduce(0) { $0 + $1.moments.count }
    }

    // MARK: - BODY
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ... (VStack 내부의 UI 코드는 이전과 동일) ...
            // MARK: - Card Header (Title and Dates)
            VStack(alignment: .leading) {
                Text(trip.albumTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text(dateRangeString)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 8)
            
            // MARK: - Cover Photo
            // [FIX] Add a placeholder for when the identifier is invalid.
            if let coverIdentifier = trip.days.first?.coverImage, !coverIdentifier.isEmpty {
                PhotoAssetView(identifier: coverIdentifier)
                    .aspectRatio(16/10, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/10, contentMode: .fit)
                    .overlay(Text("No Image").foregroundColor(.white))
            }
            
            // MARK: - Card Footer (Place Count)
            HStack {
                Spacer()
                Text("\(placeCount) Places")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(99)
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}
