//
//  POIChooserView.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: A view presented as a sheet that allows the user to select
//           a new name for a moment from a list of ranked POI candidates.
//
import SwiftUI

struct POIChooserView: View {
    @Binding var moment: Moment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Top Suggestions")) {
                    ForEach(moment.poiCandidates) { candidate in
                        Button(action: {
                            moment.name = candidate.name
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(candidate.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(String(format: "Score: %.2f", candidate.score))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if moment.name == candidate.name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.title2)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Change Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
