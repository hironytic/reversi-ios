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
    /// 現在進行中のゲームのインスタンス
    public static var current: Game?
    
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

    /// ディスパッチメイン処理
    private func dispatchCore(action: Action) {
        let currentState = stateHolder.value
        var reducedState = MainReducer.reduce(state: currentState, action: action)
        
        // フェーズの遷移を処理
        let prevPhase = currentState.phase
        var nextPhase = reducedState.phase
        if prevPhase != nextPhase {
            reducedState = prevPhase.onExit(state: reducedState, nextPhase: nextPhase)
            nextPhase = reducedState.phase
            
            var retryNeeded = false
            repeat {
                reducedState = nextPhase.onEnter(state: reducedState, previousPhase: prevPhase)
                if reducedState.phase != nextPhase {
                    // 遷移したと思ったとたん別のところに遷移するなら
                    // もう一度抜けて入り直し
                    reducedState = nextPhase.onExit(state: reducedState, nextPhase: reducedState.phase)
                    nextPhase = reducedState.phase
                    retryNeeded = true
                } else {
                    retryNeeded = false
                }
            } while retryNeeded
        }
        
        stateHolder.value = reducedState
    }

    /// アクションをディスパッチします。
    /// - Parameter action: ディスパッチ対象のアクション
    public func dispatch(action: Action) {
        DispatchQueue.main.async { [weak self] in
            self?.dispatchCore(action: action)
        }
    }
    
    /// 指定された関数でアクションを生成してディスパッチします。
    /// - Parameter actionCreator: アクションを生成する関数
    public func dispatch(actionCreator: @escaping (State) -> Action?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let action = actionCreator(self.stateHolder.value) {
                self.dispatchCore(action: action)
            }
        }
    }
}

private enum MainReducer: Reducer {
    static func reduce(state: State, action: Action) -> State {
        var state = state
        let currentPhase = state.phase

        switch action {
        case .reset:
            // リセットボタンが押されたらリセット確認依頼を出す
            state.resetConfirmationRequst = Request()
            
        case .resetConfirmed(let requestId, let execute):
            if let request = state.resetConfirmationRequst, request.requestId == requestId {
                state.resetConfirmationRequst = nil
                
                if execute {
                    // どのフェーズにいてもリセットの確認の結果、
                    // 実行することになったらリセット
                    state.phase = AnyPhase(ResetPhase())
                }
            }            
            
        default:
            break
        }
        
        // フェーズが変わらなければ、フェーズにreduceさせる
        if currentPhase == state.phase {
            state = currentPhase.reduce(state: state, action: action)
        }
        
        return state
    }
}
