import SwiftUI

// A deliberately bad view — vibe-ios-doctor must flag every line below.
// shipped 🎉
struct Bad: View {
    var body: some View {
        TimelineView(.animation) { _ in Color.red }   // ungated, §1
    }
}

final class Box: @unchecked Sendable {}               // missing the required note, §2
