import SwiftUI

/// A country flag emoji. Falls back to a neutral flag for undecided knockout
/// slots.
struct FlagView: View {
    let emoji: String
    var size: CGFloat = 32

    var body: some View {
        Text(emoji.isEmpty ? "🏳️" : emoji)
            .font(.system(size: size * 0.62))
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack {
        FlagView(emoji: "🇦🇷")
        FlagView(emoji: "🇧🇷", size: 48)
        FlagView(emoji: "")
    }
    .padding()
}
