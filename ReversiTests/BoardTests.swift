import XCTest
@testable import Reversi

class BoardTests: XCTestCase {
    override func setUp() {
    }

    override func tearDown() {
    }

    func testJustInit() {
        let board = Board()
        XCTAssertEqual(board.dumpAsText(), """
            --------
            --------
            --------
            ---ox---
            ---xo---
            --------
            --------
            --------
            """
        )
    }
    
    func testInitRestoring() throws {
        let board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )
        
        XCTAssertEqual(board.dumpAsText(), """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )
    }

    func testDiskAt() throws {
        let board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )
        
        XCTAssertEqual(board.diskAt(x: 3, y: 1), .light)
        XCTAssertEqual(board.diskAt(x: 6, y: 3), .dark)
        XCTAssertEqual(board.diskAt(x: 7, y: 7), nil)
    }
    
    func testReset() throws {
        var board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )
        
        let cellChanges = board.reset()
        XCTAssertEqual(cellChanges, [
            // Clear all cells
            Board.CellChange(x: 0, y: 0, disk: nil),
            Board.CellChange(x: 1, y: 0, disk: nil),
            Board.CellChange(x: 2, y: 0, disk: nil),
            Board.CellChange(x: 3, y: 0, disk: nil),
            Board.CellChange(x: 4, y: 0, disk: nil),
            Board.CellChange(x: 5, y: 0, disk: nil),
            Board.CellChange(x: 6, y: 0, disk: nil),
            Board.CellChange(x: 7, y: 0, disk: nil),
            Board.CellChange(x: 0, y: 1, disk: nil),
            Board.CellChange(x: 1, y: 1, disk: nil),
            Board.CellChange(x: 2, y: 1, disk: nil),
            Board.CellChange(x: 3, y: 1, disk: nil),
            Board.CellChange(x: 4, y: 1, disk: nil),
            Board.CellChange(x: 5, y: 1, disk: nil),
            Board.CellChange(x: 6, y: 1, disk: nil),
            Board.CellChange(x: 7, y: 1, disk: nil),
            Board.CellChange(x: 0, y: 2, disk: nil),
            Board.CellChange(x: 1, y: 2, disk: nil),
            Board.CellChange(x: 2, y: 2, disk: nil),
            Board.CellChange(x: 3, y: 2, disk: nil),
            Board.CellChange(x: 4, y: 2, disk: nil),
            Board.CellChange(x: 5, y: 2, disk: nil),
            Board.CellChange(x: 6, y: 2, disk: nil),
            Board.CellChange(x: 7, y: 2, disk: nil),
            Board.CellChange(x: 0, y: 3, disk: nil),
            Board.CellChange(x: 1, y: 3, disk: nil),
            Board.CellChange(x: 2, y: 3, disk: nil),
            Board.CellChange(x: 3, y: 3, disk: nil),
            Board.CellChange(x: 4, y: 3, disk: nil),
            Board.CellChange(x: 5, y: 3, disk: nil),
            Board.CellChange(x: 6, y: 3, disk: nil),
            Board.CellChange(x: 7, y: 3, disk: nil),
            Board.CellChange(x: 0, y: 4, disk: nil),
            Board.CellChange(x: 1, y: 4, disk: nil),
            Board.CellChange(x: 2, y: 4, disk: nil),
            Board.CellChange(x: 3, y: 4, disk: nil),
            Board.CellChange(x: 4, y: 4, disk: nil),
            Board.CellChange(x: 5, y: 4, disk: nil),
            Board.CellChange(x: 6, y: 4, disk: nil),
            Board.CellChange(x: 7, y: 4, disk: nil),
            Board.CellChange(x: 0, y: 5, disk: nil),
            Board.CellChange(x: 1, y: 5, disk: nil),
            Board.CellChange(x: 2, y: 5, disk: nil),
            Board.CellChange(x: 3, y: 5, disk: nil),
            Board.CellChange(x: 4, y: 5, disk: nil),
            Board.CellChange(x: 5, y: 5, disk: nil),
            Board.CellChange(x: 6, y: 5, disk: nil),
            Board.CellChange(x: 7, y: 5, disk: nil),
            Board.CellChange(x: 0, y: 6, disk: nil),
            Board.CellChange(x: 1, y: 6, disk: nil),
            Board.CellChange(x: 2, y: 6, disk: nil),
            Board.CellChange(x: 3, y: 6, disk: nil),
            Board.CellChange(x: 4, y: 6, disk: nil),
            Board.CellChange(x: 5, y: 6, disk: nil),
            Board.CellChange(x: 6, y: 6, disk: nil),
            Board.CellChange(x: 7, y: 6, disk: nil),
            Board.CellChange(x: 0, y: 7, disk: nil),
            Board.CellChange(x: 1, y: 7, disk: nil),
            Board.CellChange(x: 2, y: 7, disk: nil),
            Board.CellChange(x: 3, y: 7, disk: nil),
            Board.CellChange(x: 4, y: 7, disk: nil),
            Board.CellChange(x: 5, y: 7, disk: nil),
            Board.CellChange(x: 6, y: 7, disk: nil),
            Board.CellChange(x: 7, y: 7, disk: nil),
            
            // Place initial disks
            Board.CellChange(x: 3, y: 3, disk: .light),
            Board.CellChange(x: 4, y: 3, disk: .dark),
            Board.CellChange(x: 3, y: 4, disk: .dark),
            Board.CellChange(x: 4, y: 4, disk: .light),
        ])
        
        XCTAssertEqual(board.dumpAsText(), """
            --------
            --------
            --------
            ---ox---
            ---xo---
            --------
            --------
            --------
            """
        )
    }
    
    func testRestore() throws {
        let dump: [[Disk?]] = [
            [.light, nil, nil, nil, nil, nil, nil, nil],
            [nil, .light, nil, .light, nil, nil, nil, nil],
            [nil, nil, .light, .light, nil, .light, nil, nil],
            [nil, nil, .dark, .light, .dark, .light, .dark, nil],
            [nil, nil, nil, .dark, .light, .dark, nil, nil],
            [nil, nil, nil, .light, .dark, .dark, .dark, nil],
            [nil, nil, nil, .light, nil, .dark, nil, nil],
            [nil, nil, .light, nil, nil, nil, nil, nil],
        ]
        
        var board = Board()
        let cellChanges = try board.restore(from: dump)

        XCTAssertEqual(cellChanges, [
            Board.CellChange(x: 0, y: 0, disk: .light),
            Board.CellChange(x: 1, y: 0, disk: nil),
            Board.CellChange(x: 2, y: 0, disk: nil),
            Board.CellChange(x: 3, y: 0, disk: nil),
            Board.CellChange(x: 4, y: 0, disk: nil),
            Board.CellChange(x: 5, y: 0, disk: nil),
            Board.CellChange(x: 6, y: 0, disk: nil),
            Board.CellChange(x: 7, y: 0, disk: nil),
            Board.CellChange(x: 0, y: 1, disk: nil),
            Board.CellChange(x: 1, y: 1, disk: .light),
            Board.CellChange(x: 2, y: 1, disk: nil),
            Board.CellChange(x: 3, y: 1, disk: .light),
            Board.CellChange(x: 4, y: 1, disk: nil),
            Board.CellChange(x: 5, y: 1, disk: nil),
            Board.CellChange(x: 6, y: 1, disk: nil),
            Board.CellChange(x: 7, y: 1, disk: nil),
            Board.CellChange(x: 0, y: 2, disk: nil),
            Board.CellChange(x: 1, y: 2, disk: nil),
            Board.CellChange(x: 2, y: 2, disk: .light),
            Board.CellChange(x: 3, y: 2, disk: .light),
            Board.CellChange(x: 4, y: 2, disk: nil),
            Board.CellChange(x: 5, y: 2, disk: .light),
            Board.CellChange(x: 6, y: 2, disk: nil),
            Board.CellChange(x: 7, y: 2, disk: nil),
            Board.CellChange(x: 0, y: 3, disk: nil),
            Board.CellChange(x: 1, y: 3, disk: nil),
            Board.CellChange(x: 2, y: 3, disk: .dark),
            Board.CellChange(x: 3, y: 3, disk: .light),
            Board.CellChange(x: 4, y: 3, disk: .dark),
            Board.CellChange(x: 5, y: 3, disk: .light),
            Board.CellChange(x: 6, y: 3, disk: .dark),
            Board.CellChange(x: 7, y: 3, disk: nil),
            Board.CellChange(x: 0, y: 4, disk: nil),
            Board.CellChange(x: 1, y: 4, disk: nil),
            Board.CellChange(x: 2, y: 4, disk: nil),
            Board.CellChange(x: 3, y: 4, disk: .dark),
            Board.CellChange(x: 4, y: 4, disk: .light),
            Board.CellChange(x: 5, y: 4, disk: .dark),
            Board.CellChange(x: 6, y: 4, disk: nil),
            Board.CellChange(x: 7, y: 4, disk: nil),
            Board.CellChange(x: 0, y: 5, disk: nil),
            Board.CellChange(x: 1, y: 5, disk: nil),
            Board.CellChange(x: 2, y: 5, disk: nil),
            Board.CellChange(x: 3, y: 5, disk: .light),
            Board.CellChange(x: 4, y: 5, disk: .dark),
            Board.CellChange(x: 5, y: 5, disk: .dark),
            Board.CellChange(x: 6, y: 5, disk: .dark),
            Board.CellChange(x: 7, y: 5, disk: nil),
            Board.CellChange(x: 0, y: 6, disk: nil),
            Board.CellChange(x: 1, y: 6, disk: nil),
            Board.CellChange(x: 2, y: 6, disk: nil),
            Board.CellChange(x: 3, y: 6, disk: .light),
            Board.CellChange(x: 4, y: 6, disk: nil),
            Board.CellChange(x: 5, y: 6, disk: .dark),
            Board.CellChange(x: 6, y: 6, disk: nil),
            Board.CellChange(x: 7, y: 6, disk: nil),
            Board.CellChange(x: 0, y: 7, disk: nil),
            Board.CellChange(x: 1, y: 7, disk: nil),
            Board.CellChange(x: 2, y: 7, disk: .light),
            Board.CellChange(x: 3, y: 7, disk: nil),
            Board.CellChange(x: 4, y: 7, disk: nil),
            Board.CellChange(x: 5, y: 7, disk: nil),
            Board.CellChange(x: 6, y: 7, disk: nil),
            Board.CellChange(x: 7, y: 7, disk: nil),
        ])
        
        XCTAssertEqual(board.dumpAsText(), """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )
    }
    
    func testRestoreFail() {
        var board = Board()

        let dump1: [[Disk?]] = [
            [.light, nil, nil, nil, nil, nil, nil, nil],
            [nil, .light, nil, .light, nil, nil, nil, nil],
            [nil, nil, .light, .light, nil, .light, nil, nil],
            [nil, nil, .dark, .light, .dark, .light, .dark, nil],
        ]
        XCTAssertThrowsError(try board.restore(from: dump1)) { error in
            if case let BoardError.restore(dump: data) = error {
                XCTAssertEqual(data, dump1)
            } else {
                XCTFail()
            }
        }
        
        let dump2: [[Disk?]] = [
            [.light, nil, nil, nil, nil, nil, nil, nil],
            [nil, .light, nil, .light, nil, nil, nil, nil],
            [nil, nil, .light, .light, nil, .light, nil, nil, .light], // too many elements
            [nil, nil, .dark, .light, .dark, .light, .dark, nil],
            [nil, nil, nil, .dark, .light, .dark, nil, nil],
            [nil, nil, nil, .light, .dark, .dark, .dark, nil],
            [nil, nil, nil, .light, nil, .dark, nil, nil],
            [nil, nil, .light, nil, nil, nil, nil, nil],
        ]
        XCTAssertThrowsError(try board.restore(from: dump2)) { error in
            if case let BoardError.restore(dump: data) = error {
                XCTAssertEqual(data, dump2)
            } else {
                XCTFail()
            }
        }
    }
    
    func testPlaceDisk() throws {
        var board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )

        let cellChangesLight = try board.placeDisk(.light, atX: 2, y: 5)
        XCTAssertEqual(cellChangesLight, [
            Board.CellChange(x: 2, y: 5, disk: .light),
            Board.CellChange(x: 3, y: 4, disk: .light),
            Board.CellChange(x: 4, y: 3, disk: .light),
        ])
        XCTAssertEqual(board.dumpAsText(), """
            o-------
            -o-o----
            --oo-o--
            --xooox-
            ---oox--
            --ooxxx-
            ---o-x--
            --o-----
            """
        )
        
        let cellChangesDark = try board.placeDisk(.dark, atX: 2, y: 1)
        XCTAssertEqual(cellChangesDark, [
            Board.CellChange(x: 2, y: 1, disk: .dark),
            Board.CellChange(x: 3, y: 2, disk: .dark),
            Board.CellChange(x: 4, y: 3, disk: .dark),
            Board.CellChange(x: 2, y: 2, disk: .dark),
        ])
        XCTAssertEqual(board.dumpAsText(), """
            o-------
            -oxo----
            --xx-o--
            --xoxox-
            ---oox--
            --ooxxx-
            ---o-x--
            --o-----
            """
        )
    }
    
    func testPlaceDiskFail() throws {
        var board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )

        XCTAssertThrowsError(try board.placeDisk(.dark, atX: 2, y: 6)) { error in
            if case let BoardError.diskPlacement(disk: errorDisk, x: errorX, y: errorY) = error {
                XCTAssertEqual(errorDisk, .dark)
                XCTAssertEqual(errorX, 2)
                XCTAssertEqual(errorY, 6)
            } else {
                XCTFail()
            }
        }
    }
    
    func testCountDisks() throws {
        let board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )
        
        XCTAssertEqual(board.countDisks(of: .light), 12)
        XCTAssertEqual(board.countDisks(of: .dark), 9)
    }
    
    func testSideWithMoreDisks() throws {
        var board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )
        
        XCTAssertEqual(board.sideWithMoreDisks(), .light)
        
        _ = board.reset()
        XCTAssertEqual(board.sideWithMoreDisks(), nil)
    }
    
    func testCanPlaceDisk() throws {
        let board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )
        
        XCTAssertTrue(board.canPlaceDisk(.light, atX: 4, y: 2))
        XCTAssertFalse(board.canPlaceDisk(.dark, atX: 4, y: 2))
        XCTAssertTrue(board.canPlaceDisk(.dark, atX: 3, y: 7))
        XCTAssertFalse(board.canPlaceDisk(.light, atX: 5, y: 3))
    }
    
    func testValidMoves() throws {
        let board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """
        )

        XCTAssertEqual(board.validMoves(for: .light).map { $0.0 * 10 + $0.1 }, [
            42, 72,
            13, 73,
            14, 24, 64, 74,
            25, 75,
            46, 66, 76,
            57,
        ])
    }
}

extension Board { // for testing
    func dumpAsText() -> String {
        return dump()
            .map { dumpLine in
                return dumpLine
                    .map { $0.symbol }
                    .joined()
            }
            .joined(separator: "\n")
    }
    
    init(restoringFromText dumpText: String) throws {
        let dumpArray = dumpText
            .split(separator: "\n")
            .map { line in
                return line.map { character in
                    return Disk?(symbol: "\(character)").flatMap { $0 }
                }
            }
        try self.init(restoringFrom: dumpArray)
    }
}

extension Optional where Wrapped == Disk {
    fileprivate init?<S: StringProtocol>(symbol: S) {
        switch symbol {
        case "x":
            self = .some(.dark)
        case "o":
            self = .some(.light)
        case "-":
            self = .none
        default:
            return nil
        }
    }
    
    fileprivate var symbol: String {
        switch self {
        case .some(.dark):
            return "x"
        case .some(.light):
            return "o"
        case .none:
            return "-"
        }
    }
}
