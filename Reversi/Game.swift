import Foundation
import Combine

/// アクションに応じて状態を変更する `reduce` メソッドを持ちます。
/// このプロトコルは基本的に値型で準拠することを想定しています。
/// `reduce` メソッドでは、自身の型で保持する値であっても、
/// 変更したStateを返す以外の方法で状態を変更してはいけません。
/// また、このメソッド内では非同期処理の呼び出しなど
/// 副作用のあることを行ってはいけません。
public protocol Reducer {
    /// アクションに応じて状態を変更します。
    /// - Parameters:
    ///   - state: 変更前の状態です。
    ///   - action: 状態変更を要求するアクションです。
    /// - Returns: 変更後の状態を返します。
    func reduce(state: State, action: Action) -> State
}

/// アクションをディスパッチするメソッドを持ちます。
public protocol Dispatcher {
    /// アクションをディスパッチします。
    /// - Parameter action: アクション
    func dispatch(_ action: Action)
    
    /// サンクを用いてアクションをディスパッチします。
    /// - Parameter thunk: サンク
    func dispatch(_ thunk: Thunk)
}

/// アクションのディスパッチを遅延実行させるための関数です。
/// サンクの中では非同期処理の呼び出しなど副作用のある
/// 動作を行っても構いません。
public typealias Thunk = (Dispatcher, State) -> Void

public enum GameError: Error {
    case restore(data: String)
}

/// ゲームの状態を保持し、アクションをディスパッチすることでゲームを進めます。
public class Game: Dispatcher {
    /// 現在進行中のゲームのインスタンス
    public static var current: Game?
    
    private let stateHolder: CurrentValueSubject<State, Never>

    /// 現在の状態の発行元
    public let statePublisher: AnyPublisher<State, Never>

    /// 状態を変更するものです。
    public let reducer: Reducer

    /// 新規ゲームの開始状態で初期化します。
    public convenience init() {
        let state = State(board: Board(),
                          turn: .dark,
                          playerModes: [.manual, .manual])
        self.init(state: state, reducer: MainReducer())
    }

    /// 保存した状態で初期化します。
    /// - Parameter data: 保存状態のテキスト
    /// - Throws: 保存状態を復元できなければ `GameError.restore` を `throw` します。
    public convenience init(loading data: String) throws {
        // TODO:
        self.init()
    }

    /// 指定された状態で初期化します。
    public init(state: State, reducer: Reducer = MainReducer()) {
        self.reducer = reducer
        stateHolder = CurrentValueSubject(state)
        statePublisher = stateHolder
            .eraseToAnyPublisher()
    }

    /// このオブジェクトを現在進行中のGameにします。
    public func makeCurrent() {
        Game.current = self
    }
    
    private func outputLog(_ line: @autoclosure () -> String) {
//        print(line())
    }
    
    /// アクションをディスパッチします。
    /// - Parameter action: ディスパッチ対象のアクション
    public func dispatch(_ action: Action) {
        var state = stateHolder.value
        state = reducer.reduce(state: state, action: action)

        // サンクは取り出しておく
        let thunks = state.thunks
        state.thunks = []
        
        outputLog("Phase: \(state.phase)")
        stateHolder.value = state
        
        for thunk in thunks {
            dispatch(thunk)
        }
    }

    /// サンクを用いてアクションをディスパッチします。
    /// - Parameter thunk: サンク
    public func dispatch(_ thunk: Thunk) {
        thunk(self, stateHolder.value)
    }
}

public struct MainReducer: Reducer {
    public init() { }
    
    public func reduce(state: State, action: Action) -> State {
        var state = state
        let currentPhase = state.phase

        switch action {
        case ._setState(reducer: let reducer):
            // 任意の状態変更
            state = reducer.reduce(state: state, action: action)
            
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
