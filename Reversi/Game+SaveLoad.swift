import Foundation

extension Game {
    /// 保存した状態で初期化します。
    /// - Parameter data: 保存状態のテキスト
    /// - Parameter reducer: リデューサー
    /// - Parameter middlewares: ミドルウェア
    /// - Throws: 保存状態を復元できなければ `GameError.restore` を `throw` します。
    public convenience init(loading data: String,
                            reducer: Reducer.Type = GameReducer.self,
                            middlewares: [Middleware.Type] = []) throws
    {
        var lines: ArraySlice<Substring> = data.split(separator: "\n")[...]
        
        guard var line = lines.popFirst() else {
            throw GameError.restore(data: data)
        }
        
        let turn: Disk?
        do { // turn
            guard
                let diskSymbol = line.popFirst(),
                let disk = Optional<Disk>(symbol: diskSymbol.description)
            else {
                throw GameError.restore(data: data)
            }
            turn = disk
        }

        // players
        var playerModes: [PlayerMode] = Disk.sides.map { _ in .manual }
        for side in Disk.sides {
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let playerMode = PlayerMode(index: playerNumber)
            else {
                throw GameError.restore(data: data)
            }
            playerModes[side] = playerMode
        }

        var board = Board()
        do { // board
            guard lines.count == board.height else {
                throw GameError.restore(data: data)
            }
            
            var dump = [[Disk?]]()
            while let line = lines.popFirst() {
                var dumpLine = [Disk?]()
                for character in line {
                    let disk = Disk?(symbol: "\(character)").flatMap { $0 }
                    dumpLine.append(disk)
                }
                guard dumpLine.count == board.width else {
                    throw GameError.restore(data: data)
                }
                dump.append(dumpLine)
            }
            guard dump.count == board.height else {
                throw GameError.restore(data: data)
            }
            do {
                _ = try board.restore(from: dump)
            } catch  {
                throw GameError.restore(data: data)
            }
        }

        let state = State(board: board, turn: turn, playerModes: playerModes)
        self.init(state: state, reducer: reducer, middlewares: middlewares)
    }
    
    /// セーブデータを作成します。
    /// - Parameter state: ゲーム状態
    /// - Returns: 作成したセーブデータ（テキスト）を返します。
    static func createSaveData(state: State) -> String {
        var output: String = ""
        output += state.turn.symbol
        for side in Disk.sides {
            output += state.playerModes[side].index.description
        }
        output += "\n"
        
        let boardDump = state.board.dump()
        for dumpLine in boardDump {
            for disk in dumpLine {
                output += disk.symbol
            }
            output += "\n"
        }
        
        return output
    }
}

// MARK: fileprivate extensions for save-data

extension PlayerMode {
    fileprivate init?(index: Int) {
        guard let mode = PlayerMode.allCases.first(where: { $0.index == index }) else {
            return nil
        }
        self = mode
    }
    
    fileprivate var index: Int {
        switch self {
        case .manual: return 0
        case .computer: return 1
        }
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
