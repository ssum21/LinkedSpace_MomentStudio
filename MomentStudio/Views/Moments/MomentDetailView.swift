//
//  MomentDetailView.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: Shows all the photos (highlights and optionals) for a single moment.
//

import SwiftUI

struct MomentDetailView: View {
    @Binding var moment: Moment
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                // Combine all photos into one list for display.
                ForEach(moment.allAssetIds, id: \.self) { assetId in
                    PhotoAssetView(identifier: assetId)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                }
            }
        }
        .navigationTitle(moment.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
