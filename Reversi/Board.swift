import Foundation

public enum BoardError: Error {
    case diskPlacement(disk: Disk, x: Int, y: Int)
    case restore(dump: [[Disk?]])
}

public struct Board {
    /// 盤の幅（ `8` ）を表します。
    public let width: Int = 8
    
    /// 盤の高さ（ `8` ）を返します。
    public let height: Int = 8
    
    /// 盤のセルの `x` の範囲（ `0 ..< 8` ）を返します。
    public let xRange: Range<Int>
    
    /// 盤のセルの `y` の範囲（ `0 ..< 8` ）を返します。
    public let yRange: Range<Int>
    
    /// 状態が変更されたセルの場所と変更後のディスクの値を示します。
    public struct CellChange: Hashable {
        /// 変更されたセルの列です。
        public var x: Int
        
        /// 変更されたセルの行です。
        public var y: Int
        
        /// 変更された結果のセルの状態です。セルにディスクが置かれていない場合、 `nil` になります。
        public var disk: Disk?
        
        public init(x: Int, y: Int, disk: Disk?) {
            self.x = x
            self.y = y
            self.disk = disk
        }
    }
    
    private var cells: [Disk?]

    public init() {
        xRange = 0 ..< width
        yRange = 0 ..< height
        cells = [Disk?].init(repeating: nil, count: width * height)
        _ = reset()
    }
    
    /// `dump()` で書き出した配列を元に、盤の状態を構築します。
    /// - Parameter dump: 盤の状態を書き出した配列
    /// - Throws: 引数で渡されたものが不正な場合は `BoardError.restore` を `throw` します。
    public init(restoringFrom dump: [[Disk?]]) throws {
        self.init()
        _ = try restore(from: dump)
    }
    
    /// 盤をゲーム開始時に状態に戻します。
    /// - Returns: 変更されたセルの情報を返します。
    public mutating func reset() -> [CellChange] {
        var cellChanges = [CellChange]()
        
        for y in  yRange {
            for x in xRange {
                setDisk(nil, atX: x, y: y, recordingOnto: &cellChanges)
            }
        }
        
        setDisk(.light, atX: width / 2 - 1, y: height / 2 - 1, recordingOnto: &cellChanges)
        setDisk(.dark, atX: width / 2, y: height / 2 - 1, recordingOnto: &cellChanges)
        setDisk(.dark, atX: width / 2 - 1, y: height / 2, recordingOnto: &cellChanges)
        setDisk(.light, atX: width / 2, y: height / 2, recordingOnto: &cellChanges)
        
        return cellChanges
    }
    
    /// 盤の状態を `Disk?` の配列の配列に書き出します。
    /// - Returns: 盤の状態を書き出した配列
    public func dump() -> [[Disk?]] {
        var output = [[Disk?]]()
        for y in yRange {
            var line = [Disk?]()
            for x in xRange {
                line.append(diskAt(x: x, y: y))
            }
            output.append(line)
        }
        return output
    }
    
    /// `dump()` で書き出した配列を元に、盤の状態を復元します。
    /// - Parameter dump: 盤の状態を書き出した配列
    /// - Returns: 変更されたセルの情報を返します。
    /// - Throws: 引数で渡されたものが不正な場合は `BoardError.restore` を `throw` します。
    public mutating func restore(from dump: [[Disk?]]) throws -> [CellChange] {
        var lines = dump[...]

        guard lines.count == height else {
            throw BoardError.restore(dump: dump)
        }
        
        var cellChanges = [CellChange]()
        
        guard lines.count == height else {
            throw BoardError.restore(dump: dump)
        }
        var y = 0
        while let line = lines.popFirst() {
            guard line.count == width else {
                throw BoardError.restore(dump: dump)
            }
            var x = 0
            for disk in line {
                setDisk(disk, atX: x, y: y, recordingOnto: &cellChanges)
                x += 1
            }
            y += 1
        }
        
        return cellChanges
    }
    
    /// `x`, `y` で指定されたセルの状態を返します。
    /// セルにディスクが置かれていない場合、 `nil` が返されます。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: セルにディスクが置かれている場合はそのディスクの値を、置かれていない場合は `nil` を返します。
    public func diskAt(x: Int, y: Int) -> Disk? {
        guard xRange.contains(x) && yRange.contains(y) else { return nil }
        return cells[y * width + x]
    }

    /// `x`, `y` で指定されたセルの状態を、与えられた `disk` に変更します。
    /// - Parameter disk: セルに設定される新しい状態です。 `nil` はディスクが置かれていない状態を表します。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Parameter cellChanges: セルの変更を記憶するための配列を指定します。
    private mutating func setDisk(_ disk: Disk?, atX x: Int, y: Int, recordingOnto cellChanges: inout [CellChange]) {
        guard xRange.contains(x) && yRange.contains(y) else { preconditionFailure() }
        cells[y * width + x] = disk
        cellChanges.append(CellChange(x: x, y: y, disk: disk))
    }
    
    /// `side` で指定された色のディスクが盤上に置かれている枚数を返します。
    /// - Parameter side: 数えるディスクの色です。
    /// - Returns: `side` で指定された色のディスクの、盤上の枚数です。
    public func countDisks(of side: Disk) -> Int {
        var count = 0
        
        for y in yRange {
            for x in xRange {
                if diskAt(x: x, y: y) == side {
                    count +=  1
                }
            }
        }
        
        return count
    }
    
    /// 盤上に置かれたディスクの枚数が多い方の色を返します。
    /// 引き分けの場合は `nil` が返されます。
    /// - Returns: 盤上に置かれたディスクの枚数が多い方の色です。引き分けの場合は `nil` を返します。
    public func sideWithMoreDisks() -> Disk? {
        let darkCount = countDisks(of: .dark)
        let lightCount = countDisks(of: .light)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .dark : .light
        }
    }
    
    private func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, atX x: Int, y: Int) -> [(Int, Int)] {
        let directions = [
            (x: -1, y: -1),
            (x:  0, y: -1),
            (x:  1, y: -1),
            (x:  1, y:  0),
            (x:  1, y:  1),
            (x:  0, y:  1),
            (x: -1, y:  0),
            (x: -1, y:  1),
        ]
        
        guard diskAt(x: x, y: y) == nil else {
            return []
        }
        
        var diskCoordinates: [(Int, Int)] = []
        
        for direction in directions {
            var x = x
            var y = y
            
            var diskCoordinatesInLine: [(Int, Int)] = []
            flipping: while true {
                x += direction.x
                y += direction.y
                
                switch (disk, diskAt(x: x, y: y)) { // Uses tuples to make patterns exhaustive
                case (.dark, .some(.dark)), (.light, .some(.light)):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .some(.light)), (.light, .some(.dark)):
                    diskCoordinatesInLine.append((x, y))
                case (_, .none):
                    break flipping
                }
            }
        }
        
        return diskCoordinates
    }
    
    /// `x`, `y` で指定されたセルに、 `disk` が置けるかを調べます。
    /// ディスクを置くためには、少なくとも 1 枚のディスクをひっくり返せる必要があります。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: 指定されたセルに `disk` を置ける場合は `true` を、置けない場合は `false` を返します。
    public func canPlaceDisk(_ disk: Disk, atX x: Int, y: Int) -> Bool {
        !flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y).isEmpty
    }
    
    /// `side` で指定された色のディスクを置ける盤上のセルの座標をすべて返します。
    /// - Returns: `side` で指定された色のディスクを置ける盤上のすべてのセルの座標の配列です。
    public func validMoves(for side: Disk) -> [(x: Int, y: Int)] {
        var coordinates: [(Int, Int)] = []
        
        for y in yRange {
            for x in xRange {
                if canPlaceDisk(side, atX: x, y: y) {
                    coordinates.append((x, y))
                }
            }
        }
        
        return coordinates
    }
    
    /// `x`, `y` で指定されたセルに `disk` を置きます。
    /// - Parameter disk: セルに置かれるディスクです。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: 変更されたセルの情報を返します。
    /// - Throws: もし `disk` を `x`, `y` で指定されるセルに置けない場合、 `BoardError.diskPlacement` を `throw` します。
    public mutating func placeDisk(_ disk: Disk, atX x: Int, y: Int) throws -> [CellChange] {
        let diskCoordinates = flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y)
        if diskCoordinates.isEmpty {
            throw BoardError.diskPlacement(disk: disk, x: x, y: y)
        }

        var cellChanges = [CellChange]()
        
        setDisk(disk, atX: x, y: y, recordingOnto: &cellChanges)
        for (x, y) in diskCoordinates {
            self.setDisk(disk, atX: x, y: y, recordingOnto: &cellChanges)
        }
        
        return cellChanges
    }
}
