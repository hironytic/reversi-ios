import Foundation
import Combine

public protocol Reducer {
    /// アクションに応じて状態を変更します。
    /// - Parameters:
    ///   - state: 変更前の状態です。
    ///   - action: 状態変更を要求するアクションです。
    /// - Returns: 変更後の状態を返します。
    static func reduce(state: State, action: Action) -> State
}

private extension AnyPhase {
    func reduce(state: State, action: Action) -> State {
        return type(of: box).reduce(state: state, action: action)
    }

    func onEnter(state: State, previousPhase: AnyPhase) -> State {
        return type(of: box).onEnter(state: state, previousPhase: previousPhase)
    }
    
    func onExit(state: State, nextPhase: AnyPhase) -> State {
        return type(of: box).onExit(state: state, nextPhase: nextPhase)
    }
}

public enum GameError: Error {
    case restore(data: String)
}

/// ゲームの状態を保持し、アクションをディスパッチすることでゲームを進めます。
public class Game {
    private let stateHolder: CurrentValueSubject<State, Never>

    /// 現在の状態の発行元
    public let statePublisher: AnyPublisher<State, Never>

    /// 新規ゲームの開始状態で初期化します。
    public convenience init() {
        self.init(state: State(board: Board(), turn: .dark, playerModes: [.manual, .manual], phase: AnyPhase(InitialPhase())))
    }

    /// 保存した状態で初期化します。
    /// - Parameter data: 保存状態のテキスト
    /// - Throws: 保存状態を復元できなければ `GameError.restore` を `throw` します。
    public convenience init(loading data: String) throws {
        // TODO:
        self.init()
    }

    /// 指定された状態で初期化します。
    public init(state: State) {
        stateHolder = CurrentValueSubject(state)
        statePublisher = stateHolder
            .eraseToAnyPublisher()
    }

    /// アクションをディスパッチします。
    /// - Parameter action: ディスパッチ対象のアクション
    func dispatch(action: Action) {
        let currentState = stateHolder.value
        var reducedState = MainReducer.reduce(state: currentState, action: action)
        
        // フェーズの遷移を処理
        let prevPhase = currentState.phase
        let nextPhase = reducedState.phase  
        if prevPhase != nextPhase {
            reducedState = prevPhase.onExit(state: reducedState, nextPhase: nextPhase)
            assert(reducedState.phase == nextPhase, "Don't change phase by `onExit`")
            
            reducedState = nextPhase.onEnter(state: reducedState, previousPhase: prevPhase)
            assert(reducedState.phase == nextPhase, "Don't change phase by `onEnter`")
        }
        
        stateHolder.value = reducedState
    }

    /// 指定された関数でアクションを生成してディスパッチします。
    /// - Parameter actionCreator: アクションを生成する関数
    func dispatch(actionCreator: (State) -> Action?) {
        if let action = actionCreator(stateHolder.value) {
            dispatch(action: action)
        }
    }
}

private enum MainReducer: Reducer {
    static func reduce(state: State, action: Action) -> State {
        let currentPhase = state.phase
        
        var reducedState = state // TODO: ここでも何かするよね
        
        // フェーズが変わらなければ、フェーズにreduceさせる
        if currentPhase == reducedState.phase {
            reducedState = currentPhase.reduce(state: reducedState, action: action)
        }
        
        return reducedState
    }
}
