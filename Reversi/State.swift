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
    /// 依頼に答えたら `Action.boardUpdated` をディスパッチしてください。
    public var boardUpdateRequest: Request<BoardUpdate>?

    /// 「パス」を通知する依頼が出ていれば値が設定されています。
    /// 依頼に答えて通知が閉じられたら `Action.passDismissed` をディスパッチしてください。
    public var passNotificationRequest: Request<Void>?
    
    /// リセットの確認を表示する依頼が出ていれば値が設定されています。
    /// 依頼に答えて確認結果が得られたら `Action.resetConfirmed` をディスパッチしてください。
    public var resetConfirmationRequst: Request<Void>?    
    
    public init(board: Board, turn: Disk?, playerModes: [PlayerMode]) {
        precondition(playerModes.count == Disk.sides.count)
        
        self.board = board
        self.turn = turn
        self.playerModes = playerModes
    }
}

/// ゲーム外部に出す依頼
public struct Request<D> {
    /// 依頼の番号
    public let requestId = UniqueIdentifier()
    
    /// 依頼の詳細
    public let detail: D
    
    public init(_ detail: D) {
        self.detail = detail
    }
}

extension Request where D == Void {
    public init() {
        self.init(())
    }
}

/// リバーシ盤の表示更新の依頼内容
public enum BoardUpdate {
    /// 「1つのセルをアニメーション付きで更新してください」という依頼
    case withAnimation(Board.CellChange)
    
    /// 「一連のセルをアニメーションなしで更新してください」という依頼
    case withoutAnimation([Board.CellChange])
}

