import Foundation

/// ゲームの状態です。
public struct State {
    /// リバーシ盤の状態です。
    public var board: Board
    
    /// 現在のターンを表します。ゲームが終了したときは `nil` になります。
    public var turn: Disk?
    
    /// プレイヤーのモードです。
    public var playerModes: [PlayerMode]
    
    /// ゲームのフェーズです。
    public var phase: AnyPhase = AnyPhase(InitialPhase())
    
    /// コンピューターが思考中に true になります。
    public var thinking: Bool = false
    
    /// プレイヤーごとのディスク枚数です。
    public var diskCount: [Int] = Disk.sides.map { _ in 0 }

    /// リバーシ盤の表示を更新する依頼が出ていれば値が設定されています。
    /// 依頼に答えたら `Actionish.boardUpdated()` の結果をディスパッチしてください。
    public var boardUpdateRequest: DetailedRequest<BoardUpdate>?

    /// 「パス」を通知する依頼が出ていれば値が設定されています。
    /// 依頼に答えて通知が閉じられたら `Actionish.passDismissed()` の結果をディスパッチしてください。
    public var passNotificationRequest: Request?
    
    /// リセットの確認を表示する依頼が出ていれば値が設定されています。
    /// 依頼に答えて確認結果が得られたら `Actionish.resetConfirmed()` の結果をディスパッチしてください。
    public var resetConfirmationRequst: Request?
    
    /// ゲームの状態をセーブする依頼が出ていれば値が設定されています。
    public var saveRequest: DetailedRequest<String>?
    
    public init(board: Board, turn: Disk?, playerModes: [PlayerMode]) {
        precondition(playerModes.count == Disk.sides.count)
        
        self.board = board
        self.turn = turn
        self.playerModes = playerModes
    }
    
    /// のちのタイミングでディスパッチしてほしいサンクを登録します。
    public mutating func loop(thunk: @escaping Thunk) {
        _loops.append(thunk)
    }
    
    /// のちのタイミングでディスパッチされるサンクです。
    /// これは本来のStateの一部ではありません。
    /// `loop` を実現するために `State` に場所を間借りしているもので、
    /// このプロパティの値は状態として記録されるべきではありません。
    public var _loops: [Thunk] = []
}

/// ゲーム外部に出す依頼
public struct Request: Hashable, CustomStringConvertible {
    /// 依頼の番号
    public let requestId = UniqueIdentifier()
    
    public var description: String {
        return "Request(requestId: \(requestId))"
    }
}

/// ゲーム外部に出す依頼（詳細付き）
public struct DetailedRequest<D: Hashable>: Hashable, CustomStringConvertible {
    /// 依頼の番号
    public let requestId = UniqueIdentifier()
    
    /// 依頼の詳細
    public let detail: D
    
    public init(_ detail: D) {
        self.detail = detail
    }
    
    public var description: String {
        return "Request(requestId: \(requestId), detail: \(detail))"
    }
}

/// リバーシ盤の表示更新の依頼内容
public enum BoardUpdate: Hashable, CustomStringConvertible {
    /// 「1つのセルをアニメーション付きで更新してください」という依頼
    case withAnimation(Board.CellChange)
    
    /// 「一連のセルをアニメーションなしで更新してください」という依頼
    case withoutAnimation([Board.CellChange])
    
    public var description: String {
        switch self {
        case .withAnimation(let change):
            return "withAnimation(\(change))"
        
        case .withoutAnimation(let changes):
            return "withoutAnimation(\(changes))"
        }
    }
}
