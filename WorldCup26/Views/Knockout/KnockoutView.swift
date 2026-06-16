import SwiftUI

/// The knockout bracket: round columns laid out so later-round cells align
/// vertically between the two matches that feed them (classic bracket look).
/// Rounded connector lines link each pair of feeder cells to the match they
/// feed. Scrolls horizontally and vertically. Third-place play-off shown below.
struct KnockoutView: View {
    @State private var model: KnockoutViewModel

    init(store: TournamentStore) {
        _model = State(initialValue: KnockoutViewModel(store: store))
    }

    private let cellWidth: CGFloat = 150
    private let cellHeight: CGFloat = 58
    private let baseGap: CGFloat = 16
    private let columnSpacing: CGFloat = 22
    private let headerHeight: CGFloat = 24       // fixed so connector geometry is exact

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                bracket
                if let third = model.thirdPlace {
                    thirdPlaceSection(third)
                }
            }
            .padding(DS.Spacing.lg)
        }
        .defaultScrollAnchor(.topLeading)
        .background(DS.Color.groupedBackground)
        .navigationTitle(LKey("tab.knockout"))
    }

    private var bracket: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            ForEach(Array(model.columns.enumerated()), id: \.element.id) { index, column in
                bracketColumn(column, roundIndex: index)
            }
        }
        .background(connectors(columnCounts: model.columns.map(\.matches.count)))
    }

    private func bracketColumn(_ column: KnockoutViewModel.Column, roundIndex: Int) -> some View {
        let factor = CGFloat(1 << roundIndex)           // 1, 2, 4, 8, 16
        let unit = (cellHeight + baseGap) * factor       // center-to-center distance
        let topPadding = (unit - (cellHeight + baseGap)) / 2
        let spacing = unit - cellHeight

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(key: column.round.displayKey)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: cellWidth, height: headerHeight, alignment: .bottomLeading)

            VStack(spacing: spacing) {
                ForEach(column.matches) { match in
                    NavigationLink(value: match) {
                        BracketMatchCell(match: match, width: cellWidth, height: cellHeight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, topPadding)
        }
    }

    // MARK: - Connector lines

    /// Rounded "elbow" lines joining each pair of feeder cells in one column to
    /// the single cell they feed in the next column. Drawn behind the cells so
    /// line ends tuck neatly under each cell's edge.
    private func connectors(columnCounts: [Int]) -> some View {
        Canvas { context, _ in
            let radius: CGFloat = 8
            for round in 0..<max(0, columnCounts.count - 1) {
                let rightX = columnLeftX(round) + cellWidth
                let targetLeftX = columnLeftX(round + 1)
                let midX = (rightX + targetLeftX) / 2
                var path = Path()

                for target in 0..<columnCounts[round + 1] {
                    let topIndex = target * 2
                    let bottomIndex = target * 2 + 1
                    guard bottomIndex < columnCounts[round] else { continue }

                    let yTop = cellCenterY(roundIndex: round, index: topIndex)
                    let yBottom = cellCenterY(roundIndex: round, index: bottomIndex)
                    let yTarget = (yTop + yBottom) / 2
                    let r = min(radius, midX - rightX, (yBottom - yTop) / 2)

                    // top feeder → corner down
                    path.move(to: CGPoint(x: rightX, y: yTop))
                    path.addLine(to: CGPoint(x: midX - r, y: yTop))
                    path.addQuadCurve(to: CGPoint(x: midX, y: yTop + r),
                                      control: CGPoint(x: midX, y: yTop))
                    // vertical spine
                    path.addLine(to: CGPoint(x: midX, y: yBottom - r))
                    // corner → bottom feeder
                    path.addQuadCurve(to: CGPoint(x: midX - r, y: yBottom),
                                      control: CGPoint(x: midX, y: yBottom))
                    path.addLine(to: CGPoint(x: rightX, y: yBottom))
                    // spine midpoint → target cell
                    path.move(to: CGPoint(x: midX, y: yTarget))
                    path.addLine(to: CGPoint(x: targetLeftX, y: yTarget))
                }

                context.stroke(
                    path,
                    with: .color(Color(.separator)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// Left edge of a column's cells, relative to the bracket's top-left.
    private func columnLeftX(_ roundIndex: Int) -> CGFloat {
        CGFloat(roundIndex) * (cellWidth + columnSpacing)
    }

    /// Vertical center of a cell, relative to the bracket's top-left. Mirrors
    /// the layout math in `bracketColumn` (header + spacing, then padded cells).
    private func cellCenterY(roundIndex: Int, index: Int) -> CGFloat {
        let factor = CGFloat(1 << roundIndex)
        let unit = (cellHeight + baseGap) * factor
        let topPadding = (unit - (cellHeight + baseGap)) / 2
        let spacing = unit - cellHeight
        let cellsTop = headerHeight + DS.Spacing.sm
        return cellsTop + topPadding + CGFloat(index) * (cellHeight + spacing) + cellHeight / 2
    }

    private func thirdPlaceSection(_ match: Match) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(key: "knockout.thirdPlace")
                .font(.headline)
            NavigationLink(value: match) {
                BracketMatchCell(match: match, width: cellWidth, height: cellHeight)
            }
            .buttonStyle(.plain)
        }
    }
}
