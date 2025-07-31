//
//  TripDetailView.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: Displays a list of days for a trip. Tapping a day will switch
//           to the Moments tab to show that day's details.
//

import SwiftUI

struct TripDetailView: View {
    @Binding var trip: TripAlbum // Receive as a binding

    var body: some View {
        List($trip.days) { $day in // Use binding array
            NavigationLink(destination: DayDetailView(day: $day)) { // Pass binding
                DayRowView(day: day)
            }
        }
        .listStyle(.plain)
        .navigationTitle(trip.albumTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - DayRowView (Helper View)
// This view requires no changes.
struct DayRowView: View {
    let day: Day
    
    private var momentCount: Int {
        day.moments.count
    }
    
    var body: some View {
        HStack(spacing: 16) {
            PhotoAssetView(identifier: day.coverImage)
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                Text(day.date)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(day.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("\(momentCount) Moments")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - PREVIEW
struct TripDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            // ▼▼▼ [FIX] Create a @State wrapper for the mock data to provide a binding. ▼▼▼
            // @State creates a source of truth that can provide a binding ($mockTrip).
            // This is the standard way to preview views that require a @Binding.
            @State var mockTrip = TripAlbum.mock
            
            // Pass the binding '$mockTrip' to the view's initializer.
            TripDetailView(trip: $mockTrip)
                .environmentObject(AppState()) // Provide a dummy AppState for the preview
            // ▲▲▲ ▲▲▲
        }
        .preferredColorScheme(.dark)
    }
}
