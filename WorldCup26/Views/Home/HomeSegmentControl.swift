import SwiftUI

/// The Yesterday / Today / Upcoming switcher at the top of the Home feed,
/// rendered as a native segmented control.
struct HomeSegmentControl: View {
    @Binding var selection: HomeSegment

    var body: some View {
        Picker(LKey("home.title"), selection: $selection) {
            ForEach(HomeSegment.allCases) { segment in
                Text(key: segment.titleKey).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
