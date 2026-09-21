import SwiftUI

/// A 0-5 star rating control, backed by the standard XMP `xmp:Rating` tag.
/// Clicking a star sets the rating to that star's position; clicking the
/// currently-set star again clears it back to unrated.
struct StarRatingView: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(star <= rating ? .yellow : .secondary)
                    .onTapGesture {
                        rating = (rating == star) ? 0 : star
                    }
            }
            if rating > 0 {
                Button {
                    rating = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear rating")
            }
        }
    }
}
