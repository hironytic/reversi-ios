import Foundation

public enum ActionCreators {
    static func changePhase<P: Phase>(to phase: P) -> Thunk {
        return changePhase(to: AnyPhase(phase))
    }
    
    /// フェーズを変更するサンクを生成します。
    /// - Parameter phase: 次のフェーズ
    /// - Returns: 生成したサンクを返します。
    static func changePhase(to phase: AnyPhase) -> Thunk {
        return { (dispatcher, state) in
            // onExitやonEnterの中でchangePhaseがディスパッチされても大丈夫なように
            // changePhaseは必ず次のタイミングで行う
            DispatchQueue.main.async {
                let prevPhase = state.phase
                
                // 前のフェーズのonExitを呼び出す
                if let thunk = state.phase.onExit(nextPhase: phase) {
                    dispatcher.dispatch(thunk)
                }
                
                // フェーズを変更する
                dispatcher.dispatch(ActionCreators.setState { state in
                    var state = state
                    state.phase = phase
                    return state
                })
                
                // 次のフェーズのonEnterを呼び出す
                if let thunk = phase.onEnter(previousPhase: prevPhase) {
                    dispatcher.dispatch(thunk)
                }
            }
        }
    }
    
    /// Reducer相当のクロージャーを指定して任意に状態を変更できるアクションを生成します。
    /// - Parameter closure: 状態を変更する方法
    /// - Returns: 生成したアクションを返します。
    static func setState(closure: @escaping (State) -> State) -> Action {
        struct ClosureReducer: Reducer {
            let closure: (State) -> State
            func reduce(state: State, action: Action) -> State {
                return closure(state)
            }
        }
        return ._setState(reducer: ClosureReducer(closure: closure))
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

    /// （内部利用）状態変更の方法を指示したアクションです。
    case _setState(reducer: Reducer)
}

