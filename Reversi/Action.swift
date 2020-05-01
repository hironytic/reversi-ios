import Foundation

/// アクションっぽいもの
public enum Actionish {
    /// 実際のアクションです。
    case action(Action)
    
    /// アクションを遅延ディスパッチするサンクです。
    case thunk(Thunk)
}

// 外部からディスパッチしてもらうもの
extension Actionish {
    /// ゲームを開始するときにこのメソッドの結果をディスパッチします。
    public static func start() -> Actionish {
        return .action(.start)
    }
    
    /// ボードのセルが選択されたときに、このメソッドの結果をディスパッチします。
    public static func boardCellSelected(x: Int, y: Int) -> Actionish {
        return .action(.boardCellSelected(x: x, y: y))
    }
    
    /// 黒・白のプレイヤーモードが変更されたときに、このメソッドの結果をディスパッチします。
    public static func playerModeChanged(player: Disk, mode: PlayerMode) -> Actionish {
        return .action(.playerModeChanged(player: player, mode: mode))
    }
    
    /// リセットボタンが押されたときに、このメソッドの結果をディスパッチします。
    public static func reset() -> Actionish {
        return .action(.reset)
    }
    
    /// リセットの確認ができたときに、このメソッドの結果をディスパッチします。
    public static func resetConfirmed(requestId: UniqueIdentifier, execute: Bool) -> Actionish {
        return .action(.resetConfirmed(requestId: requestId, execute: execute))
    }
    
    /// 「パス」の表示が消されたときに、このメソッドの結果をディスパッチします。
    public static func passDismissed(requestId: UniqueIdentifier) -> Actionish {
        return .action(.passDismissed(requestId: requestId))
    }
    
    /// リバーシ盤の更新が完了したときに、このメソッドの結果をディスパッチします。
    public static func boardUpdated(requestId: UniqueIdentifier) -> Actionish {
        return .action(.boardUpdated(requestId: requestId))
    }
}

// エンジン内部でディスパッチするもの
extension Actionish {
    static func changePhase<P: Phase>(to phase: P) -> Actionish {
        return changePhase(to: AnyPhase(phase))
    }
    
    /// フェーズを変更するサンクを生成します。
    /// - Parameter phase: 次のフェーズ
    /// - Returns: 生成したサンクを返します。
    static func changePhase(to phase: AnyPhase) -> Actionish {
        return .thunk({ (dispatcher, state) in
            // onExitやonEnterの中でchangePhaseがディスパッチされても大丈夫なように
            // changePhaseは必ず次のタイミングで行う
            DispatchQueue.main.async {
                let prevPhase = state.phase
                
                // 前のフェーズのonExitを呼び出す
                if let thunk = state.phase.onExit(nextPhase: phase) {
                    dispatcher.dispatch(thunk: thunk)
                }
                
                // フェーズを変更する
                dispatcher.dispatch(action: .changePhase(nextPhase: phase))
                
                // 次のフェーズのonEnterを呼び出す
                if let thunk = phase.onEnter(previousPhase: prevPhase) {
                    dispatcher.dispatch(thunk: thunk)
                }
            }
        })
    }
    
    /// ゲーム開始時に状態を初期化するアクションを生成します。
    static func initializeStateWhenStarted() -> Actionish {
        return .action(.initializeStateWhenStarted)
    }

    /// 思考中かどうかの値を変更するアクションを生成します。
    static func setThinking(_ thinking: Bool) -> Actionish {
        return .action(.setThinking(thinking))
    }

    /// 指定された位置にディスクを置くアクションを生成します。
    static func placeDisk(disk: Disk, x: Int, y: Int) -> Actionish {
        return .action(.placeDisk(disk: disk, x: x, y: y))
    }
    
    /// リバーシ盤の更新を外部に要求するアクションを生成します。
    static func requestUpdateBoard(request: DetailedRequest<BoardUpdate>?) -> Actionish {
        return .action(.requestUpdateBoard(request: request))
    }

    /// パスの通知を外部に要求するアクションを生成します。
    static func requestPassNotification(_ doRequest: Bool) -> Actionish {
        return .action(.requestPassNotification(doRequest))
    }
    
    /// 次のターンへ変更するアクションを生成します。
    static func nextTurn() -> Actionish {
        return .action(.nextTurn)
    }

    /// リセットを実行するアクションを生成します。
    static func doReset() -> Actionish {
        return .action(.doReset)
    }
}

/// ゲームの状態を進めるためのアクションです。
public enum Action {
    /// ゲームを開始するときにディスパッチするアクションです。
    case start
    
    /// ボードのセルが選択されたときにディスパッチするアクションです。
    case boardCellSelected(x: Int, y: Int)
    
    /// 黒・白のプレイヤーモードが変更されたときにディスパッチするアクションです。
    case playerModeChanged(player: Disk, mode: PlayerMode)
    
    /// リセットボタンが押されたときにディスパッチするアクションです。
    case reset
    
    /// リセットの確認ができたときにディスパッチするアクションです。
    case resetConfirmed(requestId: UniqueIdentifier, execute: Bool)
    
    /// 「パス」の表示が消されたときにディスパッチするアクションです。
    case passDismissed(requestId: UniqueIdentifier)
    
    /// リバーシ盤の更新が完了したときにディスパッチするアクションです。
    case boardUpdated(requestId: UniqueIdentifier)

    /// フェーズを変更するアクションです。
    case changePhase(nextPhase: AnyPhase)
    
    /// ゲーム開始時に状態を初期化するアクションです。
    case initializeStateWhenStarted
    
    /// 思考中かどうかの値を変更するアクションです。
    case setThinking(Bool)
    
    /// (x, y)で指定された位置にディスクを置くアクションです。
    case placeDisk(disk: Disk, x: Int, y: Int)
    
    /// リバーシ盤の更新を外部に要求するアクションです。
    case requestUpdateBoard(request: DetailedRequest<BoardUpdate>?)
    
    /// パスの通知を外部に要求するアクションです。
    case requestPassNotification(Bool)
    
    /// 次のターンへ変更するアクションです。
    case nextTurn
    
    /// リセットを実行するアクションです。
    case doReset
}
