/// Square cells laid out across the print width, in dots.
public struct IconSheetLayout: Equatable, Sendable {
    public struct Cell: Equatable, Sendable {
        public let x: Int
        public let y: Int
        public let size: Int
    }

    public let count: Int
    public let perRow: Int
    public let width: Int

    public init(count: Int, perRow: Int, width: Int = PhomemoEncoder.printWidth) {
        precondition(perRow > 0, "need at least one icon per row")
        self.count = count
        self.perRow = perRow
        self.width = width
    }

    public var cellSize: Int { width / perRow }

    public var rows: Int { (count + perRow - 1) / perRow }

    public var height: Int { rows * cellSize }

    /// Leftover dots when the width doesn't divide evenly, split to center the grid.
    private var inset: Int { (width - cellSize * perRow) / 2 }

    public func cell(_ index: Int) -> Cell {
        Cell(
            x: inset + (index % perRow) * cellSize,
            y: (index / perRow) * cellSize,
            size: cellSize
        )
    }

    public var cells: [Cell] { (0..<count).map(cell) }
}
