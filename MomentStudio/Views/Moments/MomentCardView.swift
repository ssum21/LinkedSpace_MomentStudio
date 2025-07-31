//
//  MomentCardView.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: A reusable view that displays a summary of a single Moment. It separates
//           navigation gestures from button actions and communicates user intents
//           back to its parent view via closures.
//

import SwiftUI

struct MomentCardView: View {
    // MARK: - PROPERTIES
    
    /// A binding to the moment data, allowing this view to reflect and (via its parent)
    /// allow modifications to the original data source.
    @Binding var moment: Moment
    
    /// A closure that this view calls when the user taps the "Edit" button.
    /// The parent view is responsible for implementing the ranking logic.
    var onEdit: () -> Void
    
    // MARK: - BODY
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // --- PART 1: Navigational Area ---
            // This part of the card, when tapped, navigates to the detail view.
            NavigationLink(destination: MomentDetailView(moment: $moment)) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header: Moment name and time
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text(moment.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            Text(moment.time)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.footnote.weight(.bold))
                            .padding(.top, 4)
                    }
                    .padding([.horizontal, .top])
                    .padding(.bottom, 8)
                    
                    // Cover Photo
                    PhotoAssetView(identifier: moment.representativeAssetId)
                        .aspectRatio(4/3, contentMode: .fill)
                        .clipped()
                }
            }
            .buttonStyle(PlainButtonStyle()) // Prevents the link from styling the text inside.

            // --- PART 2: Action Button Area ---
            // This part contains buttons that perform actions within the current view.
            HStack(spacing: 12) {
                Spacer()
                
                // "Edit" button
                Button(action: {
                    // When tapped, call the onEdit closure provided by the parent view.
                    onEdit()
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(MomentActionButtonStyle(hasContent: true))
                // The button is disabled if there are no alternative places to choose from.
                
                // "Voice" button
                Button(action: { /* TODO: Implement voice memo action */ }) {
                    Label("Voice", systemImage: "waveform")
                }
                .buttonStyle(MomentActionButtonStyle(hasContent: moment.voiceMemoPath != nil))
                
                // "Caption" button
                Button(action: { /* TODO: Implement caption action */ }) {
                    Label("Caption", systemImage: "pencil.and.ellipsis.rectangle")
                }
                .buttonStyle(MomentActionButtonStyle(hasContent: moment.caption != nil && !moment.caption!.isEmpty))
            }
            .padding([.horizontal, .bottom])
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
        // Note: The .sheet modifier is now managed by the parent view (DayDetailView).
    }
}

// MARK: - Custom Button Style
// (This struct remains the same)
struct MomentActionButtonStyle: ButtonStyle {
    var hasContent: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.label
        }
        .font(.system(size: 14))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundColor(hasContent ? .primary : .secondary)
        .background(
            Color(.secondarySystemBackground)
                .opacity(hasContent ? 1.0 : 0.7)
                .cornerRadius(20)
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}


// MARK: - PREVIEW
struct MomentCardView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample binding for the preview.
        let mockMoment = Moment.mockData.first!
        let mockBinding = Binding.constant(mockMoment)
        
        return MomentCardView(moment: mockBinding, onEdit: {
            // The onEdit action for the preview can be empty or print a message.
            print("Edit button was tapped in Preview.")
        })
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
